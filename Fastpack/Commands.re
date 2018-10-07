open Cmdliner;

let exits = Term.default_exits;
let sdocs = Manpage.s_common_options;
let version =
  Version.(Printf.sprintf("%s (Commit: %s)", version, github_commit));

let run = (debug, f) => {
  if (debug) {
    Logs.set_level(Some(Logs.Debug));
    Logs.set_reporter(Logs_fmt.reporter());
  };
  try (`Ok(f())) {
  | Config.ExitError(message)
  | Context.ExitError(message) =>
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
  | Context.ExitOK => `Ok()
  };
};

let cmds = ref([]);
let all = () => cmds^;
let register = cmd => {
  cmds := [cmd, ...cmds^];
  cmd;
};

module Build = {
  let run = (options: Config.t, dryRun: bool) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt packer = Packer.make(options);

          Lwt.finalize(
            () =>
              switch%lwt (
                Packer.pack(
                  ~dryRun,
                  ~graph=None,
                  ~current_location=None,
                  ~initial=true,
                  ~start_time,
                  packer,
                )
              ) {
              | Error(_) => raise(Context.ExitError(""))
              | Ok(ctx) => Cache.save(ctx.cache)
              },
            () => Packer.finalize(packer),
          );
        },
      )
    );

  let dryRunT = {
    let doc = "Run all the build operations without storing the bundle in the file system";
    Arg.(value & flag & info(["dry-run"], ~doc));
  };

  let doc = "rebuild the bundle on a file change";
  let command =
    register((
      Term.(ret(const(run) $ Config.term $ dryRunT)),
      Term.info("build", ~doc, ~sdocs, ~exits),
    ));
};

module Watch = {
  let run = (options: Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let%lwt {Watcher.watch, finalize} = Watcher.make(options);
          Lwt.finalize(watch, finalize);
        },
      )
    );
  let doc = "watch for file changes and rebuild the bundle";
  let command =
    register((
      Term.(ret(const(run) $ Config.term)),
      Term.info("watch", ~doc, ~sdocs, ~exits),
    ));
};

module Serve = {
  let run = (options: Config.t, serverConfig: FastpackServer.Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let (broadcastToWebsocket, devserver) =
            FastpackServer.Devserver.start(
              ~port=3000,
              ~outputDir=options.outputDir,
              ~config=serverConfig,
              ~debug=options.debug,
              (),
            );

          let%lwt () =
            FastpackServer.CopyPublic.copy(
              ~sourceDir="./public",
              ~outputDir=options.outputDir,
              ~outputFilename=options.outputFilename,
              ~port=3000,
              (),
            );
          let textReporter = Reporter.Text.make();
          let reportOk = (~message, ~start_time, ~files, ctx) => {
            print_endline("success");
            let%lwt () =
              Reporter.reportOk(
                ~message,
                ~start_time,
                ~files,
                ~ctx,
                textReporter,
              );
            Yojson.Basic.(
              `Assoc([("build", `String("OK"))])
              |> to_string(~std=true)
              |> (s => s ++ "\n")
              |> broadcastToWebsocket
            );
          };

          let reportError = (~error, ctx) => {
            print_endline("error");
            let%lwt () = Reporter.reportError(~error, ~ctx, textReporter);
            Yojson.Basic.(
              `Assoc([
                ("error", `String(Context.stringOfError(ctx, error))),
              ])
              |> to_string(~std=true)
              |> (s => s ++ "\n")
              |> broadcastToWebsocket
            );
          };

          let%lwt packer =
            Packer.make(
              ~reporter=Some(Reporter.make(reportOk, reportError, ())),
              {...options, mode: Mode.Development},
            );
          let%lwt {Watcher.watch, finalize} =
            Watcher.make(~packer=Some(packer), options);

          let (w, u) = Lwt.wait();
          let exit = _ => Lwt.wakeup_exn(u, Context.ExitOK);
          Lwt_unix.on_signal(Sys.sigint, exit) |> ignore;
          Lwt_unix.on_signal(Sys.sigterm, exit) |> ignore;
          Lwt.Infix.(
            Lwt.finalize(
              () => Lwt.join([devserver <?> w, watch()]),
              finalize,
            )
          );
        },
      )
    );
  let doc = "watch for file changes, rebuild bundle & serve";
  let command =
    register((
      /* TODO: add options here */
      Term.(ret(const(run) $ Config.term $ FastpackServer.Config.term)),
      Term.info("serve", ~doc, ~sdocs, ~exits),
    ));
};

module Worker = {
  let run = (options: Config.t) => {
    let {Config.projectRootDir: project_root, outputDir: output_dir, _} = options;
    Lwt_main.run(Worker.start(~project_root, ~output_dir, ()));
  };
  let doc = "worker subprocess (do not use directly)";
  let command =
    register((
      Term.(ret(const(run) $ Config.term)),
      Term.info("worker", ~doc, ~sdocs, ~exits),
    ));
};

module Help = {
  let run = () => `Help((`Auto, None));
  let command =
    register((
      Term.(ret(const(run) $ const())),
      Term.info(
        "help",
        ~version,
        ~doc="Show this message and exit",
        ~sdocs,
        ~exits,
      ),
    ));
};

module Default = {
  let man = [
    `S(Manpage.s_commands),
    `P(
      {|PLEASE NOTE: production mode is temporarily disabled. In the meantime,
please always use the `--development` flag.
|},
    ),
    `S(Manpage.s_bugs),
    `P("Report them to https://github.com/fastpack/fastpack/issues."),
  ];
  let command = (
    fst(Build.command),
    Term.info(
      "fpack",
      ~version,
      ~doc="Pack JavaScript code into a single bundle",
      ~sdocs,
      ~man,
      ~exits,
    ),
  );
};

let default = Default.command;
