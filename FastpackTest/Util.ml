

let test f filename =
  let filename = "../../test/" ^ filename in
  let result = Lwt_main.run (
    let%lwt source = Lwt_io.(with_file ~mode:Input filename read) in
    Lwt.return (f source)
  )
  in
  Printf.printf "%s" result

let print ~with_scope source =
  let program, _ = FastpackUtil.Parser.parse_source source in
  let result = FastpackUtil.Printer.print ~with_scope program in
  result

let transpile =
  FastpackTranspiler.transpile_source [
    FastpackTranspiler.StripFlow.transpile;
    FastpackTranspiler.ReactJSX.transpile;
    FastpackTranspiler.Class.transpile;
    FastpackTranspiler.ObjectSpread.transpile;
  ]
