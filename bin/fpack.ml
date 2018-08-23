let () =
  let time = Unix.gettimeofday () in
  let open Cmdliner in

  let run_t =

    let run
        entry_points
        output_directory
        output_filename
        mode
        mock
        node_modules_paths
        project_root_path
        resolve_extension
        target
        cache
        preprocess
        postprocess
        report
        watch
        debug
      =
      if debug then begin
        Logs.set_level (Some Logs.Debug);
        Logs.set_reporter (Logs_fmt.reporter ());
      end;
      try
        let options =
          { Fastpack.
            entry_points;
            output_directory;
            output_filename;
            mode;
            mock = (List.map snd mock);
            node_modules_paths;
            project_root_path;
            resolve_extension;
            target;
            cache;
            preprocess = (List.map snd preprocess);
            postprocess;
            report;
            watch;
          }
        in
        `Ok (Fastpack.pack_main options time)
      with
      | Fastpack.ExitError message ->
        Lwt_main.run (Lwt_io.(write stderr message));
        (* supress the default behaviour of the cmdliner, since it does a lot
         * of smart stuff *)
        Format.(
          pp_set_formatter_out_functions
            err_formatter
            { out_string = (fun _ _ _ -> ());
              out_flush = (fun () -> ());
              out_newline = (fun () -> ());
              out_spaces = (fun _ -> ());
              out_indent = (fun _ -> ());
            }
        );
        `Error (false, message)
      | Fastpack.ExitOK ->
        `Ok ()
    in


    let entry_points_t =
      let doc =
        "Entry points. Default: ['.']"
      in
      let docv = "ENTRY POINTS" in
      Arg.(value & pos_all string ["."] & info [] ~docv ~doc)
    in

    let output_directory_t =
      let doc =
        "Output Directory. "
        ^ "The target bundle will be $(docv)/index.js."
      in
      let docv = "DIR" in
      Arg.(value & opt string "./bundle" & info ["o"; "output"] ~docv ~doc)
    in

    let output_filename_t =
      let doc =
        "Output File Name. "
        ^ "The target bundle filename will be $(docv)"
      in
      let docv = "NAME" in
      Arg.(value & opt string "index.js" & info ["n"; "name"] ~docv ~doc)
    in

    let mode_t =
      let open Fastpack.Mode in
      let doc = "Build bundle for development" in
      let development = Development, Arg.info ["development"] ~doc in
      Arg.(value & vflag Production [development])
    in

    let node_modules_path_t =
      let doc =
        "Paths to 'node_modules' directory. Should be inside the project directory."
        ^ ". Defaults to ['node_modules']"
      in
      let docv = "PATH" in
      Arg.(value & opt_all string ["node_modules"] & info ["nm"; "node-modules"] ~docv ~doc)
    in

    let project_root_path_t =
      let doc =
        "Ancestor to which node_modules will be resolved."
        ^ ". Defaults to '.'"
      in
      let docv = "PATH" in
      Arg.(value & opt string "." & info ["project-root"] ~docv ~doc)
    in

    let mock_t =
      let mock =
        Arg.conv Fastpack.Resolver.Mock.(parse, print)
      in
      let doc =
        "Mock PACKAGE requests with SUBSTITUTE requests. If SUBSTITUTE is omitted"
        ^ " empty module is used."
      in
      let docv = "PACKAGE[:SUBSTITUTE]" in
      Arg.(value & opt_all mock [] & info ["mock"] ~docv ~doc)
    in

    let resolve_extension_t =
      let doc =
        "Provide extensions to be considered by the resolver for the "
        ^ "extension-less path. Extensions will be tried in the specified order."
        ^ " If no extension should be tried, provide '' as an argument. Defaults "
        ^ "to [.js, .json]"
      in
      let docv = "EXTENSION" in
      Arg.(value & opt_all string [".js"; ".json"] & info ["resolve-extension"] ~docv ~doc)
    in

    let target_t =
      let doc = "Deployment target." in
      let docv = "[ app | esm | cjs ]" in
      let target =
        Arg.enum Fastpack.Target.[
          "app", Application;
          "esm", ESM;
          "cjs", CommonJS;
        ]
      in
      Arg.(value & opt target Fastpack.Target.Application & info ["target"] ~docv ~doc)
    in

    let cache_t =
        let open Fastpack.Cache in
        let doc =
          "Do not use cache at all (effective in development mode only)"
        in
        let disable = Disable, Arg.info ["no-cache"] ~doc in
        Arg.(value & vflag Use [disable])
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
      let docv = "PATTERN:PROCESSOR?OPTIONS[!...]" in
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

    let report_t =
      let doc = "Output packer statistics" in
      let docv = "[ json ]" in
      let report =
        Arg.enum Fastpack.Reporter.[
          "json", JSON;
          "text", Text;
        ]
      in
      Arg.(value & opt report Fastpack.Reporter.Text & info ["report"] ~docv ~doc)
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
        $ entry_points_t
        $ output_directory_t
        $ output_filename_t
        $ mode_t
        $ mock_t
        $ node_modules_path_t
        $ project_root_path_t
        $ resolve_extension_t
        $ target_t
        $ cache_t
        $ preprocess_t
        $ postprocess_t
        $ report_t
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
