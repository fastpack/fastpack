(* if no entry exists - read what is requested
 * can be: existance, stats, file, package, module
 * if entry exists and not trusted, validate all properties which are present
 * if entry exists and trusted, but some properties are not present
 * - read only those properties *)


module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS

module ModuleEntry = struct
  module Modified = struct
    type t = {
      es_module : bool;
      analyzed : bool;
      content : string;
      build_dependencies : string M.t;
      resolved_dependencies : (Dependency.t * string) list;
    }
  end

  type t = {
    id : string;
    modified : Modified.t option;
  }
end

type entry = {
  exists : bool;
  st_mtime : float;
  st_kind : Unix.file_kind;
  digest : string;
  content : string;
  package: Package.t option;
  module_: ModuleEntry.t option;
}

type validate = Exists | Stats | File | Package | Module

type t = {
  file_exists : string -> bool Lwt.t;
  file_stat : string -> (entry * bool) Lwt.t;
  file_stat_opt : string -> (entry * bool) option Lwt.t;
  get_file : string -> (entry * bool) Lwt.t;
  get_package : string -> (Package.t * bool) Lwt.t;
  get_module : string -> string -> (Module.t * bool) Lwt.t;
  modify_content : Module.t -> string -> unit Lwt.t;
  add_build_dependencies: Module.t -> string list -> unit Lwt.t;
  get_potentially_invalid : string -> string list;
  remove : string -> unit;
  dump : unit -> unit Lwt.t;
}

exception FileDoesNotExist of string
type strategy = Normal | Ignore

