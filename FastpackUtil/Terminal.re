let clearScreen = () =>
  switch (FS.isatty(Unix.stdout)) {
  | false => Lwt.return_unit
  | true =>
    let _ = Unix.system("clear");
    Lwt.return_unit;
  /* Lwt_io.(write(stdout, "\\033[2J\\033[1;1H")) */
  };
