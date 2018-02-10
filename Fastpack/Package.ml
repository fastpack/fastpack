
type t = {
  filename : string option;
  entry_point : string;
}

let empty = {
  filename = None;
  entry_point = "index.js";
}

let of_json filename data =
  let add_suffix m =
      m ^ if Filename.check_suffix m ".js" then "" else ".js"
  in
  let data = Yojson.Safe.from_string data in
  let open Yojson.Safe.Util in
  try
    (* let name = member "name" data |> to_string in *)
    let main = member "main" data |> to_string_option in
    let module_ = member "module" data |> to_string_option in
    let entry_point =
      match module_, main with
      | Some module_, _ -> module_
      | None, Some main -> main
      | None, None -> "index.js"
    in
    {filename = Some filename; entry_point = add_suffix entry_point}
  with Type_error _ ->
    {filename = None; entry_point = "index.js"}
    (* TODO: provide better report here *)
    (* failwith ("Package.json cannot be parsed: " ^ filename) *)

let to_string { filename; _} =
  match filename with
  | None -> "(empty)"
  | Some filename -> filename

let resolve_browser (_package : t) (_path : string) =
  (* The second argument could be either absolute path to file
   * starting with '/' and guaranteed to be inside the package
   * OR the outer module request starting with the letter
   * (like 'react' or 'zlib').
   * The expected output is string option. Make sure that string holds
   * the absolute path.
   * The only exception for the rule above is '"module": false' case.
   * In this case return (Some "builtin:__empty_module__")
   * Do not check files for existance, only base on the package.json config.
   * If "browser" is not present or required path does not belong there -
   * return None.
   * *)
  None