let create cache_filename =
  let no_file = {
    exists = false;
    st_mtime = 0.0;
    st_kind = Unix.S_REG;
    digest = "";
    content = "";
    package = None;
    module_ = None;
  }
  in

  let%lwt loaded =
    match cache_filename with
    | None ->
      Lwt.return M.empty
    | Some filename ->
      match%lwt Lwt_unix.file_exists filename with
      | true ->
        Lwt_io.with_file
          ~mode:Lwt_io.Input
          ~flags:Unix.[O_RDONLY]
          filename
          (fun ch -> (Lwt_io.read_value ch : entry M.t Lwt.t))
      | false ->
        Lwt.return M.empty
  in

  let trusted = ref StringSet.empty in
  let add_trusted filename =
    trusted := StringSet.add filename !trusted
  in

  let files = ref loaded in
  let update filename entry =
    files := M.add filename entry !files;
    add_trusted filename;
  in

  (* filename => set of files it changes *)
  let build_dependency_map = ref M.empty in
  let add_build_dependency filename changes =
    let set =
      match M.get filename !build_dependency_map with
      | None -> StringSet.empty
      | Some set -> StringSet.add changes set
    in
    build_dependency_map := M.add filename set !build_dependency_map;
  in
  let remove_dependency filename changes =
    let set =
      match M.get filename !build_dependency_map with
      | None -> StringSet.empty
      | Some set -> StringSet.remove changes set
    in
    build_dependency_map := M.add filename set !build_dependency_map;
  in

  let validate filename entry =
    let validate_file () =
      match%lwt FS.stat_option filename with
      | None ->
        update filename no_file;
        Lwt.return (no_file, false)
      | Some { st_mtime; st_kind; _} ->
        if st_mtime = entry.st_mtime
        then begin
          add_trusted filename;
          Lwt.return (entry, true)
        end
        else begin
          let%lwt content = Lwt_io.(with_file ~mode:Input filename read) in
          let digest = Digest.string content in
          if digest = entry.digest
          then begin
            let entry = { entry with st_mtime; st_kind } in
            update filename entry;
            Lwt.return (entry, true);
          end
          else begin
            let entry = { entry with st_mtime; st_kind; digest; content } in
            update filename entry;
            Lwt.return (entry, false);
          end
        end
    in
    match entry with
    | { module_ = Some m; package; _ } ->
      let%lwt entry, cached = validate_file () in
      if cached
      then Lwt.return (entry, true)
      else begin
        let package =
          match package with
          | None -> None
          | Some _ ->
            Some (Package.of_json filename entry.content)
        in
        let () =
          match m with
          | { modified = Some { build_dependencies; _ }; _ } ->
            build_dependencies
            |> M.bindings
            |> List.iter (fun (dep, _) -> remove_dependency dep filename)
          | _ -> ()
        in
        let module_ = { m with modified = None } in
        let entry = { entry with module_ = Some module_; package } in
        Lwt.return (entry, false)
      end
    | { package = Some _; _ } ->
      let%lwt entry, cached = validate_file () in
      if cached
      then Lwt.return (entry, true)
      else begin
        let package = Package.of_json filename entry.content in
        let entry = { entry with package = Some package } in
        Lwt.return (entry, false)
      end
    | { digest; st_mtime; _ } ->
      if digest <> ""
      then validate_file ()
      else if st_mtime <> 0.0
      then begin
        match%lwt FS.stat_option filename with
        | None ->
          update filename no_file;
          Lwt.return (no_file, false)
        | Some { st_mtime; st_kind; _} ->
          if st_mtime = entry.st_mtime
          then begin
            add_trusted filename;
            Lwt.return (entry, true)
          end
          else begin
            let entry = { entry with st_mtime; st_kind } in
            update filename entry;
            Lwt.return (entry, false)
          end
      end
      else begin
        let%lwt exists = Lwt_unix.file_exists filename in
        let entry = { no_file with exists } in
        update filename entry;
        Lwt.return (entry, false)
      end
  in

  let file_exists filename =
    match StringSet.mem filename !trusted, M.get filename !files with
    | true, Some { exists; _} ->
      Lwt.return exists
    | _, None ->
      let%lwt exists = Lwt_unix.file_exists filename in
      update filename { no_file with exists };
      Lwt.return exists
    | false, Some entry ->
      let%lwt { exists; _ }, _ = validate filename entry in
      Lwt.return exists
  in

  let file_stat path =
    let read_stats () =
      match%lwt FS.stat_option path with
      | None ->
        update path no_file;
        Lwt.fail (FileDoesNotExist path)
      | Some { st_mtime; st_kind; _} ->
        let entry = { no_file with exists = true; st_mtime; st_kind } in
        update path entry;
        Lwt.return (entry, false)
    in
    match StringSet.mem path !trusted, M.get path !files with
    | true, Some { exists = false; _ } ->
      Lwt.fail (FileDoesNotExist path)
    | true, Some entry ->
      if entry.st_mtime <> 0.0
      then Lwt.return (entry, true)
      else read_stats ()
    | _, None ->
      read_stats ()
    | false, Some entry ->
      let%lwt ({ exists; _ } as entry), cached = validate path entry in
      if exists
      then Lwt.return (entry, cached)
      else Lwt.fail (FileDoesNotExist path)
  in

  let file_stat_opt path =
    let read_stats () =
      match%lwt FS.stat_option path with
      | None ->
        update path no_file;
        Lwt.return_none
      | Some { st_mtime; st_kind; _} ->
        let entry = { no_file with exists = true; st_mtime; st_kind } in
        update path entry;
        Lwt.return_some (entry, false)
    in
    match StringSet.mem path !trusted, M.get path !files with
    | true, Some { exists = false; _ } ->
      Lwt.return_none
    | true, Some entry ->
      if entry.st_mtime <> 0.0
      then Lwt.return_some (entry, true)
      else read_stats ()
    | _, None ->
      read_stats ()
    | false, Some entry ->
      let%lwt ({ exists; _ } as entry), cached = validate path entry in
      if exists
      then Lwt.return_some (entry, cached)
      else Lwt.return_none
  in

  let get_file filename =
    let read_file () =
      let%lwt stats = file_stat_opt filename in
      match stats with
      | Some (entry, _) ->
        let%lwt content = Lwt_io.(with_file ~mode:Input filename read) in
        let digest = Digest.string content in
        let entry = { entry with content; digest } in
        update filename entry;
        Lwt.return (entry, false)
      | None ->
        Lwt.fail (FileDoesNotExist filename)
    in
    match StringSet.mem filename !trusted, M.get filename !files with
    | true, Some { exists = false; _ } ->
      Lwt.fail (FileDoesNotExist filename)
    | true, Some entry ->
      if entry.digest <> ""
      then Lwt.return (entry, true)
      else read_file ()
    | _, None ->
      read_file ()
    | false, Some entry ->
      let%lwt ({ exists; _ } as entry), cached = validate filename entry in
      if exists
      then Lwt.return (entry, cached)
      else Lwt.fail (FileDoesNotExist filename)
  in

  let get_package filename =
    match StringSet.mem filename !trusted, M.get filename !files with
    | true, Some { package = Some package; _ } ->
      Lwt.return (package, true)
    | _ ->
      let%lwt entry, cached = get_file filename in
      let package = Package.of_json filename entry.content in
      update filename { entry with package = Some package };
      Lwt.return (package, cached)
  in

  let get_module filename relname =
    let check_build_dependencies entry =
      match entry with
      | { module_ = Some { id; modified = Some { build_dependencies; _}}; _ } ->
        let%lwt build_dependencies_changed =
          build_dependencies
          |> M.bindings
          |> Lwt_list.exists_s
            (fun (filename, known_digest) ->
               let%lwt { digest; _ }, _ = get_file filename in
               Lwt.return (digest <> known_digest)
            )
        in
        if build_dependencies_changed
        then begin
          build_dependencies
          |> M.bindings
          |> List.iter (fun (dep, _) -> remove_dependency dep filename);
          Lwt.return ({ entry with module_ = Some {id; modified = None}}, false)
        end
        else
          Lwt.return (entry, true)
      | _ ->
        Lwt.return (entry, true)
    in

    let module_of_entry entry =
      let (
        id,
        resolved_dependencies,
        analyzed,
        es_module,
        content
      ) =
        match entry with
        | { module_ = None; _ } ->
          let id = Module.make_id relname in
          update filename { entry with module_ = Some { id; modified = None }};
          (id, [], false, false, entry.content)

        | { module_ = Some {id; modified = None }; _ } ->
          (id, [], false, false, entry.content)

        | { module_ = Some {id; modified = Some {
            content;
            analyzed;
            es_module;
            resolved_dependencies;
            _
          }}; _ } ->
          (id, resolved_dependencies, analyzed, es_module, content)
      in
      { Module.
        id;
        filename;
        resolved_dependencies;
        analyzed;
        es_module;
        workspace = Workspace.of_string content;
        scope = FastpackUtil.Scope.empty;
        exports = []
      }
    in
    let%lwt entry, cached = get_file filename in
    let%lwt entry, build_dependencies_cached = check_build_dependencies entry in
    Lwt.return (module_of_entry entry, build_dependencies_cached && cached)
  in

  let modify_content (m : Module.t) content =
    match String.sub m.filename 0 8 with
    | "builtin:" ->
      Lwt.return_unit
    | _ ->
      let%lwt entry, _ = get_file m.filename in
      let modified =
        match entry.module_ with
        | Some { modified = Some modified; _ } ->
          { modified with
            es_module = m.es_module;
            analyzed = m.analyzed;
            content;
            resolved_dependencies = m.resolved_dependencies
          }
        | Some { modified = None; _ } ->
          { build_dependencies = M.empty;
            es_module = m.es_module;
            analyzed = m.analyzed;
            content;
            resolved_dependencies = m.resolved_dependencies
          }
        | None ->
          Error.ie "Cannot modify module before creation"
      in
      update m.filename {
        entry with
        module_ = Some { id = m.id; modified = Some modified }
      };
      Lwt.return_unit
  in

  let add_build_dependencies m dependencies =
    let update_build_dependency_map () =
      dependencies
      |> List.iter (fun dep -> add_build_dependency m.Module.filename dep)
    in
    let add_build_dependencies existing_dependencies =
      Lwt_list.fold_left_s
        (fun acc filename ->
           let%lwt {digest; _ }, _ = get_file filename in
           add_build_dependency filename m.Module.filename;
           Lwt.return (M.add filename digest acc)
        )
        existing_dependencies
        dependencies
    in
    let%lwt entry, _ = get_file m.Module.filename in
    match entry with
    | { module_ = Some { id; modified = Some modified }; _ } ->
      let%lwt build_dependencies =
        add_build_dependencies modified.build_dependencies
      in
      update m.Module.filename {
        entry with module_ = Some {
          id;
          modified = Some {modified with build_dependencies}
        }};
      update_build_dependency_map ();
      Lwt.return_unit
    | { module_ = Some { id; modified = None }; _ } ->
      let%lwt build_dependencies =
        add_build_dependencies M.empty
      in
      update m.Module.filename {
        entry with module_ = Some {
          id;
          modified = Some {
              es_module = false;
              analyzed = false;
              content = entry.content;
              build_dependencies;
              resolved_dependencies = [];
            }
        }};
      update_build_dependency_map ();
      Lwt.return_unit
    | _ ->
      Error.ie ("Adding build_dependencies to a non-module: " ^ m.filename)
  in

  let get_potentially_invalid _filename = [] in
  let remove _filename = () in

  let dump () =
    match cache_filename with
    | None ->
      Lwt.return_unit
    | Some filename ->
      Lwt_io.with_file
        ~mode:Lwt_io.Output
        ~perm:0o640
        ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
        filename
        (fun ch -> Lwt_io.write_value ch ~flags:[] !files)
  in

  Lwt.return {
    file_exists;
    file_stat;
    file_stat_opt;
    get_file;
    get_package;
    get_module;
    modify_content;
    add_build_dependencies;
    get_potentially_invalid;
    remove;
    dump;
  }


