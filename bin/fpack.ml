(*
 * fpack --transpile-jsx '^lib' --transpile-jsx '^src'
 * *)


let () =
  let open Cmdliner in

  let run_t =

    let run entry =
      let entry = match entry with
        | None -> "./index.js"
        | Some entry -> entry
      in
      try
        let transpile _root_dir _filename =
          (* TODO: add filename check here *)
          FastpackTranspiler.transpile_source [
            (* FastpackTranspiler.ReactJSX.transpile; *)
          ]
        in
        `Ok (Fastpack.pack_main ~transpile entry)
      with
      | Fastpack.PackError (ctx, error) ->
        `Error (false, Fastpack.string_of_error ctx error)
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
