open Fastpack
open Lwt.Infix
module StringSet = Set.Make(String)

let re_modules = Re_posix.compile_pat "^.+\\$fp\\$main'\\);.+\\(\\{"
let run_with ~test_name ~cmd ~files f =
  let argv =
    cmd
    |> String.split_on_char ' '
    |> List.filter(fun p -> p <> "")
    |> Array.of_list
  in
  let opts = Cmdliner.Term.eval
      ~argv (Config.term, Cmdliner.Term.info "y")
  in
  let test_path = Test.get_test_path test_name in
  match opts with
  | `Ok opts ->
    Lwt_main.run(
      let%lwt () = Lwt_unix.chdir test_path in
      Lwt.catch (fun () ->
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
                Lwt.return (FastpackUtil.FS.abs_path test_path name |> (fun f -> StringSet.add f acc))
              )
              StringSet.empty
          in
          let messages = ref [] in
          let report_ok
              ~message:_message
              ~start_time:_start_time
              ~ctx:_ctx
              ~files  =
            let {Reporter. name; _} = List.hd files in
            let%lwt content = Lwt_io.(with_file ~mode:Input name read) in
            messages := (Re.replace ~f:(fun _ -> "\n({") re_modules content) :: !messages;
            Lwt.return_unit
          in
          let report_error ~ctx ~error =
            let error_text = Context.stringOfError ctx error in
            messages := error_text :: !messages;
            Lwt.return_unit
          in
          let%lwt {Packer.pack; finalize} =
            Packer.make
              ~report:(Some(Reporter.Internal(report_ok, report_error)))
              opts
          in
          Lwt.finalize (fun () ->
              let%lwt initial_result =
                pack
                  ~graph:None
                  ~current_location:None
                  ~initial:true
                  ~start_time:(Unix.gettimeofday ())
              in
              let change_and_rebuild ~actions r =
                let%lwt filesChanged = change_files actions in
                Watcher2.rebuild ~filesChanged ~pack r
              in
              let initial_result =
                match initial_result with
                | Error (ctx: Context.t) -> Error (ctx, DependencyGraph.get_files ctx.graph)
                | Ok (ctx: Context.t) -> Ok (ctx, DependencyGraph.get_files ctx.graph)
              in
              let%lwt () = f initial_result change_and_rebuild in
              (Printf.sprintf "Number of rebuilds: %d\n" (List.length !messages - 1) :: !messages)
              |> List.rev
              |> String.concat "---------------------------------------------\n"
              |> Lwt.return
            )
          finalize
        )
        (fun exn -> Lwt.return Printexc.(to_string exn  ^ "\n" ^ get_backtrace ()))
    ) |> print_endline
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
        >>= change_and_rebuild (* a different file has changed *)
         ~actions:["c.js", `Content {|export default "c";|}]
        >>= change_and_rebuild (* file touched FIXME*)
         ~actions:["a.js", `Touch]
        >>= (fun _ -> Lwt.return_unit)
    );
  [%expect_exact {|
({
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------

({
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"hello\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------

({
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"hello\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------
Number of rebuilds: 2

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
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------

Module resolution error: cannot resolve './a'
/Users/zindel/ocaml/fastpack/test/watch/index.js
Cannot resolve module
  Resolving './a'. Base directory: '/Users/zindel/ocaml/fastpack/test/watch'
  Resolving '/Users/zindel/ocaml/fastpack/test/watch/a'.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.js'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.json'
  ...no.
  Is directory? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
---------------------------------------------

({
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__b = __fastpack_require__(\"./b\");const _1__b__default = _1__b.__esModule ? _1__b.default : _1__b;\n console.log(_1__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------
Number of rebuilds: 2

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
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------

Module resolution error: cannot resolve './a'
/Users/zindel/ocaml/fastpack/test/watch/index.js
Cannot resolve module
  Resolving './a'. Base directory: '/Users/zindel/ocaml/fastpack/test/watch'
  Resolving '/Users/zindel/ocaml/fastpack/test/watch/a'.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.js'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.json'
  ...no.
  Is directory? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
---------------------------------------------

({
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a restored\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------
Number of rebuilds: 2

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
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------

Module resolution error: cannot resolve './b'
/Users/zindel/ocaml/fastpack/test/watch/index.js
Cannot resolve module
  Resolving './b'. Base directory: '/Users/zindel/ocaml/fastpack/test/watch'
  Resolving '/Users/zindel/ocaml/fastpack/test/watch/b'.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/b'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/b.js'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/b.json'
  ...no.
  Is directory? '/Users/zindel/ocaml/fastpack/test/watch/b'
  ...no.
---------------------------------------------

Module resolution error: cannot resolve './a'
/Users/zindel/ocaml/fastpack/test/watch/index.js
Cannot resolve module
  Resolving './a'. Base directory: '/Users/zindel/ocaml/fastpack/test/watch'
  Resolving '/Users/zindel/ocaml/fastpack/test/watch/a'.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.js'
  ...no.
  File exists? '/Users/zindel/ocaml/fastpack/test/watch/a.json'
  ...no.
  Is directory? '/Users/zindel/ocaml/fastpack/test/watch/a'
  ...no.
---------------------------------------------

({
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"a restored\";\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"b restored\";\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");const _1__a__default = _1__a.__esModule ? _1__a.default : _1__a;\nconst _2__b = __fastpack_require__(\"./b\");const _2__b__default = _2__b.__esModule ? _2__b.default : _2__b;\n  console.log(_1__a__default,_2__b__default);\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
---------------------------------------------
Number of rebuilds: 3

|}]
