let () = {
  let time = Unix.gettimeofday();
  open Cmdliner;

  let run_t = {
    let run =
        (
          entry_points,
          output_directory,
          output_filename,
          mode,
          mock,
          node_modules_paths,
          project_root_path,
          resolve_extension,
          target,
          cache,
          preprocess,
          postprocess,
          report,
          watch,
          debug,
        ) => {
      if (debug) {
        Logs.set_level(Some(Logs.Debug));
        Logs.set_reporter(Logs_fmt.reporter());
      };
      try (
        {
          let options = {
            Fastpack.entry_points,
            output_directory,
            output_filename,
            mode,
            mock: List.map(snd, mock),
            node_modules_paths,
            project_root_path,
            resolve_extension,
            target,
            cache,
            preprocess: List.map(snd, preprocess),
            postprocess,
            report,
            watch,
          };

          `Ok(Fastpack.pack_main(options, time));
        }
      ) {
      | Fastpack.ExitError(message) =>
        Lwt_main.run(Lwt_io.(write(stderr, message)));
        /* supress the default behaviour of the cmdliner, since it does a lot
         * of smart stuff */
        Format.(
          pp_set_formatter_out_functions(
            err_formatter,
            {
              out_string: (_, _, _) => (),
              out_flush: () => (),
              out_newline: () => (),
              out_spaces: _ => (),
              out_indent: _ => (),
            },
          )
        );
        `Error((false, message));
      | Fastpack.ExitOK => `Ok()
      };
    };

    let entry_points_t = {
      let doc = "Entry points. Default: ['.']";

      let docv = "ENTRY POINTS";
      Arg.(value & pos_all(string, ["."]) & info([], ~docv, ~doc));
    };

    let output_directory_t = {
      let doc =
        "Output Directory. " ++ "The target bundle will be $(docv)/index.js.";

      let docv = "DIR";
      Arg.(
        value & opt(string, "./bundle") & info(["o", "output"], ~docv, ~doc)
      );
    };

    let output_filename_t = {
      let doc =
        "Output File Name. " ++ "The target bundle filename will be $(docv)";

      let docv = "NAME";
      Arg.(
        value & opt(string, "index.js") & info(["n", "name"], ~docv, ~doc)
      );
    };

    let mode_t = {
      open Fastpack.Mode;
      let doc = "Build bundle for development";
      let development = (Development, Arg.info(["development"], ~doc));
      Arg.(value & vflag(Production, [development]));
    };

    let node_modules_path_t = {
      let doc =
        "Paths to 'node_modules' directory. Should be inside the project directory."
        ++ ". Defaults to ['node_modules']";

      let docv = "PATH";
      Arg.(
        value
        & opt_all(string, ["node_modules"])
        & info(["nm", "node-modules"], ~docv, ~doc)
      );
    };

    let project_root_path_t = {
      let doc =
        "Ancestor to which node_modules will be resolved."
        ++ ". Defaults to '.'";

      let docv = "PATH";
      Arg.(value & opt(string, ".") & info(["project-root"], ~docv, ~doc));
    };

    let mock_t = {
      let mock = Arg.conv(Fastpack.Resolver.Mock.(parse, print));

      let doc =
        "Mock PACKAGE requests with SUBSTITUTE requests. If SUBSTITUTE is omitted"
        ++ " empty module is used.";

      let docv = "PACKAGE[:SUBSTITUTE]";
      Arg.(value & opt_all(mock, []) & info(["mock"], ~docv, ~doc));
    };

    let resolve_extension_t = {
      let doc =
        "Provide extensions to be considered by the resolver for the "
        ++ "extension-less path. Extensions will be tried in the specified order."
        ++ " If no extension should be tried, provide '' as an argument. Defaults "
        ++ "to [.js, .json]";

      let docv = "EXTENSION";
      Arg.(
        value
        & opt_all(string, [".js", ".json"])
        & info(["resolve-extension"], ~docv, ~doc)
      );
    };

    let target_t = {
      let doc = "Deployment target.";
      let docv = "[ app | esm | cjs ]";
      let target =
        Arg.enum(
          Fastpack.Target.[
            ("app", Application),
            ("esm", ESM),
            ("cjs", CommonJS),
          ],
        );

      Arg.(
        value
        & opt(target, Fastpack.Target.Application)
        & info(["target"], ~docv, ~doc)
      );
    };

    let cache_t = {
      open Fastpack.Cache;
      let doc = "Do not use cache at all (effective in development mode only)";

      let disable = (Disable, Arg.info(["no-cache"], ~doc));
      Arg.(value & vflag(Use, [disable]));
    };

    let preprocess_t = {
      module P = Fastpack.Preprocessor;
      let preprocess = {
        let parse = s =>
          try (Result.Ok((false, P.of_string(s)))) {
          | Failure(msg) => Result.Error(`Msg(msg))
          };

        let print = (ppf, (_, opt)) =>
          Format.fprintf(ppf, "%s", P.to_string(opt));

        Arg.conv((parse, print));
      };

      let doc =
        "Preprocess modules matching the PATTERN with the PROCESSOR. Optionally,"
        ++ " the processor may receive some OPTIONS in form: 'x=y&a=b'. There are"
        ++ " 2 kinds of currently supported processors: 'builtin' and the "
        ++ "Webpack loader. 'builtin' preprocessor provides the following "
        ++ " transpilers: stripping Flow types, object spread & rest operators, "
        ++ "class properties (including statics), class/method decorators, and "
        ++ "React-assumed JSX conversion. 'builtin' may be skipped when setting "
        ++ "this option, i.e. '\\\\.js\\$' and '\\\\.js\\$:builtin' are "
        ++ "absolutely equal. An example of using the Webpack loader: "
        ++ "'\\\\.js\\$:babel-loader?filename=.babelrc'.";

      let docv = "PATTERN:PROCESSOR?OPTIONS[!...]";
      Arg.(
        value & opt_all(preprocess, []) & info(["preprocess"], ~docv, ~doc)
      );
    };

    let postprocess_t = {
      let doc =
        "Apply shell command on a bundle file. The content of the bundle will"
        ++ " be sent to STDIN and STDOUT output will be collected. If multiple"
        ++ " commands are specified they will be applied in the order of appearance";

      let docv = "COMMAND";
      Arg.(
        value & opt_all(string, []) & info(["postprocess"], ~docv, ~doc)
      );
    };

    let report_t = {
      let doc = "Output packer statistics";
      let docv = "[ json ]";
      let report =
        Arg.enum(Fastpack.Reporter.[("json", JSON), ("text", Text)]);

      Arg.(
        value
        & opt(report, Fastpack.Reporter.Text)
        & info(["report"], ~docv, ~doc)
      );
    };

    let watch_t = {
      let doc = "Watch file changes and rebuild bundle";
      Arg.(value & flag & info(["w", "watch"], ~doc));
    };

    let debug_t = {
      let doc = "Print debug output";
      Arg.(value & flag & info(["d", "debug"], ~doc));
    };

    Term.(
      ret(
        const(run)
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
        $ debug_t,
      )
    );
  };

  let info = {
    let doc = "Pack JavaScript code into a single bundle";

    let version =
      Fastpack.Version.(
        Printf.sprintf("%s (Commit: %s)", version, github_commit)
      );

    Term.info("fpack", ~version, ~doc, ~exits=Term.default_exits);
  };

  Term.exit @@ Term.eval((run_t, info));
};
