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
             [@@deriving ord]

module RequestMap = Map.Make(struct
  type t = request
  let compare = compare_request
end)

module RequestSet = Set.Make(struct
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
  ~(current_dir : string)
  ~(mock : (string * Mock.t) list)
  ~(node_modules_paths : string list)
  ~(extensions : string list)
  ~(preprocessor : Preprocessor.t)
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

  let mock_map =
    let build_mock_map () =
      let open Run.Syntax in
      Run.foldLeft
        ~f:(fun acc (k, v) ->
          let%bind normalized_key = normalize_request ~basedir:current_dir k in
          let%bind normalized_value =
            match v with
            | Mock.Empty -> return (InternalRequest "$fp$empty")
            | Mock.Mock v -> normalize_request ~basedir:current_dir v
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
        if dir = current_dir
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
             let rec gen_paths dir =
               let package_path =
                 FilePath.concat
                   (FilePath.concat dir node_modules_path)
                   package_name
               in
               if dir = current_dir
               then [package_path]
               else package_path :: (FilePath.dirname dir |> gen_paths)
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

  let withDependencies dependencies resolved =
    match%lwt resolved with
    | Ok (resolved, resolved_dependencies) ->
      Lwt.return_ok (resolved, dependencies @ resolved_dependencies)
    | Error err ->
      Lwt.return_error err
  in

  let withPackageDependency package resolved =
    match package.Package.filename with
    | None -> resolved
    | Some filename -> withDependencies [filename] resolved
  in

  let rec resolve_simple_request ?(seen=RequestSet.empty) ~basedir request =
    let open RunAsync.Syntax in
    let%bind normalized_request =
      RunAsync.liftOfRun (normalize_request ~basedir request)
    in
    match RequestSet.mem normalized_request seen with
    | true -> error "Resolver went into cycle"
    | false ->
      let seen = RequestSet.add normalized_request seen in
      let context =
        Printf.sprintf "Resolving '%s'." (request_to_string normalized_request)
      in
      RunAsync.(withContext context (
        match normalized_request with
        | InternalRequest request ->
          return (request, [])
        | PathRequest request ->
          let%bind resolved = resolve_file request in
          let%lwt package = find_package (FilePath.dirname resolved) in
          let context =
            Printf.sprintf "Resolving '%s' through \"browser\"" resolved
          in
          withPackageDependency package (
            withContext context (
              match Package.resolve_browser package resolved with
              | Some (Package.Ignore) -> return ("$fp$empty", [])
              | Some (Package.Shim shim) ->
                withContext
                  (Printf.sprintf "...found '%s'." shim)
                  (resolve_simple_request ~seen ~basedir:(FilePath.dirname resolved) shim)
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
          )
        | PackageRequest (package_name, path) ->
          withContext "Mocked package?" (
            match resolve_mock (PackageRequest (package_name, None)) with
            | Some (InternalRequest resolved) ->
              return (resolved, [])
            | Some ((PathRequest request) as r) ->
              let request =
                request
                ^ (match path with | None -> "" | Some path -> "/" ^ path)
              in
              withContext
                (Printf.sprintf "...yes '%s'." (request_to_string r))
                (resolve_simple_request ~seen ~basedir request)
            | Some ((PackageRequest (package_name, mocked_path)) as r) ->
              let request =
                package_name
                ^ (match mocked_path with | None -> "" | Some path -> "/" ^ path)
                ^ (match path with | None -> "" | Some path -> "/" ^ path)
              in
              withContext
                (Printf.sprintf "...yes '%s'." (request_to_string r))
                (resolve_simple_request ~seen ~basedir request)
            | None ->
              withContext "...no." (
                let%lwt package = find_package basedir in
                withPackageDependency package (
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
                        (resolve_simple_request ~seen ~basedir shim)
                    | None ->
                      withContext "...not found." (
                        let%bind package_path =
                          withContext
                            "Resolving package path"
                            (find_package_path_in_node_modules ~basedir package_name)
                        in
                        let request =
                          package_path
                          ^ (match path with | None -> "" | Some path -> "/" ^ path)
                        in
                        resolve_simple_request ~seen ~basedir request
                      )
                  )
                )
              )
          )
      ))
  in

  let resolve_preprocessor ~basedir preprocessor =
    let open RunAsync.Syntax in
    match preprocessor with
    | "builtin" ->
        return (("builtin", ""), [])
    | _ ->
      let context =
        Printf.sprintf "Resolving preprocessor '%s', base directory '%s'" preprocessor basedir
      in
      RunAsync.withContext context (
        let%bind request, options =
          match String.split_on_char '?' preprocessor with
          | [] -> error "Empty request"
          | request :: [] -> return (request, "")
          | request :: options -> return (request, String.concat "?" options)
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
        let resolve_preprocessors preprocessors =
          let rec resolve_preprocessors' = function
            | [] -> return ([], [])
            | request :: rest ->
              let%bind resolved, dependencies =
                resolve_preprocessor ~basedir request
              in
              let%bind all_resolved, dependencies =
                withDependencies dependencies (resolve_preprocessors' rest)
              in
              return (resolved :: all_resolved, dependencies)
          in
          let context =
            Printf.sprintf
              "Resolving preprocessors '%s'"
              (String.concat "!" preprocessors)
          in
          RunAsync.withContext context (resolve_preprocessors' preprocessors)
        in
        match filename with
        | "" ->
          let%bind (preprocessors, dependencies) = resolve_preprocessors preprocessors in
          return (None, dependencies, List.rev preprocessors)
        | _ ->
          let%bind resolved, dependencies =
            resolve_simple_request ~basedir filename
          in
          let configured_preprocessors =
            match preprocess with
            | true -> preprocessor.get_processors resolved
            | false -> []
          in
          let%bind preprocessors, dependencies =
            withDependencies
              dependencies
              (resolve_preprocessors (List.rev configured_preprocessors @ List.rev preprocessors))
          in
          return (Some resolved, dependencies, preprocessors)
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
