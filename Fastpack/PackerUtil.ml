
let debug = Logs.debug

let rec makedirs dir =
  match%lwt FastpackResolver.stat_option dir with
  | None ->
    let%lwt () = makedirs (FilePath.dirname dir) in
    Lwt_unix.mkdir dir 0o777
  | Some stat ->
    match stat.st_kind with
    | Lwt_unix.S_DIR -> Lwt.return_unit
    | _ -> failwith (dir ^ "is not a directory")

module Mode = struct
  module Visit = FastpackUtil.Visit
  module Ast = FlowParser.Ast
  module Loc = FlowParser.Loc
  module S = Ast.Statement
  module E = Ast.Expression
  module L = Ast.Literal

  type t = Production | Development | Test

  let to_string m =
    match m with
    | Production -> "production"
    | Development -> "development"
    | Test -> "test"

  let rec is_matched expr mode =
    match expr with
    | (_, E.Logical { operator = E.Logical.And; left; _ }) ->
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
      { Workspace. remove; _ }
      mode
      {Visit. parents; _ }
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
          Visit.Continue
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
              Visit.Continue

            (* patch test & consequent *)
            | false ->
              let patch_end =
                match alternate with
                | None -> loc.Loc._end.offset
                | Some (alternate_loc, _) -> alternate_loc.Loc.start.offset
              in
              remove
                loc.Loc.start.offset
                (patch_end - loc.Loc.start.offset);
              Visit.Break
          end
          else begin
            if (not is_matched) then Visit.Continue else Visit.Break
          end
      end
    | _ ->
      Visit.Continue

  let patch_expression
      { Workspace. remove; _ }
      mode
      {Visit. parents; _ }
      (expr_loc, _) =
    match parents with
    | (Visit.APS.Expression (loc, E.Conditional {
        test;
        consequent = (consequent_loc, _);
        alternate = (alternate_loc, _)
      })) :: _ ->
      begin
        match is_matched test mode with
        | None ->
          Visit.Continue
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
              Visit.Continue

            (* patch test & consequent *)
            | false ->
              remove
                loc.Loc.start.offset
                (alternate_loc.Loc.start.offset - loc.Loc.start.offset);
              Visit.Break
          end
          else begin
            if (not is_matched) then Visit.Continue else Visit.Break
          end
      end

    | _ ->
      Visit.Continue
end

module Target = struct
  type t = Application | EcmaScript6 | CommonJS

  let to_string (t : t) =
    match t with
    | Application -> "Application"
    | EcmaScript6 -> "EcmaScript 6 Module"
    | CommonJS -> "CommonJS Module"
end

module Context = struct
  type t = {
    entry_filename : string;
    package_dir : string;
    transpile : transpile;
    stack : Dependency.t list;
    mode : Mode.t;
    target : Target.t;
  }
  and transpile = t -> string -> string -> string

  let to_string { package_dir; stack; mode; _ } =
    Printf.sprintf "Working directory: %s\n" package_dir
    ^ Printf.sprintf "Mode: %s" (Mode.to_string mode)
    ^ "\nCall stack:\n"
    ^ String.concat "\t\n" @@ List.map Dependency.to_string stack
end

