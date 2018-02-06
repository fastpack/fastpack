(* if no entry exists - read what is requested
 * can be: existance, stats, file, package, module
 * if entry exists and not trusted, validate all properties which are present
 * if entry exists and trusted, but some properties are not present
 * - read only those properties *)


module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS

module ModuleEntry = struct
  module Preprocessed = struct
    type t = {
      content : string option;
      dependencies : (string * float * string) list;
    }
  end

  module Analyzed = struct
    type t = {
      es_module : bool;
      content : string;
      dependencies : (string * float * string) list;
      resolved_dependencies : (Dependency.t * string) list;
    }
  end

  type t = {
    id : string;
    preprocessed : Preprocessed.t option;
    analyzed : Analyzed.t option;
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
}

exception FileDoesNotExist of string

let create () =
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

  let trusted = ref StringSet.empty in
  let files = ref M.empty in
  (* TODO: try loading the cache *)

  let update filename entry =
    files := M.add filename entry !files;
    trusted := StringSet.add filename !trusted
  in

  let validate _filename _entry =
    failwith "Not imppl"
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
    | _, None
    | true, Some _ ->
      let%lwt entry, cached = get_file filename in
      let package = Package.of_json filename entry.content in
      update filename { entry with package = Some package };
      Lwt.return (package, cached)
    | false, Some entry ->
      let%lwt { exists; package; _ }, cached = validate filename entry in
      match exists, package with
      | false, _ ->
        Lwt.fail (FileDoesNotExist filename)
      | true, Some package ->
        Lwt.return (package, cached)
      | true, None ->
        (* TODO: not a package.json error *)
        Lwt.fail (FileDoesNotExist filename)
  in


  {
    file_exists;
    file_stat;
    file_stat_opt;
    get_file;
    get_package;
  }


