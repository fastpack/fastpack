let () =
  let time = Unix.gettimeofday () in
  let open Cmdliner in

  let run_t =

    let run
        input
        output
        mode
        target
        cache
        preprocess
        postprocess
        stats
        debug
        watch
      =
      if debug then begin
        Logs.set_level (Some Logs.Debug);
        Logs.set_reporter (Logs_fmt.reporter ());
      end;
      try
        let options =
          { Fastpack.
            input;
            output;
            mode = Some mode;
            target;
            cache = Some cache;
            preprocess = Some (List.map snd preprocess);
            postprocess = Some postprocess;
            stats;
            watch = Some watch;
          }
        in
        `Ok (Fastpack.pack_main options time)
      with
      | Fastpack.PackError (ctx, error) ->
        `Error (false, Fastpack.string_of_error ctx error)
    in


    let input_t =
      let doc =
        "Entry point JavaScript file"
      in
      let docv = "INPUT" in
      Arg.(value & pos 0 (some string) None & info [] ~docv ~doc)
    in

    let output_t =
      let doc =
        "Output Directory. "
        ^ "The target bundle will be $(docv)/index.js. 'bundle' is used by default"
      in
      let docv = "DIR" in
      Arg.(value & opt (some string) None & info ["o"; "output"] ~docv ~doc)
    in

    let mode_t =
      let open Fastpack.Mode in
      let doc = "Build bundle for development" in
      let development = Development, Arg.info ["development"] ~doc in
      Arg.(value & vflag Production [development])
    in

    let target_t =
      let doc = "Deployment target." in
      let docv = "[ app | esm | cjs ]" in
      let target =
        Arg.enum [
          "app", Fastpack.Target.Application;
          "esm", Fastpack.Target.ESM;
          "cjs", Fastpack.Target.CommonJS;
        ]
      in
      Arg.(value & opt (some target) None & info ["target"] ~docv ~doc)
    in

    let cache_t =
        let open Fastpack.Cache in
        let doc = "Do not use cache at all" in
        let ignore = Ignore, Arg.info ["no-cache"] ~doc in
        Arg.(value & vflag Normal [ignore])
    in

    let preprocess_t =
      let module P = Fastpack.Preprocessor in
      let preprocess =
        let parse s =
          try
            Result.Ok (false, P.of_string s)
          with
          | Failure msg ->
            Result.Error (`Msg msg)
        in
        let print ppf (_, opt) =
          Format.fprintf ppf "%s" (P.to_string opt)
        in
        Arg.conv (parse, print)
      in
      let doc =
        "Preprocess modules matching the PATTERN with the PROCESSOR. Optionally,"
        ^ " the processor may receive some OPTIONS in form: 'x=y&a=b'. There are"
        ^ " 2 kinds of currently supported processors: 'builtin' and the "
        ^ "Webpack loader. 'builtin' preprocessor provides the following "
        ^ " transpilers: stripping Flow types, object spread & rest operators, "
        ^ "class properties (including statics), class/method decorators, and "
        ^ "React-assumed JSX conversion. 'builtin' may be skipped when setting "
        ^ "this option, i.e. '\\\\.js\\$' and '\\\\.js\\$:builtin' are "
        ^ "absolutely equal. An example of using the Webpack loader: "
        ^ "'\\\\.js\\$:babel-loader?filename=.babelrc'."
      in
      let docv = "PATTERN:PROCESSOR?OPTIONS" in
      Arg.(value & opt_all preprocess [] & info ["preprocess"] ~docv ~doc)
    in

    let postprocess_t =
      let doc =
        "Apply shell command on a bundle file. The content of the bundle will"
        ^ " be sent to STDIN and STDOUT output will be collected. If multiple"
        ^ " commands are specified they will be applied in the order of appearance"
      in
      let docv = "COMMAND" in
      Arg.(value & opt_all string [] & info ["postprocess"] ~docv ~doc)
    in

    let stats_t =
      let doc = "Command output stats" in
      let docv = "[ json ]" in
      let target =
        Arg.enum [
          "json", Fastpack.Stats.JSON;
        ]
      in
      Arg.(value & opt (some target) None & info ["stats"] ~docv ~doc)
    in

    let watch_t =
      let doc = "Watch file changes and rebuild bundle" in
      Arg.(value & flag & info ["w"; "watch"] ~doc)
    in

    let debug_t =
      let doc = "Print debug output" in
      Arg.(value & flag & info ["d"; "debug"] ~doc)
    in

    Term.(ret (
        const run
        $ input_t
        $ output_t
        $ mode_t
        $ target_t
        $ cache_t
        $ preprocess_t
        $ postprocess_t
        $ stats_t
        $ watch_t
        $ debug_t
    ))
  in

  let info =
    let doc =
      "Pack JavaScript code into a single bundle"
    in
    let version = Fastpack.Version.(
        Printf.sprintf "%s (Commit: %s)" version github_commit
      )
    in
    Term.info "fpack" ~version ~doc ~exits:Term.default_exits
  in

  Term.exit @@ Term.eval (run_t, info)
