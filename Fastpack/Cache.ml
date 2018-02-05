module StringSet = Set.Make(String)
module M = Map.Make(String)
module FS = FastpackUtil.FS

module PathEntry = struct
  type t = Unix.stats
end

module FileEntry = struct
  type t = {
    path : PathEntry.t;
    digest : string;
    content : string;
  }
end

module PackageEntry = struct
  type t = {
    file : FileEntry.t;
    package : Package.t;
  }
end

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
    file: FileEntry.t;
    id : string;
    package : Package.t option;
    preprocessed : Preprocessed.t option;
    analyzed : Analyzed.t option;
  }
end

type entry = Exists of bool
           | Path of PathEntry.t
           | File of FileEntry.t
           | Package of PackageEntry.t
           | Module of ModuleEntry.t

type t = {
  file_exists : string -> bool Lwt.t;
  file_stat : string -> Unix.stats Lwt.t;
  file_stat_opt : string -> Unix.stats option Lwt.t;
  get_file : string -> (bool * FileEntry.t) Lwt.t;
  get_package : string -> (bool * PackageEntry.t) Lwt.t;
}

exception FileDoesNotExist of string

let create () =
  let files = ref M.empty in
  (* TODO: try loading the cache *)

  let file_exists filename =
    match M.get filename !files with
    | Some (true, Exists exists) ->
      Lwt.return exists
    | Some (true, _) ->
      Lwt.return_true
    | None | Some (false, _) ->
      let%lwt exists = Lwt_unix.file_exists filename in
      files := M.add filename (true, Exists exists) !files;
      Lwt.return exists
  in

  let file_stat path =
    match M.get path !files with
    | None | Some (false, _) | Some (true, Exists true) ->
      begin
        match%lwt FS.stat_option path with
        | Some stat ->
          files := M.add path (true, Path stat) !files;
          Lwt.return stat
        | None ->
          Lwt.fail (FileDoesNotExist path)
      end
    | Some (true, Exists false) ->
      Lwt.fail (FileDoesNotExist path)
    | Some (true, Path path)
    | Some (true, File { path; _ })
    | Some (true, Package { file = { path; _ }; _})
    | Some (true, Module { file = { path; _ }; _}) ->
      Lwt.return path
  in

  let file_stat_opt path =
    match M.get path !files with
    | None | Some (false, _) | Some (true, Exists true) ->
      begin
        match%lwt FS.stat_option path with
        | Some stat ->
          files := M.add path (true, Path stat) !files;
          Lwt.return_some stat
        | None ->
          files := M.add path (true, Exists false) !files;
          Lwt.return_none
      end
    | Some (true, Exists false) ->
      Lwt.return_none
    | Some (true, Path path)
    | Some (true, File { path; _ })
    | Some (true, Package { file = { path; _ }; _ })
    | Some (true, Module { file = { path; _ }; _}) ->
      Lwt.return_some path
  in

  let get_file filename =
    match M.get filename !files with
    | Some (true, File file)
    | Some (true, Package { file; _ })
    | Some (true, Module { file; _ }) ->
      Lwt.return (true, file)
    | _ ->
      let%lwt path =
        match%lwt file_stat_opt filename with
        | None ->
          Lwt.fail (FileDoesNotExist filename)
        | Some ({ st_kind = Unix.S_REG; _} as path) ->
          Lwt.return path
        | _ ->
          (* TODO: provide more meaningful error *)
          Lwt.fail (FileDoesNotExist filename)
      in
      let%lwt content = Lwt_io.(with_file ~mode:Input filename Lwt_io.read) in
      let digest = Digest.string content in
      let file = {FileEntry. path; content; digest } in
      files := M.add filename (true, File file) !files;
      Lwt.return (false, file)
  in

  let get_package filename =
    match M.get filename !files with
    | Some (true, Package package) ->
      Lwt.return (true, package)
    | Some (true, Module { package = Some package; file; _ }) ->
      Lwt.return (true, { PackageEntry. file; package })
    | Some (true, Module { package = None; _ }) ->
      (* TODO: check if filename ends with /package.json
       * If so - construct package, update module entry
       * otherwise - fail
       * *)
      failwith ("Module is not package.json: " ^ filename)
    | _ ->
      let%lwt (cached, file) = get_file filename in
      let package = { PackageEntry.
          file;
          package = Package.of_json filename file.FileEntry.content
        }
      in
      files := M.add filename (true, Package package) !files;
      Lwt.return (cached, package)
  in


  {
    file_exists;
    file_stat;
    file_stat_opt;
    get_file;
    get_package;
  }


