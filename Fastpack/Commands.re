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

/* TODO: StringSet */
let cmds = ref([]);
let all = () => cmds^;
let register = cmd => {
  cmds := [cmd, ...cmds^];
  cmd;
};

module Build = {
  let run = (options: Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt {Packer.pack, finalize} = Packer.make(options);

          Lwt.finalize(
            () =>
              switch%lwt (
                pack(
                  ~graph=None,
                  ~current_location=None,
                  ~initial=true,
                  ~start_time,
                )
              ) {
              | Error(_) => raise(Context.ExitError(""))
              | Ok(ctx) => ctx.cache.dump()
              },
            finalize,
          );
        },
      )
    );
  let doc = "rebuild the bundle on a file change";
  let command =
    register((
      Term.(ret(const(run) $ Config.term)),
      Term.info("build", ~doc, ~sdocs, ~exits),
    ));
};

module Watch = {
  let run = (options: Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          /* TODO: maybe decouple mode from the CommonOptions ? */
          let%lwt {Packer.pack, finalize} =
            Packer.make({...options, mode: Mode.Development});

          Lwt.finalize(
            () =>
              switch%lwt (
                pack(
                  ~graph=None,
                  ~current_location=None,
                  ~initial=true,
                  ~start_time,
                )
              ) {
              | Error(_) => raise(Context.ExitError(""))
              | Ok(ctx) => Watcher.watch(~ctx, ~pack)
              },
            finalize,
          );
        },
      )
    );
  let doc = "build the bundle";
  let command =
    register((
      Term.(ret(const(run) $ Config.term)),
      Term.info("watch", ~doc, ~sdocs, ~exits),
    ));
};

module Serve = {
  let run = (options: Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();

          let (broadcastToWebsocket, devserver) =
            FastpackServer.Devserver.start(
              ~port=3000,
              ~outputDir=options.outputDir,
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

          let report_ok =
              (
                ~message as _message,
                ~start_time as _start_time,
                ~ctx as _ctx,
                ~files as _file,
              ) => {
            print_endline("built successfully!");

            Yojson.Basic.(
              `Assoc([("build", `String("OK"))])
              |> to_string(~std=true)
              |> (s => s ++ "\n")
              |> broadcastToWebsocket
            );
          };

          let report_error = (~ctx, ~error) => {
            print_endline("error occured!");

            Yojson.Basic.(
              `Assoc([
                ("error", `String(Context.stringOfError(ctx, error))),
              ])
              |> to_string(~std=true)
              |> (s => s ++ "\n")
              |> broadcastToWebsocket
            );
          };

          /* TODO: maybe decouple mode from the CommonOptions ? */
          let%lwt {Packer.pack, finalize} =
            Packer.make(
              ~report=Some(Reporter.Internal(report_ok, report_error)),
              {...options, mode: Mode.Development},
            );

          Lwt.finalize(
            () =>
              switch%lwt (
                pack(
                  ~graph=None,
                  ~current_location=None,
                  ~initial=true,
                  ~start_time,
                )
              ) {
              | Error(_) => raise(Context.ExitError(""))
              | Ok(ctx) =>
                /* super-functional web-server :) */
                let server = devserver;
                let watcher = Watcher.watch(~ctx, ~pack);
                Lwt.join([server, watcher]);
              },
            finalize,
          );
        },
      )
    );
  let doc = "watch for file changes, rebuild bundle & serve";
  let command =
    register((
      /* TODO: add options here */
      Term.(ret(const(run) $ Config.term)),
      Term.info("serve", ~doc, ~sdocs, ~exits),
    ));
};

module Worker = {
  let run = (options: Config.t) => {
    let {Config.projectRootDir: project_root, outputDir: output_dir, _} = options;
    Lwt_main.run(Worker.start(~project_root, ~output_dir));
  };
  let doc = "worker subprocess (don't use directly)";
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
  let command = (
    fst(Build.command),
    Term.info(
      "fpack",
      ~version,
      ~doc="Pack JavaScript code into a single bundle",
      ~sdocs,
      ~exits,
    ),
  );
};

let default = Default.command;
