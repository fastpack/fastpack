
module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal

module FS = FastpackUtil.FS

let debug = Logs.debug

let rec makedirs dir =
  match%lwt FastpackUtil.FS.stat_option dir with
  | None ->
    let%lwt () = makedirs (FilePath.dirname dir) in
    Lwt_unix.mkdir dir 0o777
  | Some stat ->
    match stat.st_kind with
    | Lwt_unix.S_DIR -> Lwt.return_unit
    | _ ->
      Error.ie
      @@ Printf.sprintf "'%s' expected to be a directory" dir

module Mode = struct
  module Visit = FastpackUtil.Visit

  type t = Production | Development | Test

  let to_string m =
    match m with
    | Production -> "production"
    | Development -> "development"
    | Test -> "test"

  let rec is_matched expr mode =
    match expr with
    | (_, E.Logical { operator = E.Logical.Or; left; _ }) ->
      is_matched left mode

    | (_, E.Binary {
        left = (_, E.Literal { value = L.String value; _});
        right = (_, E.Member {
          _object = (_, E.Member {
            _object = (_, E.Identifier (_, "process"));
            property = E.Member.PropertyIdentifier (_, "env");
            computed = false;
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
        });
        operator;
      })
    | (_, E.Binary {
        left = (_, E.Member {
          _object = (_, E.Member {
            _object = (_, E.Identifier (_, "process"));
            property = E.Member.PropertyIdentifier (_, "env");
            computed = false;
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
        });
        right = (_, E.Literal { value = L.String value; _});
        operator;
      }) ->
      begin
        match operator with
        | E.Binary.Equal | E.Binary.StrictEqual ->
          Some (value = to_string mode)
        | E.Binary.NotEqual | E.Binary.StrictNotEqual ->
          Some (value <> to_string mode)
        | _ ->
          None
      end
    | _ ->
      None

  let patch_statement
      { Workspace. remove; patch_loc; _ }
      mode
      ({Visit. parents; _ } as visit_ctx)
      (stmt_loc, _) =
    match parents with
    | (Visit.APS.Statement (loc, S.If {
        test;
        consequent = (consequent_loc, _);
        alternate;
      })) :: _ ->
      begin
        match is_matched test mode with
        | None ->
          Visit.Continue visit_ctx
        | Some is_matched ->
          if consequent_loc = stmt_loc then begin
            match is_matched with
            (* patch test & alternate *)
            | true ->
              remove
                loc.Loc.start.offset
                (consequent_loc.Loc.start.offset - loc.Loc.start.offset);
              begin
                match alternate with
                | None -> ()
                | Some (alternate_loc, _) ->
                  remove
                    consequent_loc.Loc._end.offset
                    (alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset)
              end;
              Visit.Continue visit_ctx

            (* patch test & consequent *)
            | false ->
              let () =
                match alternate with
                | None ->
                  patch_loc loc "{}"
                | Some (alternate_loc, _) ->
                  remove
                    loc.Loc.start.offset
                    (alternate_loc.Loc.start.offset - loc.Loc.start.offset);
              in
              Visit.Break
          end
          else begin
            if (not is_matched) then Visit.Continue visit_ctx else Visit.Break
          end
      end
    | _ ->
      Visit.Continue visit_ctx

  let patch_expression
      { Workspace. remove; patch_loc; _ }
      mode
      ({Visit. parents; _ } as visit_ctx)
      (expr_loc, expr) =
    match parents with
    | (Visit.APS.Expression (loc, E.Conditional {
        test;
        consequent = (consequent_loc, _);
        alternate = (alternate_loc, _)
      })) :: _ ->
      begin
        match is_matched test mode with
        | None ->
          Visit.Continue visit_ctx
        | Some is_matched ->
          if consequent_loc = expr_loc then begin
            match is_matched with
            (* patch test & alternate *)
            | true ->
              remove
                loc.Loc.start.offset
                (consequent_loc.Loc.start.offset - loc.Loc.start.offset);
              remove
                consequent_loc.Loc._end.offset
                (alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset);
              Visit.Continue visit_ctx

            (* patch test & consequent *)
            | false ->
              remove
                loc.Loc.start.offset
                (alternate_loc.Loc.start.offset - loc.Loc.start.offset);
              Visit.Break
          end
          else begin
            if (not is_matched) then Visit.Continue visit_ctx else Visit.Break
          end
      end

    | _ ->
      match expr with
      | E.Member {
          _object = (_, E.Member {
            _object = (_, E.Identifier (_, "process"));
            property = E.Member.PropertyIdentifier (_, "env");
            computed = false;
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
        } ->
        patch_loc expr_loc @@ "\"" ^ to_string mode ^ "\"";
        Visit.Break;
      | _ ->
        Visit.Continue visit_ctx
end

module Target = struct
  type t = Application | ESM | CommonJS

  let to_string (t : t) =
    match t with
    | Application -> "Application"
    | ESM -> "EcmaScript Module"
    | CommonJS -> "CommonJS Module"
end

module Context = struct
  type t = {
    entry_filename : string;
    package_dir : string;
    current_filename : string;
    stack : Dependency.t list;
    mode : Mode.t;
    target : Target.t;
    resolver : NodeResolver.t;
    preprocessor : Preprocessor.t;
  }

  let to_string { entry_filename; package_dir; stack; mode; current_filename; _ } =
    let relative filename =
      String.replace ~sub:(package_dir ^ "/") ~by:"" filename
    in
    let stack =
      stack
      |> List.map (Dependency.to_string ~dir:(Some package_dir))
      |> String.concat "\t\n"
    in
    Printf.([
        sprintf "Working Directory: %s" package_dir;
        sprintf "Entry Point: %s" @@ relative entry_filename;
        sprintf "Mode: %s" (Mode.to_string mode);
        "Call Stack:" ^ if stack <> ""
                        then sprintf "\n\t%s" stack
                        else " (empty)";
        sprintf "Processing File: %s" @@ relative current_filename;
      ])
    |> List.fold_left
      (fun acc part -> if part <> "" then acc ^ part ^ "\n" else acc)
      ""
end


module Cache = struct

  module M = Map.Make(String)

  type strategy = Normal | Ignore

  type t = {
    get : string -> Module.t option;
    dump : unit -> unit Lwt.t;
    add : Module.t -> string -> bool -> unit;
    loaded : bool;
  }

  type entry = {
    id : string;
    digest : string;
    st_mtime : float;
    es_module : bool;
    resolved_dependencies : (Dependency.t * string) list;
    build_dependencies : (string * float * string) list;
    source : string;
    analyzed : bool;
  }

  let fake =
    { get = (fun _ -> None);
      dump = (fun _ -> Lwt.return_unit);
      add = (fun _ _ _ -> ());
      loaded = false;
    }

  let create_dir package_dir =
    let try_dir dir =
      try%lwt
        let%lwt stat = Lwt_unix.stat dir in
        match stat.st_kind with
        | Lwt_unix.S_DIR -> Lwt.return_some dir
        | _ -> Lwt.return_none
      with Unix.Unix_error _ ->
        Lwt.return_none
    in
    match%lwt try_dir (FilePath.concat package_dir "node_modules") with
    | Some dir ->
      let dir = FilePath.concat dir ".cache/fpack" in
      let%lwt () = makedirs dir in
      Lwt.return dir
    | None ->
      let dir = FilePath.concat package_dir ".cache/fpack" in
      let%lwt () = makedirs dir in
      Lwt.return dir

  let cache_filename cache_dir prefix filename =
    filename
    |> String.replace ~sub:"/" ~by:"__"
    |> String.replace ~sub:"." ~by:"___"
    |> Printf.sprintf "%s-%s-%s.cache" prefix Version.github_commit
    |> FilePath.concat cache_dir

  let cache cache_filename modules =

    let loaded = modules <> M.empty in
    let modules = ref modules in

    let add (m : Module.t) source analyzed =
      modules :=
        M.add
          m.filename
          { id = m.id; digest = m.digest; st_mtime = m.st_mtime;
            resolved_dependencies = m.resolved_dependencies;
            build_dependencies = m.build_dependencies;
            es_module = m.es_module;
            analyzed;
            source
          }
          !modules;
    in

    let get filename =
      match M.get filename !modules with
      | None ->
        None
      | Some {
          id;
          digest;
          st_mtime;
          resolved_dependencies;
          build_dependencies;
          source;
          analyzed;
          es_module; } ->
        Some { Module.
          id;
          filename;
          digest;
          st_mtime;
          resolved_dependencies;
          build_dependencies;
          es_module;
          analyzed;
          workspace = Workspace.of_string source;
          scope = FastpackUtil.Scope.empty;
          exports = []
        }
    in

    let dump () =
      Lwt_io.with_file
        ~mode:Lwt_io.Output
        ~perm:0o640
        ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
        cache_filename
        (fun ch -> Lwt_io.write_value ch ~flags:[Marshal.Compat_32] !modules)
    in
    Lwt.return { get; dump; add; loaded }

  let create package_dir prefix filename =
    let%lwt cache_dir = create_dir package_dir in
    let cache_filename = cache_filename cache_dir prefix filename in

    let%lwt modules =
      match%lwt Lwt_unix.file_exists cache_filename with
      | true ->
        Lwt_io.with_file
          ~mode:Lwt_io.Input
          ~flags:Unix.[O_RDONLY]
          cache_filename
          (fun ch -> (Lwt_io.read_value ch : entry M.t Lwt.t))
      | false ->
        Lwt.return @@ (M.empty : entry M.t)
    in
    cache cache_filename modules

end


exception PackError of Context.t * Error.reason


let relative_name {Context. package_dir; _} filename =
  match Str.string_match (Str.regexp "^builtin:") filename 0 with
  | true ->
    filename
  | false ->
    String.(
      sub
        filename
        (length package_dir + 1)
        (length filename - length package_dir - 1)
    )

let rec read_module (ctx : Context.t) (cache : Cache.t) filename =

    let st_mtime' filename =
      let%lwt {st_mtime; _} =
        try%lwt
          Lwt_unix.stat filename
        with Unix.Unix_error _ ->
          raise (PackError (ctx, CannotReadModule filename))
      in
      Lwt.return st_mtime
    in

    let source' filename =
      let%lwt source =
        try%lwt
          Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
        with Unix.Unix_error _ ->
          raise (PackError (ctx, CannotReadModule filename))
      in
      Lwt.return source
    in

  let make_module ?(build_dependencies=[]) id filename st_mtime source =
    let%lwt build_dependencies =
      Lwt_list.map_s
        (fun filename ->
           (** TODO: !!! Make sure to raise exceptions using Lwt *)
           (** TODO: !!! Handle potential dependency cycles *)
           (** TODO: !!! Modify ctx.stack when processing dependency *)
           let filename = FS.abs_path ctx.package_dir filename in
           let%lwt m = read_module ctx cache filename in
           Lwt.return Module.(m.filename, m.st_mtime, m.digest)
        )
        build_dependencies
    in
    Lwt.return {
      Module.
      id;
      filename;
      st_mtime;
      resolved_dependencies = [];
      build_dependencies;
      es_module = false;
      analyzed = false;
      digest = Digest.string source;
      workspace = Workspace.of_string source;
      scope = FastpackUtil.Scope.empty;
      exports = []
    }
  in

  match filename with
  | "builtin:os"
  | "builtin:module"
  | "builtin:path"
  | "builtin:util"
  | "builtin:fs"
  | "builtin:tty"
  | "builtin:net"
  | "builtin:events" ->
    (* TODO: handle builtins *)
    make_module (Module.make_id filename) filename 0.0 ""

  | "builtin:__fastpack_runtime__" ->
    make_module (Module.make_id filename) filename 0.0 FastpackTranspiler.runtime

  | _ ->
    let filename = FS.abs_path ctx.package_dir filename in

    if not (FilePath.is_subdir filename ctx.package_dir)
    then raise (PackError (ctx, CannotLeavePackageDir filename));


    let preprocess_module filename st_mtime source =
      let { Preprocessor. process; _ } = ctx.preprocessor in
      let relname = relative_name ctx filename in
      let%lwt source, build_dependencies = process relname source in
      let%lwt m =
        make_module
          ~build_dependencies
          (Module.make_id relname)
          filename
          st_mtime
          source
      in
      cache.add m source false;
      Lwt.return m
    in

    let build_dependencies_changed {Module. build_dependencies; _} =
      Lwt_list.exists_s
        (fun (filename, st_mtime, digest) ->
           (** TODO: !!! Make sure to raise exceptions using Lwt *)
           (** TODO: !!! Handle potential dependency cycles *)
           (** TODO: !!! Modify ctx.stack when processing dependency *)
           let%lwt (m : Module.t) = read_module ctx cache filename in
           Lwt.return (m.st_mtime <> st_mtime ||
                       m.st_mtime = st_mtime && m.digest <> digest)
        )
        build_dependencies
    in

    match cache.get filename with
    | Some cached_module ->
      if%lwt build_dependencies_changed cached_module
      then begin
        let%lwt st_mtime = st_mtime' filename in
        let%lwt source = source' filename in
        preprocess_module filename st_mtime source
      end
      else begin
        let%lwt st_mtime = st_mtime' filename in
        if cached_module.st_mtime = st_mtime
        then Lwt.return cached_module
        else
          let%lwt source = source' filename in
          if cached_module.digest = Digest.string source
          then Lwt.return cached_module
          else preprocess_module filename st_mtime source
      end
    | None ->
      let%lwt st_mtime = st_mtime' filename in
      let%lwt source = source' filename in
      preprocess_module filename st_mtime source


let is_ignored_request request =
  List.exists
    (fun e -> String.suffix ~suf:("." ^ e) request)
    ["css"; "less"; "sass"; "woff"; "svg"; "png"; "jpg"; "jpeg";
     "gif"; "ttf"]

let is_json filename =
  String.suffix ~suf:".json" filename


let is_es_module stmts =
  (* TODO: what if module has only import() expression? *)
  let import_or_export ((_, stmt) : Loc.t S.t) =
    match stmt with
    | S.ExportDefaultDeclaration _
    | S.ExportNamedDeclaration _
    | S.ImportDeclaration _ ->
      true
    | _ ->
      false
  in
  List.exists import_or_export stmts

