module FS = FastpackUtil.FS

type result = (Fastpack.Module.location * string list) [@@deriving show]

let test_path = Test.get_test_path "resolve"

let show result =
  Format.(pp_set_margin str_formatter 10000);
  pp_result Format.str_formatter result;
  Format.flush_str_formatter ()
  |> String.replace ~sub:"{ " ~by:"{\n  "
  |> String.replace ~sub:"; " ~by:";\n  "
  |> String.replace ~sub:" }), " ~by:"\n}),\n"
  |> String.replace ~sub:"[\"" ~by:"[\n  \""
  |> String.replace ~sub:"\"]" ~by:"\"\n]"

let resolve ?(basedir=test_path) request =
  let resolve' () =
    let%lwt cache = Fastpack.Cache.(create Memory) in
    let {Fastpack.Resolver. resolve } =
      Fastpack.Resolver.make
        ~project_dir:test_path ~extensions:[".js"; ".json"] ~cache
    in
    let%lwt resolved = resolve ~basedir request in
    Lwt.return (show resolved)
  in
  let msg = Lwt_main.run (
    Lwt.catch
      resolve'
      (function
        | Fastpack.Resolver.Error msg -> Lwt.return msg
        | exn -> raise exn
      )
  ) in
  print_endline (Test.cleanup_project_path ("\n" ^ msg))

let%expect_test "./index" =
  resolve "./index";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/index.js");
  preprocessors = []
}),
[])
|}]

let%expect_test "./index.js" =
  resolve "./index.js";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/index.js");
  preprocessors = []
}),
[])
|}]

let%expect_test "/.../index.js (abs path)" =
  resolve (FS.abs_path test_path "./index.js");
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/index.js");
  preprocessors = []
}),
[])
|}]
