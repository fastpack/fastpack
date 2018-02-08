let run_with_source f filename =
  let filename = "../../test/" ^ filename in
  let result = Lwt_main.run (
    let%lwt source = Lwt_io.(with_file ~mode:Input filename read) in
    Lwt.return (f source)
  )
  in
  Printf.printf "%s" result

let run_with_filename f filename =
  let filename =
    FastpackUtil.FS.abs_path (Unix.getcwd ()) ("../../test/" ^ filename)
  in
  let _result = f filename in
  (* Printf.printf "%s" result *)
  ()

let print with_scope source =
  let program, _ = FastpackUtil.Parser.parse_source source in
  let result = FastpackUtil.Printer.print ~with_scope program in
  result

let pack ~mode ~target ~preprocessor pack_f entry_filename =
  let pack' () =
    let bytes = Lwt_bytes.create 5000000 in
    let ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
    let%lwt cache = Fastpack.Cache.create None in
    let%lwt _ =
      Fastpack.pack
        ~pack_f
        ~cache
        ~mode
        ~target
        ~preprocessor
        ~entry_filename
        ~package_dir:(Filename.dirname entry_filename)
        ch
    in
  ch
    |> Lwt_io.position
    |> Int64.to_int
    |> Lwt_bytes.extract bytes 0
    |> Lwt_bytes.to_string
    |> Lwt.return
  in
  try
    Lwt_main.run (pack' ())
  with
  | Fastpack.PackError (ctx, error) ->
    let cwd = FastpackUtil.FS.abs_path (Unix.getcwd ()) "../../" in
    Fastpack.string_of_error ctx error
    |> String.replace ~sub:cwd ~by:"/..."

let pack_regular_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_regular_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_flat_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    (Fastpack.FlatPacker.pack)

let pack_flat_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    (Fastpack.FlatPacker.pack)

let pack_regular_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_regular_esm =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.ESM
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_flat_esm =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.ESM
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.FlatPacker.pack

let pack_flat_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.FlatPacker.pack

let pack_transpile_regular_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.transpile_all
    Fastpack.RegularPacker.pack

let pack_transpile_flat_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.transpile_all
    Fastpack.FlatPacker.pack
