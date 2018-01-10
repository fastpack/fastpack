
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

  let is_matched expr mode =
    match expr with
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
      (stmt_loc, stmt) =
    match parents with
    | (Visit.APS.Statement (loc, S.If {
        test;
        consequent = (consequent_loc, consequent);
        alternate;
      })) :: _ ->
      begin
        match is_matched test mode with
        | None ->
          Visit.Continue
        | Some is_matched ->
          if (consequent_loc, consequent) = (stmt_loc, stmt) then begin
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

let read_module (ctx : Context.t) filename =
  let filename = abs_path ctx.package_dir filename in

  if not (FilePath.is_subdir filename ctx.package_dir)
  then raise (PackError (ctx, CannotLeavePackageDir filename));

  let%lwt id, source =
    match Str.string_match (Str.regexp "^builtin:") filename 0 with
    | true ->
      (* TODO: handle builtins *)
      Lwt.return (filename, "")
    | false ->
      let%lwt source =
        try%lwt
          Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
        with Unix.Unix_error _ ->
          raise (PackError (ctx, CannotReadModule filename))
      in
      Lwt.return (Module.make_id (relative_name ctx filename), source)
  in
  Lwt.return {
    Module.
    id;
    filename = filename;
    workspace = Workspace.of_string source;
    scope = FastpackUtil.Scope.empty;
  }
