
type t = Application | ESM | CommonJS

let to_string (t : t) =
  match t with
  | Application -> "Application"
  | ESM -> "EcmaScript Module"
  | CommonJS -> "CommonJS Module"
