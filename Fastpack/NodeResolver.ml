module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS

let debug = Logs.debug

type t = {
  resolve : Package.t -> string -> string -> (Module.location * string list) Lwt.t;
  find_package : string -> string -> Package.t Lwt.t;
}

exception Error of string

let node_libs =
  StringSet.empty
  |> StringSet.add "__empty_module__"
  |> StringSet.add "assert"
  |> StringSet.add "buffer"
  |> StringSet.add "child_process"
  |> StringSet.add "cluster"
  |> StringSet.add "console"
  |> StringSet.add "constants"
  |> StringSet.add "crypto"
  |> StringSet.add "dgram"
  |> StringSet.add "dns"
  |> StringSet.add "domain"
  |> StringSet.add "events"
  |> StringSet.add "fs"
  |> StringSet.add "http"
  |> StringSet.add "https"
  |> StringSet.add "module"
  |> StringSet.add "net"
  |> StringSet.add "os"
  |> StringSet.add "path"
  |> StringSet.add "process"
  |> StringSet.add "punycode"
  |> StringSet.add "querystring"
  |> StringSet.add "readable-stream"
  |> StringSet.add "readline"
  |> StringSet.add "repl"
  |> StringSet.add "stream"
  |> StringSet.add "string_decoder"
  |> StringSet.add "sys"
  |> StringSet.add "timers"
  |> StringSet.add "tls"
  |> StringSet.add "url"
  |> StringSet.add "util"
  |> StringSet.add "vm"
  |> StringSet.add "zlib"

