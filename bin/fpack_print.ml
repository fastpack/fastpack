let () =
  let (>>=) = Lwt.(>>=) in
  let open Cmdliner in

  let run_t =

    let run entry =
      let get_contents name =
        try%lwt
          Lwt_io.(with_file ~mode:Input name read) >>= Lwt.return
        with Unix.Unix_error _ ->
          failwith "Cannot read file"
      in

      let put_contents s = Lwt_io.write Lwt_io.stdout (s ^ "\n") in

      let print source =
        let transpile =
          FastpackTranspiler.transpile_source [
            FastpackTranspiler.ReactJSX.transpile;
          ]
        in
        (* let program, _ = Fastpack.Parser.parse_source source in *)
        let result = transpile source in
        result
      in

      let print' entry =
        let%lwt source = get_contents entry in
        let printed = print source in
        put_contents printed
      in

      let entry = match entry with
        | None -> "./index.js"
        | Some entry -> entry
      in
      try
        let () = Lwt_main.run (print' entry) in
        `Ok ""
      with
      | Fastpack.PackerUtil.PackError (ctx, error) ->
        `Error (false,
          "\n"
          ^ Fastpack.PackerUtil.ctx_to_string ctx
          ^ "\n"
          ^ Fastpack.Error.to_string error
        )
    in

    let entry_t =
      let doc = "Entry point" in
      let docv = "ENTRY" in
      Arg.(value & pos 0 (some string) None & info [] ~docv ~doc)
    in

    Term.(ret (const run $ entry_t))
  in

  let info =
    let doc =
      "Pack JavaScript code into a single bundle"
    in
    Term.info "fpack" ~version:"preview" ~doc ~exits:Term.default_exits
  in

  Term.exit @@ Term.eval (run_t, info)
