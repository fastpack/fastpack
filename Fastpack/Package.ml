module StringMap = Map.Make(String)

type t = {
  filename : string option;
  entry_point : string;
  browser_shim : browser_shim StringMap.t;
}

and browser_shim =
  | Shim of string
  | Ignore

let empty = {
  filename = None;
  entry_point = "index.js";
  browser_shim = StringMap.empty;
}

let normalize ~package_json_filename path =
  if String.get path 0 == '.'
  then FastpackUtil.FS.abs_path (FilePath.dirname package_json_filename) path
  else path

let of_json filename data =
  let add_suffix m =
      m ^ if Filename.check_suffix m ".js" then "" else ".js"
  in
  let data = Yojson.Safe.from_string (String.trim data) in
  let open Yojson.Safe.Util in
  try
    (* let name = member "name" data |> to_string in *)
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
            StringMap.add key (Shim shim) browser_shim
          | `Bool false -> StringMap.add key Ignore browser_shim
          | _ -> browser_shim
        in
        let browser_shim = ListLabels.fold_left ~init:StringMap.empty ~f items in
        None, browser_shim
      | `String browser ->
        Some browser, StringMap.empty
      | _ ->
        (* TODO: differentiate between absent field and invalid type *)
        None, StringMap.empty
    in
    let entry_point =
      match browser, module_, main with
      | Some browser, _, _ -> browser
      | None, Some module_, _ -> module_
      | None, None, Some main -> main
      | None, None, None -> "index.js"
    in
    {filename = Some filename; entry_point = add_suffix entry_point; browser_shim}
  with Type_error _ ->
    (* TODO: provide better report here *)
    {filename = None; entry_point = "index.js"; browser_shim = StringMap.empty}
    (* failwith ("Package.json cannot be parsed: " ^ filename) *)

let to_string { filename; _} =
  match filename with
  | None -> "(empty)"
  | Some filename -> filename

let resolve_browser (package : t) (req : string) =
  match package with
  | { filename = None; _ } -> None
  | { filename = Some filename; browser_shim; _ } ->
    let path = normalize ~package_json_filename:filename req in
    print_endline ("REQ: " ^ req);
    print_endline ("PATH: " ^ path);
    print_endline ("PACKAGE.JSON: " ^ filename);
    StringMap.iter (fun k _v -> print_endline k) browser_shim;
    match StringMap.get path browser_shim with
    | None -> 
      print_endline ("PATH: " ^ path ^ " " ^ "none");
      None
    | Some (Shim newPath) ->
      print_endline ("PATH: " ^ path ^ " " ^ "shim");
      Some (Module.File { filename = Some newPath; preprocessors = [] })
    | Some Ignore ->
      print_endline ("PATH: " ^ path ^ " " ^ "ignore");
      Some Module.EmptyModule