module Cache = struct

  module M = Map.Make(String)
  
  type t = {
    get : string -> Module.t option;
    dump : DependencyGraph.t -> unit Lwt.t;
    get_channel : string -> int -> Lwt_io.output_channel;
  }

  type entry = {
    id : string;
    digest : string;
    st_mtime : float;
    dependencies : Dependency.t list;
    source : string;
  }

  let fake =
    { get = (fun _ -> None);
      dump = (fun _ -> Lwt.return_unit);
      get_channel = (fun _ _ -> Lwt_io.null)
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
      makedirs dir
      >> Lwt.return dir
    | None ->
      let dir = FilePath.concat package_dir ".cache/fpack" in
      makedirs dir
      >> Lwt.return dir

  let cache_filename cache_dir prefix filename =
    filename
    |> String.replace ~sub:"/" ~by:"__"
    |> String.replace ~sub:"." ~by:"___"
    |> Printf.sprintf "%s-%s.cache" prefix
    |> FilePath.concat cache_dir

  let create package_dir prefix filename =
    let%lwt cache_dir = create_dir package_dir in
    let cache_filename = cache_filename cache_dir prefix filename in
    let () = debug (fun m -> m "Cache filename: %s" cache_filename) in

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

    let channels = ref M.empty in
    let get_channel filename length =
      let bytes = Lwt_bytes.create (length * 2) in
      let channel = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
      channels := M.add filename (bytes, channel) !channels;
      channel
    in

    let get filename =
      match M.get filename modules with
      | None ->
        None
      | Some { id; digest; st_mtime; dependencies; source; } ->
        Some { Module.
          id;
          filename;
          digest;
          st_mtime;
          dependencies;
          cached = true;
          workspace = Workspace.of_string source;
          scope = FastpackUtil.Scope.empty;
        }
    in

    let dump graph =
      let modules =
        Hashtbl.fold
          (fun
            filename
            ({ id; digest; st_mtime; dependencies; _ } : Module.t)
            modules ->
             let source =
               match M.get filename !channels with
               | None ->
                 Error.ie ("Channel not found for: " ^ filename)
               | Some (bytes, ch) ->
                 Lwt_bytes.to_string
                 @@ Lwt_bytes.extract bytes 0
                 @@ Int64.to_int
                 @@ Lwt_io.position ch
             in
             M.add
               filename
               { id; digest; st_mtime; dependencies; source }
               modules
          )
          graph.DependencyGraph.modules
          M.empty
      in
      Lwt_io.with_file
        ~mode:Lwt_io.Output
        ~perm:0o640
        ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
        cache_filename
        (fun ch -> Lwt_io.write_value ch ~flags:[Marshal.Compat_32] modules)
    in
    Lwt.return {get; dump; get_channel}
end


exception PackError of Context.t * Error.reason


let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename

let relative_name {Context. package_dir; _} filename =
  String.(
    sub
      filename
      (length package_dir + 1)
      (length filename - length package_dir - 1)
  )

let read_module (ctx : Context.t) (cache : Cache.t) filename =
  let filename = abs_path ctx.package_dir filename in

  if not (FilePath.is_subdir filename ctx.package_dir)
  then raise (PackError (ctx, CannotLeavePackageDir filename));

  let st_mtime' () =
    let%lwt {st_mtime; _} =
      try%lwt
        Lwt_unix.stat filename
      with Unix.Unix_error _ ->
        raise (PackError (ctx, CannotReadModule filename))
    in
    Lwt.return st_mtime
  in

  let source' () =
    let%lwt source =
      try%lwt
        Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
      with Unix.Unix_error _ ->
        raise (PackError (ctx, CannotReadModule filename))
    in
    Lwt.return source
  in

  let make_module st_mtime source =
    {
      Module.
      id = Module.make_id (relative_name ctx filename);
      filename = filename;
      st_mtime;
      dependencies = [];
      cached = false;
      digest = Digest.string source;
      workspace = Workspace.of_string source;
      scope = FastpackUtil.Scope.empty;
    }
  in

  match Str.string_match (Str.regexp "^builtin:") filename 0 with
  | true ->
    (* TODO: handle builtins *)
    Lwt.return @@ make_module 0.0 ""
  | false ->
    match cache.get filename with
    | Some cached_module ->
      let%lwt st_mtime = st_mtime' () in
      if cached_module.st_mtime = st_mtime
      then Lwt.return cached_module
      else
        let%lwt source = source' () in
        if cached_module.digest = Digest.string source
        then Lwt.return cached_module
        else Lwt.return @@ make_module st_mtime source
    | None ->
      let%lwt st_mtime = st_mtime' () in
      let%lwt source = source' () in
      Lwt.return @@ make_module st_mtime source
