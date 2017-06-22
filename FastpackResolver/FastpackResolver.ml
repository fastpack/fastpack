let stat_option path =
  try%lwt
    let%lwt stat = Lwt_unix.stat path in
    Lwt.return_some stat
  with Unix.Unix_error _ ->
    Lwt.return_none

let package_entry_point package_json_path =
  let package_path = FilePath.dirname package_json_path in

  let find_option find list =
    try
      Some (List.find find list)
    with Not_found ->
      None
  in

  let%lwt main_value =
    let%lwt data = Lwt_io.with_file ~mode:Lwt_io.Input package_json_path Lwt_io.read in
    let package = Yojson.Basic.from_string data in
    match package with
    | `Assoc fields ->
      let main = find_option (fun (k, _) -> k = "main") fields in
      (match main with
       | Some (_, `String main_value) ->
         Lwt.return_some main_value
       | _ ->
         Lwt.return_none)
    | _ ->
      Lwt.return_none
  in

  match main_value with
  | Some main_value ->
    Lwt.return (FilePath.concat package_path main_value)
  | None ->
    Lwt.return (FilePath.concat package_path "index.js")

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
  | None -> resolve_path (path ^ ".js")
  | Some _ as res -> Lwt.return res

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
      let path = FilePath.make_absolute basedir path in
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