module Mock = struct
  type t = Empty
         | Mock of string

  let parse s =
    match String.(s |> trim |> split_on_char ':') with
    | [] | [""] ->
      Result.Error (`Msg "Empty config")
    | request :: [] | request :: "" :: [] ->
      Result.Ok (false, (request, Empty))
    | request :: rest ->
      let mock = String.concat ":" rest in
      Result.Ok (false, (request, Mock mock))

  let print ppf (_, mock) =
    let value =
      match mock with
      | request, Empty -> request
      | request, Mock mock -> request ^ ":" ^ mock
    in
    Format.fprintf ppf "%s" value

end



let make
    ~(project_dir : string)
    ~(mock : (string * Mock.t) list)
    ~(node_modules_paths : string list)
    ~(cache : Cache.t)
    ~(preprocessor : Preprocessor.t) =

  (* TODO: make extensions be command-line parameter *)
  let _try_extensions = [".js"; ".json"; ""] in

  let normalize path =
    if String.get path 0 == '.'
    then FastpackUtil.FS.abs_path project_dir path
    else path
  in

  (* TODO: verify mock cycles *)
  let mock_package_map, mock_file_map =
    List.fold_left
      (fun (package_map, file_map) (key, substitute) ->
        let substitute =
          match substitute with
          | Mock.Empty -> "$fp$empty"
          | Mock.Mock substitute -> substitute
        in
        if String.get key 0 = '.' || String.get key 0 = '/'
        then
          let key = normalize key in
          let substitute = normalize substitute in
          (package_map, M.add key substitute file_map)
        else
          (M.add key substitute package_map, file_map)
      )
      (M.empty, M.empty)
      mock
  in

  let resolve_mock_package package_name =
    M.get package_name mock_package_map
  in

  let resolve_mock_file filename =
    M.get filename mock_file_map
  in

  (** Try to resolve an absolute path *)
  let resolved_path = ref M.empty in
  let rec resolve_path path =
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
              let entry_point = FS.abs_path path entry_point in
              begin
                match%lwt cache.file_stat_opt entry_point with
                | None ->
                  resolve_extensionless_path entry_point
                | Some ({ st_kind = Lwt_unix.S_DIR; _ }, _) ->
                  resolve_extensionless_path (FilePath.concat entry_point "index")
                | Some _ ->
                  Lwt.return_some entry_point
              end
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
        (* resolved_path := M.add path resolved !resolved_path; *)
        Lwt.return resolved

  (** Try to resolve an absolute path with different extensions *)
  and resolve_extensionless_path path =
    match%lwt resolve_path (path ^ ".js") with
    | Some _ as res -> Lwt.return res
    | None ->
      match%lwt resolve_path (path ^ ".jsx") with
      | Some _ as res -> Lwt.return res
      | None ->
        match%lwt resolve_path path with
        | Some _ as res -> Lwt.return res
        | None -> resolve_path (path ^ ".json")
  in

  let get_package_dependency {Package. filename; _} =
    match filename with
    | Some filename -> [filename]
    | None -> []
  in

  let rec resolve_package (package : Package.t) package_name path basedir =
    match resolve_mock_package package_name with
    | Some request ->
      resolve_file package request basedir
    | None ->
        match Package.resolve_browser package package_name with
      | Some (Package.Shim shim) ->
        resolve_file package shim basedir
      | Some (Package.Ignore) ->
        (* TODO: path_in_package should be None *)
        Lwt.return (Module.EmptyModule, [])
      | None ->
        let try_paths =
          node_modules_paths
          |> List.map
            (fun node_modules_path ->
               match String.get node_modules_path 0 with
               | '/' -> [FilePath.concat node_modules_path package_name]
               | _ ->
                 let rec gen_paths current_dir =
                   let package_path =
                     FilePath.concat
                       (FilePath.concat current_dir node_modules_path)
                       package_name
                   in
                   if current_dir = project_dir
                   then [package_path]
                   else package_path :: (FilePath.dirname current_dir |> gen_paths)
                 in
                 gen_paths basedir
            )
          |> List.concat
        in
        let%lwt resolved =
          Lwt_list.fold_left_s
            (fun resolved package_path ->
               match resolved with
               | Some _ -> Lwt.return resolved
               | None ->
                 if%lwt cache.file_exists package_path then
                  let package_json_path = FilePath.concat package_path "package.json" in
                  let%lwt package =
                    match%lwt cache.file_exists package_json_path with
                    | false ->
                      Lwt.return Package.empty
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
                        match resolve_mock_file resolved with
                        | Some mocked ->
                          let%lwt resolved = resolve_file package mocked basedir in
                          Lwt.return_some resolved
                        | None ->
                          Lwt.return_some (Module.resolved_file resolved, dep)
                    end
                  | Some path ->
                    let path = FS.abs_path package_path path in
                    match Package.resolve_browser package path with
                    | Some (Package.Shim shim) ->
                      let%lwt resolved = resolve_extensionless_path shim in
                      begin
                        match resolved with
                        | None ->
                          Lwt.return_none
                        | Some resolved ->
                          match resolve_mock_file resolved with
                          | Some mocked ->
                            let%lwt resolved = resolve_file package mocked basedir in
                            Lwt.return_some resolved
                          | None ->
                            Lwt.return_some (Module.resolved_file resolved, dep)
                      end
                    | Some (Package.Ignore) ->
                      (* TODO: path_in_package should be None *)
                      Lwt.return_some (Module.EmptyModule, dep)
                    | None ->
                      let%lwt resolved = resolve_extensionless_path path in
                      match resolved with
                      | None ->
                        Lwt.return_none
                      | Some resolved ->
                        match resolve_mock_file resolved with
                        | Some mocked ->
                          let%lwt resolved = resolve_file package mocked basedir in
                          Lwt.return_some resolved
                        | None ->
                          Lwt.return_some (Module.resolved_file resolved, dep)
                 else
                   Lwt.return_none
            )
            None
            try_paths
        in
        match resolved with
        | Some resolved -> Lwt.return resolved
        | None -> Lwt.fail (Error package_name)


  and resolve_file (package : Package.t) path basedir =
    match path with

    | "" ->
      Lwt.fail (Error "Empty path")

    | path ->
      match String.get path 0 with

      (* relative module path *)
      | '.' ->
        let path = FS.abs_path basedir path in
        begin
          match%lwt resolve_extensionless_path path with
          | None ->
            Lwt.fail (Error path)
          | Some resolved ->
            match resolve_mock_file resolved with
            | Some mocked ->
              resolve_file package mocked basedir
            | None ->
              match Package.resolve_browser package resolved with
              | None ->
                Lwt.return (Module.resolved_file resolved,
                            get_package_dependency package)
              | Some Package.Ignore ->
                Lwt.return (Module.EmptyModule, get_package_dependency package)
              | Some (Package.Shim browser_path) ->
                resolve_file package browser_path basedir
        end

      (* absolute module path *)
      (* TODO: decide, should we be considering "browser" here? *)
      | '/' ->
        begin
          match%lwt resolve_extensionless_path path with
          | None ->
            Lwt.fail (Error path)
          | Some resolved ->
            match resolve_mock_file resolved with
            | Some mocked ->
              resolve_file package mocked basedir
            | None ->
              Lwt.return (Module.resolved_file resolved, [])
        end

      (* scoped package *)
      | '@' ->
        let%lwt package_name, path_in_package =
        match String.split_on_char '/' path with
        | [] | _::[] ->
          Lwt.fail (Error path)
        | scope::package::[] ->
          Lwt.return (scope ^ "/" ^ package, None)
        | scope::package::rest ->
          Lwt.return (scope ^ "/" ^ package, Some (String.concat "/" rest))
        in
        resolve_package package package_name path_in_package basedir

      (* package *)
      | _ ->
        match path with
        | "$fp$empty" -> Lwt.return (Module.EmptyModule, [])
        | "$fp$runtime" -> Lwt.return (Module.Runtime, [])
        | _ ->
          let%lwt package_name, path_in_package =
            match String.split_on_char '/' path with
            | [] -> Lwt.fail (Error path)
            | package::[] -> Lwt.return (package, None)
            | package::rest -> Lwt.return (package, Some (String.concat "/" rest))
          in
          resolve_package package package_name path_in_package basedir
  in

  let resolve (package : Package.t) request basedir =

    let resolve_preprocessors preprocessors =
      Lwt_list.fold_left_s
        (fun (preprocessors, all_deps) p ->
           let%lwt p, opts =
             match String.split_on_char '?' p with
             | [p] ->
               Lwt.return (p, "")
             | [p; opts] ->
               Lwt.return (p, opts)
             | _ ->
               (* TODO: better error reporting *)
               Lwt.fail (Error "bad preprrocessor format")
           in
           match p with
           | "builtin" ->
             Lwt.return (("builtin", "") :: preprocessors, all_deps)
           | _ ->
             let%lwt resolved = resolve_file package p basedir in
             match resolved with
             | Module.Main _, _
             | Module.EmptyModule, _
             | Module.Runtime, _
             | Module.File { filename = None; _ }, _ ->
               (* TODO: better error handling *)
               Lwt.fail (Error "Something weird when resolving preprocessors")
             | Module.File { filename = Some filename; _}, deps ->
               Lwt.return ((filename, opts) :: preprocessors,
                           deps @ all_deps)
        )
        ([], [])
        preprocessors
    in

    let rec resolve_parts ?(preprocess=true) parts =
      match parts with
      | [] ->
        Lwt.fail (Error "Empty path")

      | [ filename ] ->
        let%lwt resolved = resolve_file package filename basedir in
        let%lwt resolved =
          match preprocess, resolved with
          | true, (Module.File {
              filename = Some filename;
              preprocessors;
            }, deps) ->
            let%lwt more_preprocessors, more_deps =
              filename
              |> preprocessor.get_processors
              |> resolve_preprocessors
            in
            Lwt.return (Module.File {
                filename = Some filename;
                preprocessors = more_preprocessors @ preprocessors
              }, more_deps @ deps)
          | _ ->
            Lwt.return resolved
        in
        Lwt.return resolved

      | "-" :: rest
      | "" :: "" :: rest
      | "" :: rest ->
        resolve_parts ~preprocess:false rest

      | _ ->
        let%lwt resolved_file, deps, rest =
          match List.rev parts with
          | [] ->
            Lwt.fail (Error "Verified earlier, empty list cannot get here")
          | "" :: rest ->
            Lwt.return (
              Module.File { filename = None; preprocessors = []},
              [],
              rest
            )
          | filename :: rest ->
            let%lwt resolved_file, deps =
              resolve_parts ~preprocess [filename]
            in
            Lwt.return (resolved_file, deps, rest)
        in
        match resolved_file with
        | Module.Main _ ->
          Lwt.fail (Error "fp$main should never be required")
        | Module.EmptyModule ->
          Lwt.return (Module.EmptyModule, [])
        | Module.Runtime ->
          Lwt.return (Module.Runtime, [])
        | Module.File { preprocessors; filename } ->
          let%lwt more_preprocessors, more_deps = resolve_preprocessors rest in
          Lwt.return (
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
  let find_package root_dir filename =
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
    find_package_json (FilePath.dirname filename)
  in

  { resolve; find_package }
