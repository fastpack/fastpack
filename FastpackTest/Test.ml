module FS = FastpackUtil.FS

let project_path =
  FS.abs_path (Unix.getcwd ()) "../../../"

let () =
  Fastpack.Environment.setExecutable
    (FilePath.concat project_path "_build/default/bin/fpack.exe")

let get_test_path name =
  FS.abs_path project_path ("./test/" ^ name)

let cleanup_project_path =
  CCString.replace ~which:`All ~sub:project_path ~by:"/..."


let test f filename =
  let filename = get_test_path filename in

  let result = Lwt_main.run (
    let%lwt source = Lwt_io.(with_file ~mode:Input filename read) in
    Lwt.return (f source)
  )
  in
  Printf.printf "%s" result

let testString f source =
  let result = Lwt_main.run (
    Lwt.return (f source)
  )
  in
  Printf.printf "%s" result

let print ~with_scope source =
  let program, _ = FastpackUtil.Parser.parse_source source in
  let result = FastpackUtil.Printer.print ~with_scope program in
  result

let transpile source =
  FastpackTranspiler.transpile_source [
    FastpackTranspiler.StripFlow.transpile;
    FastpackTranspiler.ReactJSX.transpile;
    FastpackTranspiler.Class.transpile;
    FastpackTranspiler.ObjectSpread.transpile;
  ] source |> fst
