type color =
  | Cyan
  | Red
  | Black
  | White;

type font =
  | Regular
  | Bold;

let print_with_color = (~font=Regular, str, col) => {
  let isTTY = FS.isatty(Unix.stderr);
  let col =
    switch (col) {
    | Cyan => "36"
    | Red => "31"
    | Black => "30"
    | White => "37"
    };

  let f =
    switch (font) {
    | Regular => "0"
    | Bold => "1"
    };

  if (isTTY) {
    "\027[" ++ f ++ ";" ++ col ++ "m" ++ str ++ "\027[0m";
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
