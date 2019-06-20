open Fastpack.Resolver
module FS = FastpackUtil.FS
module Preprocessor = Fastpack.Preprocessor

type resolved = (Fastpack.Module.location * string list) [@@deriving show]

let test_path = Test.get_test_path "resolve"

let show resolved =
  let resolved =
    let (location, dependencies) = resolved in
    let location =
      match location with
      | Fastpack.Module.File { filename; preprocessors } ->
        let filename =
          match filename with
          | None -> None
          | Some filename -> Some (Test.cleanup_project_path filename)
        in
        let preprocessors =
          preprocessors
          |> List.map (
            fun (p, opt) ->
              Test.(cleanup_project_path p, cleanup_project_path opt)
          )
        in
        Fastpack.Module.File { filename; preprocessors }
      | _ -> location
    in
    (location, List.map Test.cleanup_project_path dependencies)
  in
  Format.(pp_set_margin str_formatter 60);
  pp_resolved Format.str_formatter resolved;
  Format.flush_str_formatter ()

let resolve
  ?(current_dir=test_path)
  ?(mock=[])
  ?(node_modules_paths=["node_modules"])
  ?(extensions=[".js"; ".json"])
  ?(preprocessors=[])
  ?(basedir=test_path)
  request
  =
    let basedir = FS.abs_path current_dir basedir in
    let resolve' () =
      let%lwt cache = Fastpack.Cache.(make Empty)  in
      let resolver =
        make
          ~project_root:current_dir
          ~current_dir
          ~mock
          ~node_modules_paths
          ~extensions
          ~packageMainFields:["browser";"module";"main"]
          ~preprocessors
          ~cache
          ()
      in
      let%lwt resolved = resolve ~basedir request resolver in
      Lwt.return (show resolved)
    in
    let msg = Lwt_main.run (
      Lwt.catch
        resolve'
        (function
          | Error msg -> Lwt.return (Test.cleanup_project_path msg)
          | exn -> raise exn
        )
    ) in
    print_endline ("\n" ^ msg)

(*
 * Resolve simple file requests
 * *)

let%expect_test "." =
  resolve ".";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [] }),
 [])
|}]

let%expect_test "./index" =
  resolve "./index";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [] }),
 [])
|}]

let%expect_test "./index.js" =
  resolve "./index.js";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [] }),
 [])
|}]

let%expect_test "/.../index.js (abs path)" =
  resolve (FS.abs_path test_path "./index.js");
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [] }),
 [])
|}]

let%expect_test "./notfound" =
  resolve "./notfound";
  [%expect_exact {|
Cannot resolve module
  Resolving './notfound'. Base directory: '/.../test/resolve'
  Resolving '/.../test/resolve/notfound'.
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
((File
    { filename =
      (Some "/.../test/resolve/node_modules/dependency/dependency-entry-point.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "dependency/module" =
  resolve "dependency/module";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/dependency/module.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]


let%expect_test "'not-found' from ./subdir with custom node_modules" =
  resolve
    ~node_modules_paths:[FS.abs_path test_path "nm"; "node_modules"]
    ~basedir:"subdir"
    "not-found";
  [%expect_exact {|
Cannot find package path
  Resolving 'not-found'. Base directory: '/.../test/resolve/subdir'
  Resolving 'not-found'.
  Mocked package?
  ...no.
  Resolving 'not-found' through "browser"
  ...not found.
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
((File
    { filename = (Some "/.../test/resolve/fs.js");
      preprocessors = [] }),
 [])
|}]

let%expect_test "mock to package" =
  resolve ~mock:[("fs", Mock "dependency")] "fs";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/dependency/dependency-entry-point.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "mock to path in package" =
  resolve ~mock:[("fs", Mock "dependency/module")] "fs";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/dependency/module.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]


let%expect_test "resolve path in package with mocking to path in package (should fail)" =
  resolve ~mock:[("fs", Mock "dependency/module")] "fs/some-path";
  [%expect_exact {|
Cannot resolve module
  Resolving 'fs/some-path'. Base directory: '/.../test/resolve'
  Resolving 'fs/some-path'.
  Mocked package?
  ...yes 'dependency/module'.
  Resolving 'dependency/module/some-path'.
  Mocked package?
  ...no.
  Resolving 'dependency' through "browser"
  ...not found.
  Resolving '/.../test/resolve/node_modules/dependency/module/some-path'.
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path'
  ...no.
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path.js'
  ...no.
  File exists? '/.../test/resolve/node_modules/dependency/module/some-path.json'
  ...no.
  Is directory? '/.../test/resolve/node_modules/dependency/module/some-path'
  ...no.
|}]


let%expect_test "mocked file" =
  resolve
    ~mock:[("./node_modules/dependency/module.js", Mock "./index.js")]
    "dependency/module";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "mocked file (fails)" =
  resolve
    ~mock:[("./node_modules/dependency/module.js", Mock "./not-found.js")]
    "dependency/module";
  [%expect_exact {|
File not found: /.../test/resolve/not-found.js
  Resolving 'dependency/module'. Base directory: '/.../test/resolve'
  Resolving 'dependency/module'.
  Mocked package?
  ...no.
  Resolving 'dependency' through "browser"
  ...not found.
  Resolving '/.../test/resolve/node_modules/dependency/module'.
  Resolving '/.../test/resolve/node_modules/dependency/module.js' through "browser"
  ...not found.
  Mocked file?
  ...yes. '/.../test/resolve/not-found.js'
|}]

let%expect_test "resolver cycle" =
  resolve
    ~mock:[("pkg1", Mock "pkg2"); ("pkg2", Mock "pkg1")]
    "pkg1";
  [%expect_exact {|
Resolver went into cycle
  Resolving 'pkg1'. Base directory: '/.../test/resolve'
  Resolving 'pkg1'.
  Mocked package?
  ...yes 'pkg2'.
  Resolving 'pkg2'.
  Mocked package?
  ...yes 'pkg1'.
|}]

let%expect_test "browser entry point" =
  resolve "browser-entry-point";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/browser-entry-point/browser/index.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/browser-entry-point/package.json"
   ])
|}]

