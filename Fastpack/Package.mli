(**
 * Read package.json files
 * Currently considered fields are: "browser", "module", and "main".
 * *)


type t = {
  filename : string option;
  entry_point : string;
  browser_shim : browser_shim Map.Make(String).t;
}
and browser_shim =
  | Shim of string
  | Ignore

(** Construct empty package.json representation. *)
val empty : t

(**
 * Construct package.json based on exisiting file.
 * `of_json filename data` where `data` is the raw content of the file
 * *)
val of_json : string -> string -> t

(**
 * Resolve dependncy request through "browser" field.
 *)
val resolve_browser : t -> string -> browser_shim option
