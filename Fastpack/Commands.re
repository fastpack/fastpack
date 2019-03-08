module Process = FastpackUtil.Process;
module FS = FastpackUtil.FS;
module Terminal = FastpackUtil.Terminal;
module StringSet = Set.Make(CCString);
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
  | Error.ExitError(message) =>
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
  | Error.ExitOK => `Ok()
  };
};

let cmds = ref([]);
let all = () => cmds^;
let register = cmd => {
  cmds := [cmd, ...cmds^];
  cmd;
};

let reportCache = builder => {
  let {Builder.config, cache, _} = builder;
  let report =
    Printf.sprintf(
      "Cache: %s",
      switch (Config.isCacheDisabled(config), Cache.isLoadedEmpty(cache)) {
      | (true, _) => "disabled"
      | (false, true) => "empty"
      | (false, false) => "used"
      },
    );
  Lwt_io.(write_line(stdout, report));
};

let reportWarnings = bundle => switch%lwt(Bundle.getWarnings(bundle)) {
  | Some(warnings) => Lwt_io.(write_line(stdout, warnings));
  | None => Lwt.return_unit
};

let reportResult = (start_time, result, builder) =>
  switch (result) {
  | Error({Builder.reason, _}) =>
    let report = Error.toString(builder.Builder.current_dir, reason);
    Lwt_io.(write(stderr, report));
  | Ok(bundle) =>
    let%lwt () = reportWarnings(bundle);
    let size = Bundle.getTotalSize(bundle);
    let modules = DependencyGraph.length(bundle |> Bundle.getGraph);
    let pretty_size =
      Printf.(
        if (size >= 1048576) {
          sprintf("%.2fMb", float_of_int(size) /. 1048576.0);
        } else if (size >= 1024) {
          sprintf(
            "%dKb",
            float_of_int(size) /. 1024.0 +. 0.5 |> floor |> int_of_float,
          );
        } else {
          sprintf("%db", size);
        }
      );
    let report =
      Terminal.(
        print_with_color(
          ~font=Bold,
          ~color=Green,
          Printf.sprintf(
            "Done in %.3fs. Bundle: %s. Modules: %d.\n",
            Unix.gettimeofday() -. start_time,
            pretty_size,
            modules,
          ),
        )
      );
    Lwt_io.(write_line(stdout, report));
  };

module ExplainConfig = {
  let run = (config: Lwt.t(Config.t)) =>
    run(false, () =>
      Lwt_main.run(
        {
          let%lwt config = config;
          Lwt_io.(write(stdout, Config.prettyPrint(config)));
        },
      )
    );


  let doc = "load, validate, and explain the configuration";
  let command =
    register((
      Term.(ret(const(run) $ Config.term)),
      Term.info("explain-config", ~doc, ~sdocs, ~exits),
    ));
};

module Build = {
  let run = (config: Lwt.t(Config.t), debug: bool, dryRun: bool, one: bool) =>
    run(debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt config = config;
          let%lwt builder = Builder.make(config);
          let%lwt () = reportCache(builder);
          Lwt.finalize(
            () => {
              let%lwt result = Builder.build(~one, ~dryRun, builder);
              let%lwt () = reportResult(start_time, result, builder);
              switch (result) {
              | Ok(_) => Cache.save(builder.Builder.cache)
              | Error(_) => raise(Error.ExitError(""))
              };
            },
            () => Builder.finalize(builder),
          );
        },
      )
    );

  let dryRunT = {
    let doc = "all the build operations without storing the bundle in the file system";
    Arg.(value & flag & info(["dry-run"], ~doc));
  };

  let oneT = {
    let doc = "process one module disregarding its dependencies and output the information";
    Arg.(value & flag & info(["one-module"], ~doc));
  };

  let doc = "rebuild the bundle on a file change";
  let command =
    register((
      Term.(ret(const(run) $ Config.term $ Config.debugT  $ dryRunT $ oneT)),
      Term.info("build", ~doc, ~sdocs, ~exits),
    ));
};

module Transpile = {
  let run = (filename: string) =>
    Lwt_main.run(
      {
        let all_transpilers =
          FastpackTranspiler.[
            ReactJSX.transpile,
            StripFlow.transpile,
            Class.transpile,
            ObjectSpread.transpile,
          ];
        let%lwt source = Lwt_io.(with_file(~mode=Input, filename, read));
        /* let%lwt (transpiled, _, _) = Preprocessor.builtin(Some(source)); */
        let t = Unix.gettimeofday();
        let (program, _) = FastpackUtil.Parser.parse_source(source);
        let%lwt () =
          Lwt_io.(
            write_line(
              stdout,
              Printf.sprintf("Parse: %3.3f", Unix.gettimeofday() -. t),
            )
          );
        let (_transpiled, parsed) =
          FastpackTranspiler.transpile(all_transpilers, program);
        let%lwt () =
          Lwt_io.(
            write_line(
              stdout,
              Printf.sprintf("Transpile: %3.3f", Unix.gettimeofday() -. t),
            )
          );
        let%lwt () = Lwt_io.(write_line(stdout, FastpackTranspiler.runtime));
        switch (parsed) {
        | Some(_) =>
          Lwt_io.(
            write_line(
              stdout,
              Printf.sprintf("Not modified %3.3f", Unix.gettimeofday() -. t),
            )
          )
        | None =>
          Lwt_io.(
            write_line(
              stdout,
              Printf.sprintf("Modified %3.3f", Unix.gettimeofday() -. t),
            )
          )
        };
        /* Lwt_io.(write_line(stdout, transpiled)); */
      },
    );

  let filenameT = {
    let doc = "Filename";

    let docv = "FILENAME";
    Arg.(required & pos(0, some(string), None) & info([], ~docv, ~doc));
  };
  let doc = "transpile one file using the builtin transpiler";
  let command =
    register((
      Term.(const(run) $ filenameT),
      Term.info("transpile", ~doc, ~sdocs, ~exits),
    ));
};

module Watch = {
  module Watchman = {
    type t = {
      root: string,
      process: Process.t,
      filterFilename: string => bool,
    };

    let make = (root, filterFilename) => {
      let subscription = Printf.sprintf("s-%f", Unix.gettimeofday());
      let subscribe_message =
        `List([
          `String("subscribe"),
          `String(root),
          `String(subscription),
          `Assoc([("fields", `List([`String("name")]))]),
        ])
        |> Yojson.to_string;

      let cmd = [|"watchman", "--no-save-state", "-j", "--no-pretty", "-p"|];
      let%lwt () = Lwt_io.(write_line(stdout, "Starting watchman..."));
      let process = Process.start(cmd);
      let%lwt _ =
        Lwt.catch(
          () => {
            let%lwt () = Process.write(subscribe_message ++ "\n", process);
            Process.readLine(process);
          },
          fun
          | Process.NotRunning(msg) =>
            raise(
              Error.ExitError(
                Printf.sprintf(
                  {|
%s

Unssuccessfully tried to start watchman using the following command:
  %s

It looks, like your system doesn't have it installed. Please, check here
for installation instructions:
  https://facebook.github.io/watchman/
          |},
                  Terminal.print_with_color(
                    ~font=Bold,
                    ~color=Red,
                    "Cannot start file watching service: watchman",
                  ),
                  msg,
                ),
              ),
            )
          | exn => raise(exn),
        );
      /* TODO: validate answer */
      /*{"version":"4.9.0","subscribe":"mysubscriptionname","clock":"c:1523968199:68646:1:95"}*/
      /* this line is ignored, receiving possible files */
      let%lwt _ = Process.readLine(process);
      Lwt.return({root, filterFilename, process});
    };

    let rec getFiles = (watchman: t) => {
      let%lwt line = Process.readLine(watchman.process);
      open Yojson.Safe.Util;
      let data = Yojson.Safe.from_string(line);
      let root = member("root", data) |> to_string;
      let files =
        member("files", data)
        |> to_list
        |> List.map(to_string)
        |> List.map(filename => FS.abs_path(root, filename))
        |> List.filter(watchman.filterFilename)
        |> List.fold_left(
             (set, filename) => StringSet.add(filename, set),
             StringSet.empty,
           );
      if (files == StringSet.empty) {
        getFiles(watchman);
      } else {
        Lwt.return(files);
      };
    };

    let finalize = watchman => Process.finalize(watchman.process);
  };
  let run = (config: Lwt.t(Config.t), debug) =>
    run(debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt config = config;
          let%lwt builder = Builder.make(config);
          let%lwt () = reportCache(builder);
          let%lwt result = Builder.build(builder);
          let%lwt () = reportResult(start_time, result, builder);
          let%lwt watchman =
            Watchman.make(
              Config.projectRootDir(config),
              Builder.getFilenameFilter(builder),
            );

          let changedFiles = ref(StringSet.empty);
          let changedFilesLock = Lwt_mutex.create();

          let rec collectFileChanges = () => {
            let%lwt files = Watchman.getFiles(watchman);
            let%lwt () =
              Lwt_mutex.with_lock(
                changedFilesLock,
                () => {
                  changedFiles := StringSet.union(changedFiles^, files);
                  Lwt.return_unit;
                },
              );
            collectFileChanges();
          };

          let readChangedFiles = () =>
            Lwt_mutex.with_lock(
              changedFilesLock,
              () => {
                let ret = changedFiles^;
                changedFiles := StringSet.empty;
                Lwt.return(ret);
              },
            );

          let lastResult = ref(result);
          let lastResultLock = Lwt_mutex.create();

          let readLastResult = () =>
            Lwt_mutex.with_lock(lastResultLock, () =>
              Lwt.return(lastResult^)
            );

          let storeLastResult = result =>
            Lwt_mutex.with_lock(
              lastResultLock,
              () => {
                lastResult := result;
                Lwt.return_unit;
              },
            );

          let rec rebuild = () => {
            let start_time = Unix.gettimeofday();
            let%lwt filesChanged = readChangedFiles();
            let%lwt prevResult = readLastResult();
            let%lwt () =
              switch%lwt (
                Builder.shouldRebuild(~filesChanged, ~prevResult, builder)
              ) {
              | None => Lwt_unix.sleep(0.02)
              | Some(_) =>
                let%lwt () = Terminal.clearScreen();
                let n = 3;
                let elements = StringSet.elements(filesChanged);
                let message =
                  "Files changed: \n"
                  ++ String.concat(
                       "\n",
                       List.map(f => "    " ++ f, CCList.take(n, elements)),
                     )
                  ++ (
                    List.length(elements) >= n ?
                      Printf.sprintf(
                        "\n    and %d more.\n",
                        List.length(elements) - n,
                      ) :
                      "\n"
                  );
                let%lwt () = Lwt_io.(write_line(stdout, message));

                let%lwt result =
                  Lwt.protected(
                    Builder.rebuild(~filesChanged, ~prevResult, builder),
                  );
                let%lwt () = reportResult(start_time, result, builder);
                storeLastResult(result);
              };
            rebuild();
          };

          let lastResultCacheDumped = ref(None);
          let dumpCache = () =>
            switch%lwt (readLastResult()) {
            | Ok(_) =>
              let dump = result => {
                let%lwt () = Cache.save(builder.Builder.cache);
                lastResultCacheDumped := Some(result);
                Lwt.return_unit;
              };
              switch (lastResultCacheDumped^) {
              | None => dump(lastResult^)
              | Some(lastResultCacheDumped) =>
                if (lastResult^ !== lastResultCacheDumped) {
                  dump(lastResult^);
                } else {
                  Lwt.return_unit;
                }
              };
            | Error(_) => Lwt.return_unit
            };

          /* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
           * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
           * */
          let (w, u) = Lwt.wait();
          let exit = _ => Lwt.wakeup_exn(u, Error.ExitOK);
          Lwt_unix.on_signal(Sys.sigint, exit) |> ignore;
          Lwt_unix.on_signal(Sys.sigterm, exit) |> ignore;
          let%lwt () =
            Lwt_io.(
              write_line(
                stdout,
                Printf.sprintf(
                  "Watching directory: %s. (Ctrl+C to exit)",
                  Config.projectRootDir(config),
                ),
              )
            );
          Lwt.Infix.(
            Lwt.finalize(
              () =>
                collectFileChanges()
                <&> rebuild()
                <&> FS.setInterval(5., dumpCache)
                <?> w,
              () => {
                let%lwt () = Watchman.finalize(watchman);
                let%lwt () = Builder.finalize(builder);
                Lwt.return_unit;
              },
            )
          );
        },
      )
    );
  let doc = "watch for file changes and rebuild the bundle";
  let command =
    register((
      Term.(ret(const(run) $ Config.term $ Config.debugT)),
      Term.info("watch", ~doc, ~sdocs, ~exits),
    ));
};

module Worker = {
  let worker =
    Worker.(
      make(
        ~init=initFromParent,
        ~input=inputFromParent,
        ~output=outputToParent,
        ~serveForever=true,
        (),
      )
    );
  let run = () =>
    Lwt_main.run(Worker.start(worker));
  let doc = "worker subprocess (do not use directly)";
  let command =
    register((
      Term.(const(run) $ const()),
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
