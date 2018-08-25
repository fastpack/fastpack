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

module Build = {
  let run = (options: CommonOptions.t) =>
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
              | Ok(_) => Lwt.return_unit
              },
            finalize,
          );
        },
      )
    );
  let doc = "rebuild the bundle on a file change";
  let command = (
    Term.(ret(const(run) $ CommonOptions.term)),
    Term.info("watch", ~doc, ~sdocs, ~exits),
  );
};

module Watch = {
  let run = (options: CommonOptions.t) =>
    run(options.debug, () =>
      Lwt_main.run(
        {
          /* TODO: maybe decouple mode from the CommonOptions ? */
          let options = {...options, mode: Mode.Development};
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
              | Ok(_) => Lwt.return_unit
              },
            finalize,
          );
        },
      )
    );
  let doc = "build the bundle";
  let command = (
    Term.(ret(const(run) $ CommonOptions.term)),
    Term.info("build", ~doc, ~sdocs, ~exits),
  );
};

module Help = {
  let run = () => `Help((`Auto, None));
  let command = (
    Term.(ret(const(run) $ const())),
    Term.info(
      "help",
      ~version,
      ~doc="Show this message and exit",
      ~sdocs,
      ~exits,
    ),
  );
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

let all = [Build.command, Help.command];
let default = Default.command;
