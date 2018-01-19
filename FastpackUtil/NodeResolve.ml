module PackageJson = struct
  type t = {
    name : string;
    main : string option;
    module_ : string option;
    browser : string option;
  }

  let of_json data =
    let open Yojson.Safe.Util in
    try
      let name = member "name" data |> to_string in
      let main = member "main" data |> to_string_option in
      let module_ = member "module" data |> to_string_option in
      let browser = member "browser" data |> to_string_option in
      Result.Ok { name; main; module_; browser }
    with Type_error _ ->
      Result.Error "Error parsing package.json"

  let of_string data =
    let data = Yojson.Safe.from_string data in
    of_json data
end

let stat_option path =
  try%lwt
    let%lwt stat = Lwt_unix.stat path in
    Lwt.return_some stat
  with Unix.Unix_error _ ->
    Lwt.return_none

let package_entry_point package_json_path =
  let package_path = FilePath.dirname package_json_path in

  let%lwt module_value, main_value =
    let%lwt data = Lwt_io.with_file ~mode:Lwt_io.Input package_json_path Lwt_io.read in
    match PackageJson.of_string data with
    | Result.Ok package ->
      Lwt.return (package.PackageJson.module_, package.PackageJson.main)
    | Result.Error _ ->
      (** TODO: missing error handling here *)
      Lwt.return (None, None)
  in

  let add_suffix m =
      m ^ if Filename.check_suffix m ".js" then "" else ".js"
  in

  let entry_point =
    match module_value, main_value with
    | Some module_value, _ ->
      add_suffix module_value
    | None, Some main_value ->
      add_suffix main_value
    | None, None ->
      "index.js"
  in
  Lwt.return @@ FilePath.concat package_path entry_point

(** Try to resolve an absolute path *)
let resolve_path path =
  match%lwt stat_option path with
  | None -> Lwt.return_none
  | Some stat ->
    match stat.st_kind with

    | Lwt_unix.S_DIR ->
      (* Check if directory contains package.json and read entry point from
         there if any *)
      let package_json_path = FilePath.concat path "package.json" in
      if%lwt Lwt_unix.file_exists package_json_path then
        let%lwt entry_point = package_entry_point package_json_path in
        Lwt.return_some entry_point
      else
        (** Check if directory contains index.js and return it if found *)
        let index_js_path = FilePath.concat path "index.js" in
        if%lwt Lwt_unix.file_exists index_js_path then
          Lwt.return_some index_js_path
        else
          Lwt.return_none

    | Lwt_unix.S_REG ->
      Lwt.return_some path

    (* TODO: handle symlink *)
    | _ ->
      Lwt.return_none

(** Try to resolve an absolute path with different extensions *)
let resolve_extensionless_path path =
  match%lwt resolve_path path with
  | Some _ as res -> Lwt.return res
  | None ->
    match%lwt resolve_path (path ^ ".js") with
    | Some _ as res -> Lwt.return res
    | None -> resolve_path (path ^ ".json")


(** Try to resolve a package *)
let rec resolve_package package path basedir =
  let node_modules_path = FilePath.concat basedir "node_modules" in
  let package_path = FilePath.concat node_modules_path package in
  if%lwt Lwt_unix.file_exists node_modules_path then
    if%lwt Lwt_unix.file_exists package_path then
      match path with
      | None -> resolve_extensionless_path package_path
      | Some path -> resolve_extensionless_path (FilePath.concat package_path path)
    else
      let next_basedir = FilePath.dirname basedir in
      if next_basedir == basedir
      then Lwt.return_none
      else resolve_package package path next_basedir
  else
    let next_basedir = FilePath.dirname basedir in
    if next_basedir == basedir
    then Lwt.return_none
    else resolve_package package path next_basedir

let resolve path basedir =

  match path with

  | "" ->
    Lwt.return_none

  | path ->
    match String.get path 0 with

    (* relative module path *)
    | '.' ->
      let path =
        FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute basedir path
      in
      resolve_extensionless_path path

    (* absolute module path *)
    | '/' ->
      resolve_extensionless_path path

    (* scoped package *)
    | '@' ->
      let (package, path) = match String.split_on_char '/' path with
        | [] -> (None, None)
        | _scope::[] -> (None, None)
        | scope::package::[] -> (Some (scope ^ "/" ^ package), None)
        | scope::package::rest -> (Some (scope ^ "/" ^ package), Some (String.concat "/" rest))
      in
      (match package with
       | None -> Lwt.return_none
       | Some package -> resolve_package package path basedir)

    (* package *)
    | _ ->
      let (package, path) = match String.split_on_char '/' path with
        | [] -> (None, None)
        | package::[] -> (Some package, None)
        | package::rest -> (Some package, Some (String.concat "/" rest))
      in
      (match package with
       | None -> Lwt.return_none
       | Some package -> resolve_package package path basedir)
