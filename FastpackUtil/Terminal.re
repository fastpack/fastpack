type font =
  | Regular
  | Bold;

let print_with_color = (~font=Regular, ~color, str) => {
  let isTTY = FS.isatty(Unix.stderr);

  let f =
    switch (font) {
    | Regular => false
    | Bold => true
    };

  if (isTTY) {
    <Pastel bold=f color={color}>str</Pastel>
  } else {
    str;
  };
};

let clearScreen = () =>
  switch (FS.isatty(Unix.stdout)) {
  | false => Lwt.return_unit
  | true => let _ = Unix.system("clear"); Lwt.return_unit
  /* Lwt_io.(write(stdout, "\\033[2J\\033[1;1H")) */
  };
