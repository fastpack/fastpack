open Test
open Fastpack
open Lwt.Infix
module StringSet = Set.Make(CCString)

let re_modules = Re.Posix.compile_pat "^.+/\\* --runtimeMain-- \\*/"
let run_with ~test_name ~cmd ~files f =
  Pastel.(setMode Disabled);
  Unix.putenv "FPACK_FORCE_TTY" "false";
  let test_path = get_test_path test_name in
  Unix.chdir test_path;
  let argv =
    cmd
    |> String.split_on_char ' '
    |> List.filter(fun p -> p <> "")
    |> Array.of_list
  in
  let opts = Cmdliner.Term.eval
      ~argv (Config.term, Cmdliner.Term.info "y")
  in
  match opts with
  | `Ok opts ->
    (* FIXME: ugly hack to make travis happy *)
    let pause =
      match Unix.getenv "TRAVIS_OS_NAME" with
      | "osx" -> 1.
      | _ -> 0.001
      | exception Not_found -> 0.001
    in
    Lwt_main.run(
      Lwt.catch (fun () ->
          let%lwt opts = opts in
          let%lwt () = Lwt_list.iter_s (fun (name, content) ->
              Lwt_io.with_file
                ~mode:Lwt_io.Output
                ~perm:0o640
                ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                name
                (fun ch -> Lwt_io.write ch (content ^ "\n"))
              )
              files
          in
          let%lwt () = Lwt_io.flush_all () in
          let%lwt () = Lwt_unix.sleep pause in
          let change_files =
            Lwt_list.fold_left_s (fun acc (name, action) ->
                let%lwt () =
                  match action with
                  | `Content content ->
                    Lwt_io.with_file
                      ~mode:Lwt_io.Output
                      ~perm:0o640
                      ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                      name
                      (fun ch -> Lwt_io.write ch (content ^ "\n"))
                  | `Delete ->
                    Lwt_unix.unlink name
                  | `Touch ->
                    let%lwt content =
                      Lwt_io.(with_file ~mode:Input name read)
                    in
                    Lwt_io.with_file
                      ~mode:Lwt_io.Output
                      ~perm:0o640
                      ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                      name
                      (fun ch -> Lwt_io.write ch content)
                in
                Lwt.return (
                  FastpackUtil.FS.abs_path test_path name
                  |> (fun f -> StringSet.add f acc)
                )
              )
              StringSet.empty
          in
          let messages = ref [] in
          (* let report_ok *)
          (*     ~message:_message *)
          (*     ~start_time:_start_time *)
          (*     ~files *)
          (*     _ctx *)
          (*   = *)
          (*   let {Reporter. name; _} = List.hd files in *)
          (*   let%lwt content = Lwt_io.(with_file ~mode:Input name read) in *)
          (*   messages := (Re.replace ~f:(fun _ -> "\n({") re_modules content) :: !messages; *)
          (*   Lwt.return_unit *)
          (* in *)
          (* let report_error ~error ctx = *)
          (*   let error_text = Context.stringOfError ctx error in *)
          (*   messages := error_text :: !messages; *)
          (*   Lwt.return_unit *)
          (* in *)
          let%lwt builder = Builder.make opts in
          let saveResult prevResult r =
            match prevResult with
            | Some(prevResult) when prevResult == r ->
              messages := "---Unchanged--- \n" :: !messages;
              Lwt.return r
            | _ ->
              match r with
              | Ok(bundle) ->
                let name =
                  List.hd
                    (List.map (fun {Bundle.absPath; _} -> absPath) (Bundle.getFiles bundle))
                in
                let%lwt content = Lwt_io.(with_file ~mode:Input name read) in
                messages := (Re.replace ~f:(fun _ -> "\n") re_modules content) :: !messages;
                Lwt.return r
              | Error({Builder. reason; _}) ->
                let error_text = Error.toString builder.Builder.current_dir  reason  in
                messages := error_text :: !messages;
                Lwt.return r
          in
          Lwt.finalize (fun () ->
              let%lwt initial_result = Builder.build builder >>= saveResult None in
              let change_and_rebuild ~actions r =
                let%lwt filesChanged = change_files actions in
                let%lwt () = Lwt_io.flush_all () in
                let%lwt () = Lwt_unix.sleep pause in
                Builder.rebuild ~filesChanged ~prevResult:r builder
                >>= saveResult (Some r)
              in
              let%lwt () = f initial_result change_and_rebuild in
              !messages
              |> List.rev
              |> String.concat "---------------------------------------------\n"
              |> Lwt.return
            )
          (fun () -> Builder.finalize(builder))
        )
        (fun exn -> Lwt.return Printexc.(to_string exn  ^ "\n" ^ get_backtrace ()))
    ) |> cleanup_project_path |> print_endline
  | _ -> failwith "Parsing CLI failed"


