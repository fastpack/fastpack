module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS
module Scope = FastpackUtil.Scope


let debug = Logs.debug

module ModuleEntry = struct
  type t = {
    id : string;
    state : Module.state;
    module_type : Module.module_type;
    files : (string * string) list;
    content : string;
    build_dependencies : string M.t;
    resolved_dependencies : (Dependency.t * Module.location) list;
    scope: Scope.t;
    exports: Scope.exports;
  }
end

type entry = {
  exists : bool;
  st_mtime : float;
  st_kind : Unix.file_kind;
  digest : string;
  content : string;
  package: Package.t option;
}

type cache = {
  files : entry M.t;
  modules : ModuleEntry.t M.t;
}

type t = {
  file_exists : string -> bool Lwt.t;
  file_stat : string -> (entry * bool) Lwt.t;
  file_stat_opt : string -> (entry * bool) option Lwt.t;
  get_file : string -> (entry * bool) Lwt.t;
  get_file_no_raise : string -> (entry * bool) Lwt.t;
  get_package : string -> (Package.t * bool) Lwt.t;
  get_module : Module.location -> Module.t option Lwt.t;
  modify_content : Module.t -> string -> unit;
  add_build_dependencies: Module.t -> string list -> unit Lwt.t;
  get_potentially_invalid : string -> string list;
  setup_build_dependencies : StringSet.t -> unit;
  remove : string -> unit;
  dump : unit -> unit Lwt.t;
  starts_empty : bool;
}

exception FileDoesNotExist of string

type strategy = | Use
                | Disable

type init = | Persistent of string
            | Memory



let empty = {
  files = M.empty;
  modules = M.empty;
}

