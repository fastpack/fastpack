module Process = FastpackUtil.Process;
module FS = FastpackUtil.FS;
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

let reportResult = (start_time, result, builder) =>
  switch (result) {
  | Error({Builder.reason, _}) =>
    let report = Context.errorToString(builder.Builder.current_dir, reason);
    Lwt_io.(write(stderr, report));
  | Ok(bundle) =>
    let cache = builder.Builder.cache;
    let size = Bundle.getTotalSize(bundle);
    let modules = DependencyGraph.length(bundle.Bundle.graph);
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
      Printf.sprintf(
        "Packed in %.3fs. Bundle: %s. Modules: %d. Cache: %s.\n",
        Unix.gettimeofday() -. start_time,
        pretty_size,
        modules,
        switch (builder.Builder.config.cache, Cache.isLoadedEmpty(cache)) {
        | (Config.Cache.Disable, _) => "disabled"
        | (Config.Cache.Use, true) => "empty"
        | (Config.Cache.Use, false) => "used"
        },
      );
    Lwt_io.(write(stdout, report));
  };

module Build = {
  let run = (options: Config.t, dryRun: bool) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt builder = Builder.make(options);

          Lwt.finalize(
            () => {
              let%lwt result = Builder.build(~dryRun, builder);
              let%lwt () = reportResult(start_time, result, builder);
              switch (result) {
              | Ok(_) => Cache.save(builder.Builder.cache)
              | _ => Lwt.return_unit
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

  let doc = "rebuild the bundle on a file change";
  let command =
    register((
      Term.(ret(const(run) $ Config.term $ dryRunT)),
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
      let process = Process.start(cmd);
      /* TODO: validate if process is started at all */
      let%lwt () = Process.write(subscribe_message ++ "\n", process);
      let%lwt _ = Process.readLine(process);
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
  let run = (options: Config.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          let start_time = Unix.gettimeofday();
          let%lwt builder = Builder.make(options);
          let%lwt result = Builder.build(builder);
          let%lwt () = reportResult(start_time, result, builder);
          let%lwt watchman =
            Watchman.make(
              options.projectRootDir,
              Builder.getFilenameFilter(builder),
            );

          let lastResult = ref(result);
          let lastResultCacheDumped = ref(None);
          let dumpCache = () =>
            switch (lastResult^) {
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

          let rec tryRebuilding = (files, prevResult) => {
            let%lwt nextResult =
              Lwt.pick([
                {
                  let%lwt files = Watchman.getFiles(watchman);
                  `FilesChanged(files) |> Lwt.return;
                },
                {
                  let%lwt result =
                    Builder.rebuild(
                      ~filesChanged=files,
                      ~prevResult,
                      builder,
                    );
                  `Rebuilt(result) |> Lwt.return;
                },
              ]);
            switch (nextResult) {
            | `FilesChanged(newFiles) =>
              tryRebuilding(StringSet.union(files, newFiles), prevResult)
            | `Rebuilt(result) => Lwt.return(result)
            };
          };

          let rec watch = result => {
            let%lwt files = Watchman.getFiles(watchman);
            let start_time = Unix.gettimeofday();
            switch%lwt (
              Builder.shouldRebuild(
                ~filesChanged=files,
                ~prevResult=result,
                builder,
              )
            ) {
            | None => watch(result)
            | Some(_) =>
              let%lwt () = FastpackUtil.Colors.clearScreen();
              let%lwt result = tryRebuilding(files, result);
              lastResult := result;
              let%lwt () = reportResult(start_time, result, builder);
              watch(result);
            };
          };

          Logs.debug(x => x("HERE!"));
          /* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
           * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
           * */
          let (w, u) = Lwt.wait();
          let exit = _ => Lwt.wakeup_exn(u, Context.ExitOK);
          Lwt_unix.on_signal(Sys.sigint, exit) |> ignore;
          Lwt_unix.on_signal(Sys.sigterm, exit) |> ignore;
          Lwt.Infix.(
            Lwt.finalize(
              () => watch(result) <&> FS.setInterval(5., dumpCache) <?> w,
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
      Term.(ret(const(run) $ Config.term)),
      Term.info("watch", ~doc, ~sdocs, ~exits),
    ));
};

module Worker = {
  let run = () => Lwt_main.run(Worker.start());
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
