module FS = FastpackUtil.FS

type result = (Fastpack.Module.location * string list) [@@deriving show]

let project_root =
  FS.abs_path (Unix.getcwd ()) "../../../"

let test_root =
  FS.abs_path project_root "./test/resolve"

let show result =
  Format.(pp_set_margin str_formatter 10000);
  pp_result Format.str_formatter result;
  Format.flush_str_formatter ()
  |> String.replace ~sub:"{ " ~by:"{\n  "
  |> String.replace ~sub:"; " ~by:";\n  "
  |> String.replace ~sub:" }), " ~by:"\n}),\n"
  |> String.replace ~sub:"[\"" ~by:"[\n  \""
  |> String.replace ~sub:"\"]" ~by:"\"\n]"


let replace_project_root =
  String.replace ~which:`All ~sub:project_root ~by:"/..."

let resolve ?(basedir=test_root) request =
  let resolve' () =
    let%lwt cache = Fastpack.Cache.(create Memory) in
    let {Fastpack.Resolver. resolve } =
      Fastpack.Resolver.make
        ~project_dir:test_root ~extensions:[".js"; ".json"] ~cache
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
  print_endline (replace_project_root ("\n" ^ msg))

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
  resolve (FS.abs_path test_root "./index.js");
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/index.js");
  preprocessors = []
}),
[])
|}]