let create (init : init) =
  let no_file = {
    exists = false;
    st_mtime = 0.0;
    st_kind = Unix.S_REG;
    digest = "";
    content = "";
    package = None;
  }
  in
  
  let%lwt loaded =
    match init with
    | Memory ->
      Lwt.return empty
    | Persistent filename ->
      match%lwt Lwt_unix.file_exists filename with
      | true ->
        let%lwt loaded =
          Lwt_io.with_file
            ~mode:Lwt_io.Input
            ~flags:Unix.[O_RDONLY]
            filename
            (fun ch -> (Lwt_io.read_value ch : cache Lwt.t))
        in
        Lwt.return loaded
      | false ->
        Lwt.return empty
  in

  let trusted = ref StringSet.empty in
  let add_trusted filename =
    trusted := StringSet.add filename !trusted
  in

  let files = ref loaded.files in
  let update filename entry =
    files := M.add filename entry !files;
    add_trusted filename;
  in

  let modules = ref loaded.modules in

  (* filename => set of files it changes *)
  let build_dependency_map = ref M.empty in
  let add_build_dependency filename changes =
    let set =
      match M.get filename !build_dependency_map with
      | None -> StringSet.add changes StringSet.empty
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

  (* this is a special function required by the Watcher
   * in order to setup minimum required dependency map only for modules
   * present in the last bundle. To be called once *)
  let setup_build_dependencies locations_str =
    build_dependency_map := M.empty;
    StringSet.iter
      (fun location_str ->
         match M.get location_str !modules with
         | Some { build_dependencies; _ } ->
           build_dependencies
           |> M.bindings
           |> List.iter
             (fun (dep, _) -> add_build_dependency dep location_str)
         | _ ->
           ()
      )
      locations_str
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
    (* | { module_ = Some m; package; _ } -> *)
    (*   let%lwt entry, cached = validate_file () in *)
    (*   if cached *)
    (*   then Lwt.return (entry, true) *)
    (*   else begin *)
    (*     let package = *)
    (*       match package with *)
    (*       | None -> None *)
    (*       | Some _ -> *)
    (*         Some (Package.of_json filename entry.content) *)
    (*     in *)
    (*     let () = *)
    (*       match m with *)
    (*       | { modified = Some { build_dependencies; _ }; _ } -> *)
    (*         build_dependencies *)
    (*         |> M.bindings *)
    (*         |> List.iter (fun (dep, _) -> remove_dependency dep filename) *)
    (*       | _ -> () *)
    (*     in *)
    (*     let module_ = { m with state = Module.Initial; modified = None } in *)
    (*     let entry = { entry with module_ = Some module_; package } in *)
    (*     update filename entry; *)
    (*     Lwt.return (entry, false) *)
    (*   end *)
    | { package = Some _; _ } ->
      let%lwt entry, cached = validate_file () in
      if cached
      then Lwt.return (entry, true)
      else begin
        let package = Package.of_json filename entry.content in
        let entry = { entry with package = Some package } in
        update filename entry;
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
        let%lwt entry =
          match entry.st_kind with
          | Unix.S_REG ->
            let%lwt content = Lwt_io.(with_file ~mode:Input filename read) in
            let digest = Digest.string content in
            let entry = { entry with content; digest } in
            update filename entry;
            Lwt.return entry
          | _ ->
            Lwt.return entry
        in
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

  let get_file_no_raise filename =
    let%lwt entry, cached =
      Lwt.catch
        (fun () -> get_file filename)
        (function
          | FileDoesNotExist _ ->
            let entry = {
              exists = false;
              st_mtime = 0.0;
              st_kind = Unix.S_REG;
              content = "";
              digest = "";
              package = None;
            } in
            update filename entry;
            Lwt.return (entry, false)
          | exn ->
            raise exn
        )
    in
    Lwt.return (entry, cached)
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

  let get_module location =
    let build_dependencies_changed build_dependencies =
      build_dependencies
      |> M.bindings
      |> Lwt_list.exists_s
        (fun (filename, known_digest) ->
           let%lwt { digest; _ }, _ = get_file filename in
           Lwt.return (digest <> known_digest)
        )
    in
    let location_str = Module.location_to_string location in
    match M.get location_str !modules with
    | None ->
      Lwt.return_none
    | Some {
        id;
        state;
        module_type;
        files;
        content;
        build_dependencies;
        resolved_dependencies;
        scope;
        exports
      } ->
      match%lwt build_dependencies_changed  build_dependencies with
      | true ->
        build_dependencies
        |> M.bindings
        |> List.iter (fun (dep, _) -> remove_dependency dep location_str);
        modules := M.remove location_str !modules;
        Lwt.return_none
      | false ->
        Lwt.return_some { Module.
          id;
          location;
          state;
          resolved_dependencies;
          module_type;
          files;
          workspace = Workspace.of_string content;
          scope;
          exports;
        }
  in

  let modify_content (m : Module.t) content =
    match m.location with
    | Module.EmptyModule | Module.Runtime ->
      ()
    | _ ->
      let location_str = Module.location_to_string m.location in
      let build_dependencies =
        match M.get location_str !modules with
        | Some { build_dependencies; _} -> build_dependencies
        | None -> M.empty
      in
      let module_entry = {
        ModuleEntry.
        id = m.id;
        state = m.state;
        build_dependencies;
        resolved_dependencies = m.resolved_dependencies;
        module_type = m.module_type;
        files = m.files;
        scope = m.scope;
        exports = m.exports;
        content;
      }
      in
      modules := M.add location_str module_entry !modules
  in

  let add_build_dependencies (m : Module.t) dependencies =
    let location_str = Module.location_to_string m.location in
    let add_build_dependencies existing_dependencies =
      Lwt_list.fold_left_s
        (fun acc filename ->
           let%lwt {digest; _ }, _ = get_file filename in
           add_build_dependency filename location_str;
           Lwt.return (M.add filename digest acc)
        )
        existing_dependencies
        dependencies
    in
    match M.get location_str !modules with
    | Some module_entry ->
        let%lwt build_dependencies =
          add_build_dependencies module_entry.build_dependencies
        in
        modules :=
          M.add location_str { module_entry with build_dependencies} !modules;
        Lwt.return_unit
    | None ->
      Error.ie ("Adding build_dependencies to a non-module: " ^ location_str)
  in

  let get_potentially_invalid filename =
    match M.get filename !files with
    | None -> []
    | Some _ ->
      match M.get filename !build_dependency_map with
      | None -> [filename]
      | Some set -> set |> StringSet.add filename |> StringSet.elements
  in

  let remove filename =
    trusted := StringSet.remove filename !trusted;
  in


  let dump () =
    match init with
    | Memory ->
      Lwt.return_unit
    | Persistent filename ->
      Lwt_io.with_file
        ~mode:Lwt_io.Output
        ~perm:0o640
        ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
        filename
        (fun ch ->
           Lwt_io.write_value ch ~flags:[] { files = !files; modules = !modules })
  in

  Lwt.return {
    file_exists;
    file_stat;
    file_stat_opt;
    get_file;
    get_file_no_raise;
    get_package;
    get_module;
    modify_content;
    add_build_dependencies;
    setup_build_dependencies;
    get_potentially_invalid;
    remove;
    dump;
    starts_empty = !files = M.empty;
  }

