module FS = FastpackUtil.FS
module M = Map.Make(String)

module Mock = struct
  type t = Empty
         | Mock of string

  let to_string mock =
    match mock with
    | Empty -> ""
    | Mock mock -> mock

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

type t = {
  resolve : basedir:string -> string -> (Module.location * string  list) Lwt.t;
}

exception Error of string

type request = PathRequest of string
             | PackageRequest of (string * string option)
             | InternalRequest of string
             [@@deriving show {with_path = false},eq,ord]

module RequestMap = Map.Make(struct
  type t = request
  let compare = compare_request
end)


let request_to_string req =
  match req with
  | InternalRequest s -> s
  | PathRequest s -> s
  | PackageRequest (pkg, path) ->
    pkg ^ (match path with | None -> "" | Some path -> "/" ^ path)

let make
  ~(project_dir : string)
  ~(mock : (string * Mock.t) list)
  ~(node_modules_paths : string list)
  ~(extensions : string list)
  ~(cache : Cache.t) =

  let normalize_request ~(basedir : string) request =
    let open Run.Syntax in
    if Module.is_internal request
    then return (InternalRequest request)
    else
      match request with
      | "" -> error ("Empty request")
      | _ ->
        match String.get request 0 with
        | '.' -> return (PathRequest (FS.abs_path basedir request))
        | '/' -> return (PathRequest request)
        | '@' ->
          begin
            match String.split_on_char '/' request with
            | [] | _::[] ->
              error (Printf.sprintf "Bad scoped package name: %s" request)
            | scope :: package :: [] ->
              return (PackageRequest (scope ^ "/" ^ package, None))
            | scope::package::rest ->
              return (PackageRequest (scope ^ "/" ^ package, Some (String.concat "/" rest)))
          end
        | _ ->
          match String.split_on_char '/' request with
          | [] -> error "Bad package request"
          | package::[] -> return (PackageRequest (package, None))
          | package::rest -> return (PackageRequest (package, Some (String.concat "/" rest)))
  in

  (* let%lwt mock_map = *)
  (*   let open Run.Syntax in *)
  (*   let build_mock_map () = *)
  (*   in *)
  (*   match%bind build_mock_map () with *)
  (*   | Ok mock_map *)
  (* in *)

  let mock_map =
    let build_mock_map () =
      let open Run.Syntax in
      Run.foldLeft
        ~f:(fun acc (k, v) ->
          let%bind normalized_key = normalize_request ~basedir:project_dir k in
          let%bind normalized_value =
            match v with
            | Mock.Empty -> return (InternalRequest "$fp$empty")
            | Mock.Mock v -> normalize_request ~basedir:project_dir v
          in
          match normalized_key, normalized_value with
          | InternalRequest _, _ ->
            error ("Cannot mock internal package: " ^ k)
          | PackageRequest (_, Some _), _ ->
            error ("Cannot mock path inside the package: " ^ k)
          | PathRequest _, PackageRequest _ ->
            error ("File could be only mocked with another file, not package: "
                   ^ k ^ ":" ^ Mock.to_string v)
          | _ ->
            return (RequestMap.add normalized_key normalized_value acc)
        )
        ~init:RequestMap.empty
        mock

    in
    match build_mock_map () with
    | Ok mock_map -> mock_map
    | Error error -> raise (Error (Run.formatError error))
  in

  let resolve_mock normalized_request =
    RequestMap.get normalized_request mock_map
  in

  let package_json_cache = ref M.empty in
  let rec find_package dir =
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
        if dir = project_dir
        then
          Lwt.return (Package.empty)
        else begin
          let%lwt package = find_package (FilePath.dirname dir) in
          package_json_cache := M.add dir package !package_json_cache;
          Lwt.return package
        end
  in

  let rec resolve_file ?(try_directory=true) path =
    let open RunAsync.Syntax in
    let rec resolve' extensions =
      match extensions with
      | [] ->
        if try_directory
        then resolve_directory path
        else error "Cannot resolve module"
      | ext :: rest ->
        let filename = path ^ ext in
        let context = Printf.sprintf "File exists? '%s'" filename in
        RunAsync.(withContext context (
          match%lwt cache.file_stat_opt filename with
          | Some ({ st_kind = Lwt_unix.S_REG; _ }, _) ->
            return filename
          | _ ->
            withContext "...no." (resolve' rest)
        ))
    in
    resolve' ("" :: extensions)

  and resolve_directory path =
    let context =
      Printf.sprintf "Is directory? '%s'" path
    in
    RunAsync.(withContext context (
      match%lwt cache.file_stat_opt path with
      | Some ({st_kind = Lwt_unix.S_DIR; _}, _) ->
        withContext "...yes." (
          let package_json = FilePath.concat path "package.json" in
          match%lwt cache.file_stat_opt package_json with
          | Some ({st_kind = Lwt_unix.S_REG; _}, _) ->
            let%lwt {Package. entry_point; _ }, _ = cache.get_package package_json in
            resolve_file (FS.abs_path path entry_point)
          | _ ->
            resolve_file ~try_directory:false (path ^ "/index")
        )
      | _ ->
        withContext "...no." (error "Cannot resolve module")
    ))
  in

  let find_package_path_in_node_modules ~basedir package_name =
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
    let open RunAsync.Syntax in
    let rec exists' paths =
      match paths with
      | [] -> error "Cannot find package path"
      | path :: rest ->
        let context = Printf.sprintf "Path exists? '%s'" path in
        RunAsync.(withContext context (
          match%lwt cache.file_stat_opt path with
          | Some ({ st_kind = Lwt_unix.S_DIR; _ }, _) ->
            return path
          | _ ->
            withContext "...no." (exists' rest)
        ))
    in
    exists' try_paths
  in

  let rec resolve_simple_request ~basedir request =
    (* TODO: track seen requests *)
    let open RunAsync.Syntax in
    let context =
      Printf.sprintf "Resolving '%s'. Base directory: '%s'" request basedir
    in
    RunAsync.(withContext context (
      match%bind RunAsync.liftOfRun (normalize_request ~basedir request) with
      | InternalRequest request ->
        return (request, [])
      | PathRequest request ->
        let%bind resolved = resolve_file request in
        let%lwt package = find_package (FilePath.dirname resolved) in
        let context =
          Printf.sprintf "Resolving '%s' through \"browser\"" resolved
        in
        withContext context (
          match Package.resolve_browser package resolved with
          | Some (Package.Ignore) -> return ("$fp$empty", [])
          | Some (Package.Shim shim) ->
            withContext
              (Printf.sprintf "...found '%s'." shim)
              (resolve_simple_request ~basedir:(FilePath.dirname resolved) shim)
          | None ->
            withContext "...not found." (
              withContext "Mocked file?" (
                match resolve_mock (PathRequest resolved) with
                | Some (PathRequest path) ->
                  withContext (Printf.sprintf "...yes. '%s'" path) (
                    match%lwt cache.file_stat_opt path with
                    | Some ({ st_kind = Lwt_unix.S_REG; _ }, _) ->
                      return (path, [])
                    | _ ->
                      error ("File not found: " ^ path)
                  )
                | Some (InternalRequest request) ->
                  return (request, [])
                | Some _ ->
                  error "Incorrect mock configuration"
                | None ->
                  return (resolved, [])
              )
            )
        )
      | PackageRequest (package_name, path) ->
        withContext "Mocked package?" (
          match resolve_mock (PackageRequest (package_name, None)) with
          | Some (InternalRequest resolved) ->
            return (resolved, [])
          | Some ((PathRequest request) as r) ->
            withContext
              (Printf.sprintf "...yes '%s'." (request_to_string r))
              (resolve_simple_request ~basedir request)
          | Some ((PackageRequest (package_name, mocked_path)) as r) ->
            let request =
              package_name
              ^ (match mocked_path with | None -> "" | Some path -> "/" ^ path)
              ^ (match path with | None -> "" | Some path -> "/" ^ path)
            in
            withContext
              (Printf.sprintf "...yes '%s'." (request_to_string r))
              (resolve_simple_request ~basedir request)
          | None ->
            withContext "...no." (
              let%lwt package = find_package basedir in
              let context =
                Printf.sprintf "Resolving '%s' through \"browser\"" package_name
              in
              withContext context (
                match Package.resolve_browser package package_name with
                | Some (Package.Ignore) -> return ("$fp$empty", [])
                | Some (Package.Shim shim) ->
                  (* TODO: what if path is not None?*)
                  withContext
                    (Printf.sprintf "...found '%s'." shim)
                    (resolve_simple_request ~basedir shim)
                | None ->
                  withContext "...not found." (
                    let%bind package_path =
                      withContext
                        "Resolving package path"
                        (find_package_path_in_node_modules ~basedir package_name)
                    in
                    match path with
                    | None ->
                      let%bind resolved = resolve_directory package_path in
                      return (resolved, [])
                    | Some path ->
                      resolve_simple_request ~basedir (package_path ^ "/" ^ path)
                  )
              )
            )
        )
    ))
  in

  let resolve_preprocessor ~basedir preprocessor =
    let context =
      Printf.sprintf "Resolving preprocessor '%s', base directory '%s'" preprocessor basedir
    in
    RunAsync.withContext context (
      let open RunAsync.Syntax in
      let%bind request, options =
        match String.split_on_char '?' preprocessor with
        | request :: [] -> return (request, "")
        | request :: options :: [] -> return (request, options)
        | _ -> error (Printf.sprintf "Bad preprocessor format: '%s'" preprocessor)
      in
      let%bind resolved, dependencies =
        resolve_simple_request ~basedir request
      in
      return ((resolved, options), dependencies)
    )
  in

  let resolve ~basedir request =
    let resolve' () =
      let open RunAsync.Syntax in
      let parts, preprocess =
        let rec to_parts ?(preprocess=true) = function
          | [] ->
            ([], false)
          | "-" :: rest | "" :: "" :: rest | "" :: rest ->
            to_parts ~preprocess:false rest
          | parts ->
            (parts, preprocess)
        in
        to_parts (String.split_on_char '!' request)
      in
      match List.rev parts with
      | [] -> error "Empty request"
      | filename :: preprocessors ->
        let%bind filename, dependencies, configured_preprocessors =
          match filename with
          | "" ->
            return (None, [], [])
          | _ ->
            let%bind resolved, dependencies =
              resolve_simple_request
                ~basedir
                filename
            in
            (* TODO: configured preprocessors *)
            (* let preprocessors = preprocessor.get_processors resolved in *)
            let preprocessors =
              match preprocess with
              | true -> []
              (* | true -> ["style-loader"; "css-loader?modules=true"] *)
              | false -> []
            in
            return (Some resolved, dependencies, preprocessors)
        in
        let%bind preprocessors, preprocessor_dependencies =
          RunAsync.foldLeft
            ~init:([], [])
            ~f:(fun (all_resolved, all_dependencies) request ->
              let%bind resolved, dependencies =
                resolve_preprocessor ~basedir request
              in
              return (resolved :: all_resolved, dependencies @ all_dependencies)
            )
            (configured_preprocessors @ preprocessors)
        in
        return (filename, dependencies @ preprocessor_dependencies, List.rev preprocessors)
    in
    let context =
      Printf.sprintf "Resolving '%s'. Base directory: '%s'" request basedir
    in
    match%lwt RunAsync.(withContext context (resolve' ())) with
    | Ok (filename, dependencies, preprocessors) ->
      let location = Module.resolved_file2 ~preprocessors filename in
      Lwt.return (location, dependencies)
    | Error error -> Lwt.fail (Error (Run.formatError error))
  in

  { resolve }
