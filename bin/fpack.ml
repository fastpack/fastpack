let () =
  let open Cmdliner in

  let run_t =

    let run entry =
      let entry = match entry with
        | None -> "./index.js"
        | Some entry -> entry
      in
      try
        `Ok (Fastpack.Packer.pack_main entry)
      with
      | Fastpack.Packer.PackError (InvalidEntryPoint filename) ->
        `Error (
          false,
          Printf.sprintf "Cannot find entry point %s" filename
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
