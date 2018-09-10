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
  let%lwt () = f();
  setInterval(ms, f);
};

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

let copy_file = (~source, ~target, ()): Lwt.t(unit) => {
  let%lwt sourceFile = Lwt_io.open_file(~mode=Lwt_io.Input, source);
  let%lwt targetFile = Lwt_io.open_file(~mode=Lwt_io.Output, target);

  let%lwt file = Lwt_io.read(sourceFile);
  let%lwt () = Lwt_io.write(targetFile, file);

  let%lwt () = Lwt_io.close(sourceFile);
  let%lwt () = Lwt_io.close(targetFile);

  Lwt.return();
};
