module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS

let debug = Logs.debug

type t = {
  resolve : Package.t -> string -> string -> (Module.location * string list) option Lwt.t;
  find_package : string -> Module.location -> Package.t Lwt.t;
}


(* let builtins = *)
(*   StringSet.empty *)
(*   |> StringSet.add "__fastpack_runtime__" *)
(*   |> StringSet.add "__empty_module__" *)

let empty =
  StringSet.empty
  |> StringSet.add "__empty_module__"
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

let is_empty module_request =
  StringSet.mem module_request empty

let make (cache : Cache.t) (preprocessor : Preprocessor.t) =

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
              Lwt.return_some (FS.abs_path path entry_point)
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

  let get_package_dependency {Package. filename; _} =
    match filename with
    | Some filename -> [filename]
    | None -> []
  in

  let rec resolve_package package path basedir =
    (* let () = Printf.printf "Package: %s\n" package in *)
    (* let () = Printf.printf "Path: %s\n" (CCOpt.get_or ~default:"None" path) in *)
    (* let () = Printf.printf "Basedir: %s\n" basedir in *)
    let node_modules_path = FilePath.concat basedir "node_modules" in
    let package_path = FilePath.concat node_modules_path package in
    if%lwt cache.file_exists node_modules_path then
      if%lwt cache.file_exists package_path then
        let package_json_path = FilePath.concat package_path "package.json" in
        let%lwt package =
          match%lwt cache.file_exists package_json_path with
          | false -> Lwt.return Package.empty
          | true ->
            let%lwt package, _ = cache.get_package package_json_path in
            Lwt.return package
        in
        let dep = get_package_dependency package in
        match path with
        | None ->
          let%lwt resolved = resolve_extensionless_path package_path in
          begin
            match resolved with
            | None ->
              Lwt.return_none
            | Some resolved ->
              Lwt.return_some (Module.resolved_file resolved, dep)
          end
        | Some path ->
          let path = FS.abs_path package_path path in
          match Package.resolve_browser package path with
          | Some resolved ->
            Lwt.return_some (resolved, dep)
          | None ->
            let%lwt resolved = resolve_extensionless_path path in
            match resolved with
            | None ->
              Lwt.return_none
            | Some resolved ->
              Lwt.return_some (Module.resolved_file resolved, dep)
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

  let resolve_file (package : Package.t) path basedir =
    match path with

    | "" ->
      Lwt.return_none

    | path ->
      match String.get path 0 with

      (* relative module path *)
      | '.' ->
        let path = FS.abs_path basedir path in
        begin
          match Package.resolve_browser package path with
          | Some resolved ->
            Lwt.return_some (resolved, get_package_dependency package)
          | None ->
            begin
              match%lwt resolve_extensionless_path path with
              | None -> Lwt.return_none
              | Some resolved ->
                Lwt.return_some (Module.resolved_file resolved,
                                 get_package_dependency package)
            end
        end

      (* absolute module path *)
      | '/' ->
        begin
          match%lwt resolve_extensionless_path path with
          | None -> Lwt.return_none
          | Some resolved ->
            Lwt.return_some (Module.resolved_file resolved, [])
        end

      (* scoped package *)
      | '@' ->
        begin
          match Package.resolve_browser package path with
          | Some resolved ->
            Lwt.return_some (resolved, get_package_dependency package)
          | None ->
            let package_name, path =
              match String.split_on_char '/' path with
              | [] ->
                (None, None)
              | _scope::[] ->
                (None, None)
              | scope::package::[] ->
                (Some (scope ^ "/" ^ package), None)
              | scope::package::rest ->
                (Some (scope ^ "/" ^ package), Some (String.concat "/" rest))
            in
            begin
              match package_name with
              | None ->
                Lwt.return_none
              | Some package_name ->
                resolve_package package_name path basedir
            end
        end

      (* package *)
      | _ ->
        if is_empty path
        then
          Lwt.return_some (Module.EmptyModule, [])
        else
          if path = "__fastpack_runtime__"
          then
            Lwt.return_some (Module.Runtime, [])
          else
            match Package.resolve_browser package path with
            | Some resolved ->
              Lwt.return_some (resolved, get_package_dependency package)
            | None ->
              let package_name, path =
                match String.split_on_char '/' path with
                | [] -> (None, None)
                | package::[] -> (Some package, None)
                | package::rest -> (Some package, Some (String.concat "/" rest))
              in
              match package_name with
              | None ->
                Lwt.return_none
              | Some package ->
                resolve_package package path basedir
  in

  let resolve (package : Package.t) request basedir =
    let resolve_preprocessors preprocessors =
      Lwt_list.fold_left_s
        (fun acc p ->
           match acc with
           | None ->
             Lwt.return_none
           | Some (preprocessors, all_deps) ->
             let p, opts =
               match String.split_on_char '?' p with
               | [p] -> p, ""
               | [p; opts] -> p, opts
               | _ ->
                 (* TODO: better error reporting *)
                 Error.ie "bad preprrocessor format"
             in
             match p with
             | "builtin" ->
               Lwt.return_some (("builtin", "") :: preprocessors, all_deps)
             | _ ->
               let%lwt resolved = resolve_file package p basedir in
               match resolved with
               | None ->
                 Lwt.return_none
               | Some (Module.Unknown, _)
               | Some (Module.EmptyModule, _)
               | Some (Module.Runtime, _)
               | Some (Module.File { filename = None; _ }, _) ->
                 (* TODO: better error handling *)
                 Error.ie "Something weird when resolving preprocessors"
               | Some (Module.File { filename = Some filename; _}, deps) ->
                 Lwt.return_some ((filename, opts) :: preprocessors,
                                  deps @ all_deps)
        )
        (Some ([], []))
        preprocessors
    in
    let rec resolve_parts ?(preprocess=true) parts =
      match parts with
      | [] ->
        Lwt.return_none

      | [ filename ] ->
        let%lwt resolved = resolve_file package filename basedir in
        let%lwt resolved =
          match preprocess, resolved with
          | true, Some (Module.File {
              filename = Some filename;
              preprocessors;
            }, deps) ->
            let more_preprocessors = preprocessor.get_processors filename in
            let%lwt more_preprocessors =
              resolve_preprocessors more_preprocessors
            in
            begin
            match more_preprocessors with
            | Some (more_preprocessors, more_deps) ->
              Lwt.return_some (Module.File {
                  filename = Some filename;
                  preprocessors = more_preprocessors @ preprocessors
                }, more_deps @ deps)
            | None ->
              Lwt.return_none
            end
          | _ ->
            Lwt.return resolved
        in
        Lwt.return resolved

      | "" :: "" :: rest
      | "" :: rest ->
        resolve_parts ~preprocess:false rest

      | _ ->
        let%lwt resolved_file, deps, rest =
          match List.rev parts with
          | [] ->
            Error.ie "Verified earlier, empty list cannot get here"
          | "" :: rest ->
            Lwt.return (
              Some (Module.File { filename = None; preprocessors = []}),
              [],
              rest
            )
          | filename :: rest ->
            let%lwt resolved_file = resolve_parts ~preprocess [filename] in
            begin
              match resolved_file with
              | Some (resolved_file, deps) ->
                Lwt.return (Some resolved_file, deps, rest)
              | None ->
                Lwt.return (None, [], rest)
            end
        in
        match resolved_file with
        | None ->
          Lwt.return_none
        | Some Module.Unknown ->
          Error.ie "Should not happend here"
        | Some Module.EmptyModule ->
          Lwt.return_some (Module.EmptyModule, [])
        | Some Module.Runtime ->
          Lwt.return_some (Module.Runtime, [])
        | Some (Module.File { preprocessors; filename }) ->
          let%lwt more_preprocessors = resolve_preprocessors rest in
          match more_preprocessors with
          | None ->
            Lwt.return_none
          | Some (more_preprocessors, more_deps) ->
            Lwt.return_some (
              Module.File {
                filename;
                preprocessors = more_preprocessors @ preprocessors;
              },
              deps @ more_deps
            )

    in
    let parts = String.split_on_char '!' request in
    resolve_parts parts
  in

  let package_json_cache = ref M.empty in
  let find_package root_dir module_location =
    let rec find_package_json dir =
      match M.get dir !package_json_cache with
      | Some package ->
        Lwt.return package
      | None ->
        let filename = FilePath.concat dir "package.json" in
        match%lwt cache.file_exists filename with
        | true ->
          let%lwt package, _ = cache.get_package filename in
          package_json_cache := M.add dir package !package_json_cache;
          Lwt.return package
        | false ->
          if dir = root_dir
          then
            Lwt.return (Package.empty)
          else begin
            let%lwt package = find_package_json (FilePath.dirname dir) in
            package_json_cache := M.add dir package !package_json_cache;
            Lwt.return package
          end
    in
    match module_location with
    | Module.File { filename = Some filename; _} ->
      find_package_json (FilePath.dirname filename)
    | Module.File _
    | Module.EmptyModule
    | Module.Runtime ->
      Lwt.return Package.empty
    | Module.Unknown ->
      Error.ie "Unknown module location in find_package"
  in

  { resolve; find_package }