let%expect_test "browser shim" =
  resolve "browser-shim";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/browser-shim/index-browser.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/browser-shim/package.json"
   ])
|}]

let%expect_test "browser shim: file mapped to file" =
  resolve ~basedir:"node_modules/browser-shim" "./module";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/browser-shim/module-browser.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/browser-shim/package.json";
   "/.../test/resolve/node_modules/browser-shim/package.json"
   ])
|}]

let%expect_test "browser shim: package mapped to empty module" =
  resolve ~basedir:"node_modules/browser-shim" "skip-package";
  [%expect_exact {|
(EmptyModule,
 ["/.../test/resolve/node_modules/browser-shim/package.json"
   ])
|}]

let%expect_test "browser shim: package mapped to another package" =
  resolve ~basedir:"node_modules/browser-shim" "to-pkg";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/dependency/dependency-entry-point.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/browser-shim/package.json";
   "/.../test/resolve/node_modules/browser-shim/package.json";
   "/.../test/resolve/node_modules/dependency/package.json"
   ])
|}]

let%expect_test "browser shim: package mapped to file" =
  resolve ~basedir:"node_modules/browser-shim" "to-file";
  [%expect_exact {|
((File
    { filename =
      (Some "/.../test/resolve/node_modules/browser-shim/file.js");
      preprocessors = [] }),
 ["/.../test/resolve/node_modules/browser-shim/package.json";
   "/.../test/resolve/node_modules/browser-shim/package.json"
   ])
|}]

let%expect_test "preprocessors" =
  resolve "dependency?k=v&a=b!./fs!./index";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors =
      [("/.../test/resolve/node_modules/dependency/dependency-entry-point.js",
        "k=v&a=b"); ("/.../test/resolve/fs.js", "")]
      }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "preprocessors: no argument" =
  resolve "dependency?k=v&a=b!./fs!";
  [%expect_exact {|
((File
    { filename = None;
      preprocessors =
      [("/.../test/resolve/node_modules/dependency/dependency-entry-point.js",
        "k=v&a=b"); ("/.../test/resolve/fs.js", "")]
      }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "preprocessors: empty request" =
  resolve "dependency?k=v&a=b!!./fs!./index";
  [%expect_exact {|
Empty request
  Resolving 'dependency?k=v&a=b!!./fs!./index'. Base directory: '/.../test/resolve'
  Resolving preprocessors 'dependency?k=v&a=b!!./fs'
  Resolving preprocessor '', base directory '/.../test/resolve'
|}]


let%expect_test "preprocessors: configured only" =
  resolve
    ~preprocessors:[Fastpack.Config.Preprocessor.ofString "\\.js"]
    "./index";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors = [("builtin", "")] }),
 [])
|}]

let%expect_test "preprocessors: configured and specified" =
  let config = "\\.js$:browser-shim?x=1!browser-entry-point" in
  resolve
    ~preprocessors:[Fastpack.Config.Preprocessor.ofString config]
    "dependency?k=v&a=b!./fs!./index";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors =
      [("/.../test/resolve/node_modules/browser-shim/index-browser.js",
        "x=1");
        ("/.../test/resolve/node_modules/browser-entry-point/browser/index.js",
         "");
        ("/.../test/resolve/node_modules/dependency/dependency-entry-point.js",
         "k=v&a=b");
        ("/.../test/resolve/fs.js", "")]
      }),
 ["/.../test/resolve/node_modules/browser-shim/package.json";
   "/.../test/resolve/node_modules/browser-entry-point/package.json";
   "/.../test/resolve/node_modules/dependency/package.json"
   ])
|}]

let%expect_test "preprocessors: ignore configured processors" =
  let config = "\\.js$:browser-shim?x=1!browser-entry-point" in
  resolve
    ~preprocessors:[Fastpack.Config.Preprocessor.ofString config]
    "!dependency?k=v&a=b!./fs!./index";
  [%expect_exact {|
((File
    { filename = (Some "/.../test/resolve/index.js");
      preprocessors =
      [("/.../test/resolve/node_modules/dependency/dependency-entry-point.js",
        "k=v&a=b"); ("/.../test/resolve/fs.js", "")]
      }),
 ["/.../test/resolve/node_modules/dependency/package.json"])
|}]

let%expect_test "preprocessors: error" =
  let config = "\\.js$:browser-shim?x=1!browser-entry-point" in
  resolve
    ~preprocessors:[Fastpack.Config.Preprocessor.ofString config]
    "dependency-not-found?k=v&a=b!./fs!./index";

  [%expect_exact {|
Cannot find package path
  Resolving 'dependency-not-found?k=v&a=b!./fs!./index'. Base directory: '/.../test/resolve'
  Resolving preprocessors 'browser-shim?x=1!browser-entry-point!dependency-not-found?k=v&a=b!./fs'
  Resolving preprocessor 'dependency-not-found?k=v&a=b', base directory '/.../test/resolve'
  Resolving 'dependency-not-found'.
  Mocked package?
  ...no.
  Resolving 'dependency-not-found' through "browser"
  ...not found.
  Resolving package path
  Path exists? '/.../test/resolve/node_modules/dependency-not-found'
  ...no.
|}]
