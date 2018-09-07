let stat_option = path =>
  try%lwt (
    {
      let%lwt stat = Lwt_unix.stat(path);
      Lwt.return_some(stat);
    }
  ) {
  | Unix.Unix_error(_) => Lwt.return_none
  };

let rec setInterval = (ms, f) => {
  let%lwt () = Lwt_unix.sleep(ms);
  let%lwt () = f ();
  setInterval(ms, f);
}

let abs_path = (dir, filename) =>
  FilePath.reduce(~no_symlink=true) @@ FilePath.make_absolute(dir, filename);

let relative_path = (dir, filename) => {
  let relative = FilePath.make_relative(dir, filename);
  if (relative == "") {
    filename;
  } else {
    switch (relative.[0]) {
    | '.' => filename /* no single root */
    | _ => relative
    };
  };
};

let open_process = cmd => {
  /* TODO: handle Unix_error */
  let (fp_in, process_out) = Unix.pipe();
  let (process_in, fp_out) = Unix.pipe();
  let fp_in_ch = Lwt_io.of_unix_fd(~mode=Lwt_io.Input, fp_in);
  let fp_out_ch = Lwt_io.of_unix_fd(~mode=Lwt_io.Output, fp_out);
  let process =
    Lwt_process.(
      open_process_none(
        ~env=Unix.environment(),
        ~stdin=`FD_move(process_in),
        ~stdout=`FD_move(process_out),
        ~stderr=`Dev_null,
        shell(cmd),
      )
    );

  Lwt.return((process, fp_in_ch, fp_out_ch));
};

let rec makedirs = dir =>
  switch%lwt (stat_option(dir)) {
  | None =>
    let%lwt () = makedirs(FilePath.dirname(dir));
    Lwt_unix.mkdir(dir, 0o777);
  | Some(stat) =>
    switch (stat.st_kind) {
    | Lwt_unix.S_DIR => Lwt.return_unit
    | _ => Error.ie @@ Printf.sprintf("'%s' expected to be a directory", dir)
    }
  };

let try_dir = dir =>
  try%lwt (
    {
      let%lwt stat = Lwt_unix.stat(dir);
      switch (stat.st_kind) {
      | Lwt_unix.S_DIR => Lwt.return_some(dir)
      | _ => Lwt.return_none
      };
    }
  ) {
  | Unix.Unix_error(_) => Lwt.return_none
  };

let pat_text_ext =
  Re_posix.compile_pat("\\.(js|jsx|mjs|ts|tsx|css|sass|scss|less)$");
let is_text_file = filename =>
  switch (Re.exec_opt(pat_text_ext, filename)) {
  | Some(_) => true
  | None => false
  };

let isatty = channel => {
  let forceTTY =
    switch (Sys.getenv_opt("FPACK_FORCE_TTY")) {
    | Some("true") => true
    | _ => false
    };

  forceTTY || Unix.isatty(channel);
};
