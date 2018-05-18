module FS = FastpackUtil.FS
module M = Map.Make(String)

type request = PathRequest of string
             | PackageRequest of (string * string option)

type t = {
  resolve : basedir:string -> string -> (string option * string list * string list) Lwt.t;
}

let request_to_string req =
  match req with
  | PathRequest s -> "Path:" ^ s
  | PackageRequest (pkg, path) ->
    Printf.sprintf "Package: %s. Path: %s" pkg (CCOpt.get_or ~default:"None" path)

let make
  ~(project_dir : string)
  ~(extensions : string list)
  ~(cache : Cache.t) =

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

  let normalize_request ~(basedir : string) request =
    let open Run.Syntax in
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
        (* TODO: account for package.json *)
        withContext "...yes." (
          let package_json = FilePath.concat path "package.json" in
          match%lwt cache.file_stat_opt package_json with
          | Some ({st_kind = Lwt_unix.S_REG; _}, _) ->
            let%lwt {Package. entry_point; _ }, _ = cache.get_package package_json in
            resolve_file entry_point
          | _ ->
            resolve_file ~try_directory:false (path ^ "/index")
        )
      | _ ->
        withContext "...no." (error "Cannot resolve module")
    ))
  in

  let rec resolve_simple_request ~basedir request =
    let context =
      Printf.sprintf "Resolving '%s', base directory '%s'" request basedir
    in
    RunAsync.(withContext context (
      let open RunAsync.Syntax in
      match%bind RunAsync.liftOfRun (normalize_request ~basedir request) with
      | PathRequest request ->
        let%bind resolved = resolve_file request in
        let%lwt package = find_package project_dir resolved in
        let context =
          Printf.sprintf "Resolving '%s' through \"browser\"" resolved
        in
        withContext context (
          match Package.resolve_browser package resolved with
          | Some (Package.Ignore) -> return ("", [])
          | Some (Package.Shim shim) ->
            withContext
              "...found."
              (resolve_simple_request ~basedir:(FilePath.dirname resolved) shim)
          | None ->
            (* TODO: file mock *)
            return (resolved, [])
        )
      | PackageRequest _ ->
        error "Package request is not implemented"
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
      return (resolved ^ (if options <> "" then "?" ^ options else ""), dependencies)
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
        let%bind filename, configured_preprocessors, dependencies =
          match filename with
          | "" ->
            return (None, [], [])
          | _ ->
            let%bind resolved, dependencies =
              resolve_simple_request
                ~basedir
                filename
            in
            (* let preprocessors = preprocessor.get_processors resolved in *)
            let preprocessors =
              match preprocess with
              | true -> []
              (* | true -> ["style-loader"; "css-loader?modules=true"] *)
              | false -> []
            in
            return (Some resolved, preprocessors, dependencies)
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
        return (filename, List.rev preprocessors, dependencies @ preprocessor_dependencies)
    in
    let context =
      Printf.sprintf "Resolving '%s' with base directory '%s'" request basedir
    in
    match%lwt RunAsync.(withContext context (resolve' ())) with
    | Ok resolved -> Lwt.return resolved
    (* | Error error -> raise (NodeResolver.Error (Run.formatError error)) *)
    | Error error -> print_endline (Run.formatError error); Lwt.return (None, [], [])
  in

  { resolve }

let test request =
  let project_dir = "/Users/zindel/ocaml/style-components" in
  Unix.chdir project_dir;
  Lwt_main.run (
    let%lwt cache = Cache.(create Memory) in
    let {resolve} = make ~project_dir ~extensions:[".js"; ".json"] ~cache in
    resolve ~basedir:project_dir request
  )
