module M = Map.Make(String)

type t = {
  filename : string option;
  entry_point : string;
  browser_shim : browser_shim M.t;
}
and browser_shim =
  | Shim of string
  | Ignore


let empty = {
  filename = None;
  entry_point = "index.js";
  browser_shim = M.empty;
}

let normalize ~package_json_filename path =
  if String.get path 0 == '.'
  then FastpackUtil.FS.abs_path (FilePath.dirname package_json_filename) path
  else path


let of_json filename data =
  let data = Yojson.Safe.from_string (String.trim data) in
  let open Yojson.Safe.Util in
  try
    let main = member "main" data |> to_string_option in
    let module_ = member "module" data |> to_string_option in
    let browser, browser_shim =
      let field = member "browser" data in
      match field with
      | `Assoc items ->
        let f browser_shim (key, v) =
          let key = normalize ~package_json_filename:filename key in
          match v with
          | `String shim ->
            let shim = normalize ~package_json_filename:filename shim in
            M.add key (Shim shim) browser_shim
          | `Bool false -> M.add key Ignore browser_shim
          | _ -> browser_shim
        in
        let browser_shim = ListLabels.fold_left ~init:M.empty ~f items in
        None, browser_shim
      | `String browser ->
        Some browser, M.empty
      | _ ->
        (* TODO: differentiate between absent field and invalid type *)
        None, M.empty
    in
    let entry_point =
      match browser, module_, main with
      | Some browser, _, _ -> "./" ^ browser
      | None, Some module_, _ -> "./" ^ module_
      | None, None, Some main -> "./" ^ main
      | None, None, None -> "index.js"
    in
    (* TODO: shouldn't this be in Resolver? *)
    let entry_point =
      match M.get (normalize ~package_json_filename:filename entry_point) browser_shim with
      | Some (Shim shim) -> shim
      | Some Ignore -> "$fp$empty"
      | None -> entry_point
    in
    {
      filename = Some filename;
      entry_point;
      browser_shim
    }
  with Type_error _ ->
    {filename = None; entry_point = "index.js"; browser_shim = M.empty}
    (* TODO: provide better report here *)
    (* failwith ("Package.json cannot be parsed: " ^ filename) *)

let resolve_browser (package : t) (path : string) =
  match package with
  | { filename = None; _ } ->
      None
  | { filename = Some filename; browser_shim; _ } ->
    let path = normalize ~package_json_filename:filename path in
    M.get path browser_shim
