let () = {
  /* let time = Unix.gettimeofday(); */

  /* let run_t = { */
  /*   let run = options => { */
  /*     if (options.Fastpack.CommonOptions.debug) { */
  /*       Logs.set_level(Some(Logs.Debug)); */
  /*       Logs.set_reporter(Logs_fmt.reporter()); */
  /*     }; */
  /*     try (`Ok(Fastpack.pack_main(options, time))) { */
  /*     | Fastpack.ExitError(message) => */
  /*       Lwt_main.run(Lwt_io.(write(stderr, message))); */
  /*       /1* supress the default behaviour of the cmdliner, since it does a lot */
  /*        * of smart stuff *1/ */
  /*       Format.( */
  /*         pp_set_formatter_out_functions( */
  /*           err_formatter, */
  /*           { */
  /*             out_string: (_, _, _) => (), */
  /*             out_flush: () => (), */
  /*             out_newline: () => (), */
  /*             out_spaces: _ => (), */
  /*             out_indent: _ => (), */
  /*           }, */
  /*         ) */
  /*       ); */
  /*       `Error((false, message)); */
  /*     | Fastpack.ExitOK => `Ok() */
  /*     }; */
  /*   }; */

  /*   Term.(ret(const(run) $ Fastpack.CommonOptions.term)); */
  /* }; */

  /* let info = { */
  /*   let doc = "Pack JavaScript code into a single bundle"; */

  /*   let version = */
  /*     Fastpack.Version.( */
  /*       Printf.sprintf("%s (Commit: %s)", version, github_commit) */
  /*     ); */

  /*   Term.info("fpack", ~version, ~doc, ~exits=Term.default_exits); */
  /* }; */

  Cmdliner.(Term.exit @@ Fastpack.Commands.(Term.eval_choice(default, all)));
};
