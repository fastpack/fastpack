let () =
  let open Cmdliner in

  let run_t =

    let run
        input
        output
        flat
        development
        transpile_all
        transpile_react_jsx
        transpile_flow
        transpile_class
        transpile_object_spread
      =
      try
        let options =
          { Fastpack.empty_options with
            input;
            output;
            flat = Some flat;
            development = Some development;
          }
        in
        let options =
          match transpile_all with
          | [] -> options
          | patterns ->
            { options with
              transpile_react_jsx = Some patterns;
              transpile_flow = Some patterns;
              transpile_class = Some patterns;
              transpile_object_spread = Some patterns;
            }
        in
        let options =
          match transpile_react_jsx with
          | [] -> options
          | patterns -> { options with transpile_react_jsx = Some patterns}
        in
        let options =
          match transpile_flow with
          | [] -> options
          | patterns -> { options with transpile_flow = Some patterns}
        in
        let options =
          match transpile_class with
          | [] -> options
          | patterns -> { options with transpile_class = Some patterns}
        in
        let options =
          match transpile_object_spread with
          | [] -> options
          | patterns -> { options with transpile_object_spread = Some patterns}
        in
        `Ok (Fastpack.pack_main options)
      with
      | Fastpack.PackError (ctx, error) ->
        `Error (false, Fastpack.string_of_error ctx error)
    in


    let input_t =
      let doc = "Entry point JavaScript file (main in package.json)" in
      let docv = "INPUT" in
      Arg.(value & pos 0 (some string) None & info [] ~docv ~doc)
    in

    let output_t =
      let doc = "Output JavaScript file (fastpack.output in package.json)" in
      let docv = "OUTPUT" in
      Arg.(value & opt (some string) None & info ["o"; "output"] ~docv ~doc)
    in

    let flat_t =
      let doc = "Build flat bundle (fastpack.flat in package.json)" in
      let docv = "FLAG" in
      Arg.(value & flag & info ["flat"] ~docv ~doc)
    in

    let dev_t =
      let doc = "Build development bundle (fastpack.development in package.json)" in
      let docv = "DEVELOPMENT" in
      Arg.(value & flag & info ["dev"] ~docv ~doc)
    in

    let transpile_all =
      let doc =
        "[Experimental] Apply all transpilers to files matching $(docv)"
        ^ "\n(fastpack.transpile_all in package.json)"
      in
      let docv = "PATTERN" in
      Arg.(value & opt_all string [] & info ["transpile-all"] ~docv ~doc)
    in

    let transpile_react_jsx =
      let doc =
        "[Experimental] Apply React JSX transpiler to files matching $(docv)"
        ^ "\n(fastpack.transpile_react_jsx in package.json)"
      in
      let docv = "PATTERN" in
      Arg.(value & opt_all string [] & info ["transpile-react-jsx"] ~docv ~doc)
    in

    let transpile_flow =
      let doc =
        "[Experimental] Apply Flow transpiler to files matching $(docv)"
        ^ "\n(fastpack.transpile_flow in package.json)"
      in
      let docv = "PATTERN" in
      Arg.(value & opt_all string [] & info ["transpile-flow"] ~docv ~doc)
    in

    let transpile_class =
      let doc =
        "[Experimental] Apply `class` syntax transpiler to files matching $(docv)"
        ^ "\n(fastpack.transpile_class in package.json)"
      in
      let docv = "PATTERN" in
      Arg.(value & opt_all string [] & info ["transpile-class"] ~docv ~doc)
    in

    let transpile_object_spread =
      let doc =
        "[Experimental] Apply `...` syntax transpiler to files matching $(docv)"
        ^ "\n(fastpack.transpile_object_spread in package.json)"
      in
      let docv = "PATTERN" in
      Arg.(value & opt_all string [] & info ["transpile-object-spread"] ~docv ~doc)
    in

    Term.(ret (const run
               $ input_t
               $ output_t
               $ flat_t
               $ dev_t
               $ transpile_all
               $ transpile_react_jsx
               $ transpile_flow
               $ transpile_class
               $ transpile_object_spread
              ))
  in

  let info =
    let doc =
      "Pack JavaScript code into a single bundle"
    in
    Term.info "fpack" ~version:"preview" ~doc ~exits:Term.default_exits
  in

  Term.exit @@ Term.eval (run_t, info)
