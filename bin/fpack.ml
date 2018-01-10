let () =
  let open Cmdliner in

  let run_t =

    let run
        input
        output
        bundle
        mode
        target
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
            bundle;
            mode;
            target;
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

    let bundle_t =
      let doc =
        "Bundle type [ regular / flat ] (fastpack.flat in package.json)"
      in
      let docv = "[ regular | flat ]" in
      let bundle =
        Arg.enum [
          "regular", Fastpack.Regular;
          "flat", Fastpack.Flat;
        ]
      in
      Arg.(value & opt (some bundle) None & info ["bundle"] ~docv ~doc)
    in

    let mode_t =
      let doc = "process.env.NODE_ENV (fastpack.mode in package.json)" in
      let docv = "[ production | development | test ]" in
      let mode =
        Arg.enum [
          "production", Fastpack.Mode.Production;
          "development", Fastpack.Mode.Development;
          "test", Fastpack.Mode.Test;
        ]
      in
      Arg.(value & opt (some mode) None & info ["mode"] ~docv ~doc)
    in

    let target_t =
      let doc = "Deployment target (fastpack.target in package.json)" in
      let docv = "[ app | es6 | cjs ]" in
      let target =
        Arg.enum [
          "app", Fastpack.Target.Application;
          "es6", Fastpack.Target.EcmaScript6;
          "cjs", Fastpack.Target.CommonJS;
        ]
      in
      Arg.(value & opt (some target) None & info ["target"] ~docv ~doc)
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

    Term.(ret (
        const run
        $ input_t
        $ output_t
        $ bundle_t
        $ mode_t
        $ target_t
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

  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ());
  Term.exit @@ Term.eval (run_t, info)