let%expect_test "start ok, change one file, touch one file" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import a from './a'; import b from './b'; console.log(a,b);|};
      "a.js", {|export default "a";|};
      "b.js", {|export default "b";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild (* one file change *)
         ~actions:["a.js", `Content {|export default "hello";|}]
        >>= change_and_rebuild (* an unrelated file has been changed *)
         ~actions:["c.js", `Content {|export default "c";|}]
        >>= change_and_rebuild (* file touched FIXME*)
         ~actions:["a.js", `Touch]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"hello\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------
---Unchanged--- 
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"hello\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});

|}]

let%expect_test "start ok, remove one file, fix import" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import a from './a'; import b from './b'; console.log(a,b);|};
      "a.js", {|export default "a";|};
      "b.js", {|export default "b";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild (* delete file *)
         ~actions:["a.js", `Delete]
        >>= change_and_rebuild (* fix import *)
         ~actions:["index.js", `Content {|import b from './b'; console.log(b);|}]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------

/.../test/watch/index.js
Cannot resolve './a'

Cannot resolve module
  Resolving './a'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/a'.
  File exists? '/.../test/watch/a'
  ...no.
  File exists? '/.../test/watch/a.js'
  ...no.
  File exists? '/.../test/watch/a.json'
  ...no.
  Is directory? '/.../test/watch/a'
  ...no.
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__b = __fastpack_require__(\"./b\");\n console.log((__fastpack_require__.default(_1__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./b":"b"}
},

});

|}]

let%expect_test "start ok, remove one file, restore this file back" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import a from './a'; import b from './b'; console.log(a,b);|};
      "a.js", {|export default "a";|};
      "b.js", {|export default "b";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild (* delete file *)
         ~actions:["a.js", `Delete]
        >>= change_and_rebuild (* restore file back *)
          ~actions:["a.js", `Content {|export default "a restored";|}]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------

/.../test/watch/index.js
Cannot resolve './a'

Cannot resolve module
  Resolving './a'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/a'.
  File exists? '/.../test/watch/a'
  ...no.
  File exists? '/.../test/watch/a.js'
  ...no.
  File exists? '/.../test/watch/a.json'
  ...no.
  Is directory? '/.../test/watch/a'
  ...no.
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a restored\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});

|}]

let%expect_test "start ok, remove 2 files, restore them one by one" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import a from './a'; import b from './b'; console.log(a,b);|};
      "a.js", {|export default "a";|};
      "b.js", {|export default "b";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild (* delete 2 files *)
         ~actions:["a.js", `Delete;
                   "b.js", `Delete]
        >>= change_and_rebuild (* restore b *)
          ~actions:["b.js", `Content {|export default "b restored";|}]
        >>= change_and_rebuild (* restore a *)
          ~actions:["a.js", `Content {|export default "a restored";|}]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------

/.../test/watch/index.js
Cannot resolve './b'

Cannot resolve module
  Resolving './b'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/b'.
  File exists? '/.../test/watch/b'
  ...no.
  File exists? '/.../test/watch/b.js'
  ...no.
  File exists? '/.../test/watch/b.json'
  ...no.
  Is directory? '/.../test/watch/b'
  ...no.
---------------------------------------------

/.../test/watch/index.js
Cannot resolve './a'

Cannot resolve module
  Resolving './a'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/a'.
  File exists? '/.../test/watch/a'
  ...no.
  File exists? '/.../test/watch/a.js'
  ...no.
  File exists? '/.../test/watch/a.json'
  ...no.
  Is directory? '/.../test/watch/a'
  ...no.
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a restored\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b restored\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});

|}]

let%expect_test "start with parse error, than fix" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|console.log("hello, "world!"");|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild (* fix parse error *)
         ~actions:["index.js", `Content {|console.log("hello, \"world!\"");|};]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|
/.../test/watch/index.js
Parse error

--------------------
Unexpected identifier at (1:21) - (1:26):

1 │ console.log("hello, "world!"");
  │                      ^^^^^
2 │ 


---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("console.log(\"hello, \\\"world!\\\"\");\n\n//# sourceURL=fpack:///index.js");
},
d: {}
},

});

|}]

