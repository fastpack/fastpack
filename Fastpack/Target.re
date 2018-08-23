type t =
  | Application
  | ESM
  | CommonJS;

let to_string = (t: t) =>
  switch (t) {
  | Application => "Application"
  | ESM => "EcmaScript Module"
  | CommonJS => "CommonJS Module"
  };
