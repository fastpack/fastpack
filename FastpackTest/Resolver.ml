open Fastpack.Resolver
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

let resolve
  ?(project_dir=test_path)
  ?(mock=[])
  ?(node_modules_paths=["node_modules"])
  ?(extensions=[".js"; ".json"])
  ?(basedir=test_path)
  request
  =
    let basedir = FS.abs_path project_dir basedir in
    let resolve' () =
      let%lwt cache = Fastpack.Cache.(create Memory) in
      let { resolve } =
        make
          ~project_dir
          ~mock
          ~node_modules_paths
          ~extensions
          ~cache
      in
      let%lwt resolved = resolve ~basedir request in
      Lwt.return (show resolved)
    in
    let msg = Lwt_main.run (
      Lwt.catch
        resolve'
        (function
          | Error msg -> Lwt.return msg
          | exn -> raise exn
        )
    ) in
    print_endline (Test.cleanup_project_path ("\n" ^ msg))

(*
 * Resolve simple file requests
 * *)

let%expect_test "." =
  resolve ".";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/index.js");
  preprocessors = []
}),
[])
|}]

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

let%expect_test "./notfound" =
  resolve "./notfound";
  [%expect_exact {|
Cannot resolve module
  Resolving './notfound'. Base directory: '/.../test/resolve'
  Resolving './notfound'. Base directory: '/.../test/resolve'
  File exists? '/.../test/resolve/notfound'
  ...no.
  File exists? '/.../test/resolve/notfound.js'
  ...no.
  File exists? '/.../test/resolve/notfound.json'
  ...no.
  Is directory? '/.../test/resolve/notfound'
  ...no.
|}]

(*
 * Resolving packages
 * *)

let%expect_test "dependency" =
  resolve "dependency";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/node_modules/dependency/dependency-entry-point.js");
  preprocessors = []
}),
[])
|}]

let%expect_test "dependency/module" =
  resolve "dependency/module";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/node_modules/dependency/module.js");
  preprocessors = []
}),
[])
|}]


let%expect_test "'not-found' from ./subdir with custom node_modules" =
  resolve
    ~node_modules_paths:[FS.abs_path test_path "nm"; "node_modules"]
    ~basedir:"subdir"
    "not-found";
  [%expect_exact {|
Cannot find package path
  Resolving 'not-found'. Base directory: '/.../test/resolve/subdir'
  Resolving 'not-found'. Base directory: '/.../test/resolve/subdir'
  Mocked package?
  ...no.
  Resolving package path
  Path exists? '/.../test/resolve/nm/not-found'
  ...no.
  Path exists? '/.../test/resolve/subdir/node_modules/not-found'
  ...no.
  Path exists? '/.../test/resolve/node_modules/not-found'
  ...no.
|}]


let%expect_test "no internal modules in mock" =
  resolve
    ~mock:[("$fp$runtime", Empty)]
    "dependency";
  [%expect_exact {|
Cannot mock internal package: $fp$runtime
|}]

let%expect_test "cannot mock path in package" =
  resolve
    ~mock:[("dependency/some/path", Empty)]
    "dependency";
  [%expect_exact {|
Cannot mock path inside the package: dependency/some/path
|}]

let%expect_test "cannot mock file with anything else but file" =
  resolve
    ~mock:[("./some/file.js", Mock "some-package")]
    "dependency";
  [%expect_exact {|
File could be only mocked with another file, not package: ./some/file.js:some-package
|}]


let%expect_test "mock to empty module" =
  resolve ~mock:[("fs", Empty)] "fs";
  [%expect_exact {|
(EmptyModule, [])
|}]

let%expect_test "mock to path" =
  resolve ~mock:[("fs", Mock "./fs.js")] "fs";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/fs.js");
  preprocessors = []
}),
[])
|}]

let%expect_test "mock to package" =
  resolve ~mock:[("fs", Mock "dependency")] "fs";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/node_modules/dependency/dependency-entry-point.js");
  preprocessors = []
}),
[])
|}]

let%expect_test "mock to path in package" =
  resolve ~mock:[("fs", Mock "dependency/module")] "fs";
  [%expect_exact {|
((File {
  filename = (Some "/.../test/resolve/node_modules/dependency/module.js");
  preprocessors = []
}),
[])
|}]


let%expect_test "resolve path in package with mocking to path in package (should fail)" =
  resolve ~mock:[("fs", Mock "dependency/module")] "fs/some-path";
  [%expect_exact {|
Cannot resolve module
  Resolving 'fs/some-path'. Base directory: '/.../test/resolve'
  Resolving 'fs/some-path'. Base directory: '/.../test/resolve'
  Mocked package?
  ...yes 'dependency/module'.
  Resolving 'dependency/module/some-path'. Base directory: '/.../test/resolve'
  Mocked package?
  ...no.
  Resolving '/.../test/resolve/node_modules/dependency/module/some-path'. Base directory: '/.../test/resolve'
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path'
  ...no.
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path.js'
  ...no.
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path.json'
  ...no.
  Is directory? '/.../test/resolve/node_modules/dependency/module/some-path'
  ...no.
|}]