let%expect_test "start ok, remove all files, restore a, restore b" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import a from './a'; import b from './b'; console.log(a,b);|};
      "a.js", {|export default "a";|};
      "b.js", {|export default "b";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild
         ~actions:["index.js", `Delete;
                   "a.js", `Delete;
                   "b.js", `Delete]
       >>= change_and_rebuild
         ~actions:["a.js", `Content {|export default "a restored";|}]
       >>= change_and_rebuild
         ~actions:["b.js", `Content {|export default "b restored";|}]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: b.js */
"b":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\nconst _2__b = __fastpack_require__(\"./b\");\n  console.log((__fastpack_require__.default(_1__a)),(__fastpack_require__.default(_2__b)));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},

});
---------------------------------------------

$fp$main
Cannot resolve './index.js'

Cannot resolve module
  Resolving './index.js'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/index.js'.
  File exists? '/.../test/watch/index.js'
  ...no.
  File exists? '/.../test/watch/index.js.js'
  ...no.
  File exists? '/.../test/watch/index.js.json'
  ...no.
  Is directory? '/.../test/watch/index.js'
  ...no.
---------------------------------------------

$fp$main
Cannot resolve './index.js'

Cannot resolve module
  Resolving './index.js'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/index.js'.
  File exists? '/.../test/watch/index.js'
  ...no.
  File exists? '/.../test/watch/index.js.js'
  ...no.
  File exists? '/.../test/watch/index.js.json'
  ...no.
  Is directory? '/.../test/watch/index.js'
  ...no.
---------------------------------------------

$fp$main
Cannot resolve './index.js'

Cannot resolve module
  Resolving './index.js'. Base directory: '/.../test/watch'
  Resolving '/.../test/watch/index.js'.
  File exists? '/.../test/watch/index.js'
  ...no.
  File exists? '/.../test/watch/index.js.js'
  ...no.
  File exists? '/.../test/watch/index.js.json'
  ...no.
  Is directory? '/.../test/watch/index.js'
  ...no.

|}]

let%expect_test "start ok, break import, fix export" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import {a} from './a'; console.log(a);|};
      "a.js", {|export const a = "exported from a";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild
         ~actions:["index.js", `Content {|import {aa} from './a'; console.log(aa);|}]
       >>= change_and_rebuild
         ~actions:["a.js", `Content {|export const aa = "exported from a"|}]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst a = \"exported from a\";;Object.defineProperty(exports, \"a\", {enumerable: true, get: function() {return a;}});\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\n console.log((Object(_1__a[\"a\"])));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a"}
},

});
---------------------------------------------

/.../test/watch/index.js
Import Error

Cannot import name 'aa' from 'a.js'

---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst aa = \"exported from a\";Object.defineProperty(exports, \"aa\", {enumerable: true, get: function() {return aa;}});\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\n console.log((Object(_1__a[\"aa\"])));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a"}
},

});

|}]

let%expect_test "start with failing import, fix import" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|import {aa} from './a'; console.log(a);|};
      "a.js", {|export const a = "exported from a";|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild
         ~actions:["index.js", `Content {|import {a as aa} from './a'; console.log(aa);|}]
       >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|
/.../test/watch/index.js
Import Error

Cannot import name 'aa' from 'a.js'

---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst a = \"exported from a\";;Object.defineProperty(exports, \"a\", {enumerable: true, get: function() {return a;}});\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__a = __fastpack_require__(\"./a\");\n console.log((Object(_1__a[\"a\"])));\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a"}
},

});

|}]

let%expect_test "make sure data.json triggers rebuild" =
  run_with
    ~test_name:"watch"
    ~cmd:"fpack --no-cache --dev index.js"
    ~files:[
      "index.js", {|let json = require('./data.json');|};
      "data.json", {|{"x": 1}|};
    ]
    (fun initial_result change_and_rebuild ->
       initial_result
       |> change_and_rebuild
         ~actions:["data.json", `Content {|{"x": 2}|}]
       >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|

({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: data.json */
"dataDOT$$json":{m:function(module, exports, __fastpack_require__) {
eval("module.exports = {\"x\": 1}\n;");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("let json = __fastpack_require__(\"./data.json\");\n\n//# sourceURL=fpack:///index.js");
},
d: {"./data.json":"dataDOT$$json"}
},

});
---------------------------------------------


({
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},
/* !s: data.json */
"dataDOT$$json":{m:function(module, exports, __fastpack_require__) {
eval("module.exports = {\"x\": 2}\n;");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("let json = __fastpack_require__(\"./data.json\");\n\n//# sourceURL=fpack:///index.js");
},
d: {"./data.json":"dataDOT$$json"}
},

});

|}]
