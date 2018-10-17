type color =
  | Cyan
  | Red
  | Black
  | White;

type font =
  | Regular
  | Bold;

let print_with_color = (~font=Regular, ~isTTY=true, str, col) => {
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