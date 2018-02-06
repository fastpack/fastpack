module StringSet = Set.Make(String)
module M = Map.Make(String)
let debug = Logs.debug

type t = {
  resolve : string -> string -> string option Lwt.t;
  find_package : string -> string -> Package.t Lwt.t;
}

let builtins =
  StringSet.empty
  |> StringSet.add "__fastpack_runtime__"
  |> StringSet.add "os"
  |> StringSet.add "module"
  |> StringSet.add "path"
  |> StringSet.add "util"
  |> StringSet.add "fs"
  |> StringSet.add "tty"
  |> StringSet.add "net"
  |> StringSet.add "events"
  |> StringSet.add "assert"
  |> StringSet.add "stream"
  |> StringSet.add "constants"
  |> StringSet.add "readable-stream"

let is_builtin module_request =
  StringSet.mem module_request builtins

let make (cache : Cache.t) =

  (** Try to resolve an absolute path *)
  let resolved_path = ref M.empty in
  let resolve_path path =
    match M.get path !resolved_path with
    | Some path ->
      Lwt.return path
    | None ->
      match%lwt cache.file_stat_opt path with
      | None -> Lwt.return_none
      | Some (stat, _) ->
        let%lwt resolved =
          match stat.st_kind with

          | Lwt_unix.S_DIR ->
            (* Check if directory contains package.json and read entry point from
               there if any *)
            let package_json_path = FilePath.concat path "package.json" in
            if%lwt cache.file_exists package_json_path then
              let%lwt { Package. entry_point; _ }, _ =
                cache.get_package package_json_path
              in
              Lwt.return_some (FastpackUtil.FS.abs_path path entry_point)
            else
              (** Check if directory contains index.js and return it if found *)
              let index_js_path = FilePath.concat path "index.js" in
              if%lwt cache.file_exists index_js_path then
                Lwt.return_some index_js_path
              else
                Lwt.return_none

          | Lwt_unix.S_REG ->
            Lwt.return_some path

          (* TODO: handle symlink *)
          | _ ->
            Lwt.return_none
        in
        resolved_path := M.add path resolved !resolved_path;
        Lwt.return resolved
  in

  (** Try to resolve an absolute path with different extensions *)
  let resolve_extensionless_path path =
    match%lwt resolve_path path with
    | Some _ as res -> Lwt.return res
    | None ->
      match%lwt resolve_path (path ^ ".js") with
      | Some _ as res -> Lwt.return res
      | None -> resolve_path (path ^ ".json")
  in


  let rec resolve_package package path basedir =
    let node_modules_path = FilePath.concat basedir "node_modules" in
    let package_path = FilePath.concat node_modules_path package in
    if%lwt cache.file_exists node_modules_path then
      if%lwt cache.file_exists package_path then
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
  in

  let resolve path from_filename =
    if is_builtin path
    then Lwt.return_some ("builtin:" ^ path)
    else
      let basedir = FilePath.dirname from_filename in
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
  in

  let find_package root_dir filename =
    let rec find_package_json dir =
      let filename = FilePath.concat dir "package.json" in
      match%lwt cache.file_exists filename with
      | true ->
        let%lwt package, _ = cache.get_package filename in
        Lwt.return package
      | false ->
        if dir = root_dir
        then Lwt.return (Package.empty)
        else find_package_json (FilePath.dirname dir)
    in
    let%lwt package = find_package_json (FilePath.dirname filename) in
    (* let%lwt () = Lwt_io.(write stdout (Package.to_string package ^ "\n")) in *)
    Lwt.return package
  in

  { resolve; find_package }
