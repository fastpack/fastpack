module StringSet = Set.Make(String)

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module P = Ast.Pattern
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
    package : Package.t;
    stack : Dependency.t list;
    mode : Mode.t;
    target : Target.t;
    resolver : NodeResolver.t;
    preprocessor : Preprocessor.t;
    graph : DependencyGraph.t;
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


exception PackError of Context.t * Error.reason
exception ExitError of string
exception ExitOK

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n%s"
    (Context.to_string ctx)
    (Error.to_string ctx.package_dir error)

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


let read_module (ctx : Context.t) (cache : Cache.t) location =
  let make_module id filename source =
    {
      Module.
      id;
      filename;
      resolved_dependencies = [];
      es_module = false;
      state = Initial;
      workspace = Workspace.of_string source;
      scope = FastpackUtil.Scope.empty;
      exports = [];
    }
  in

  let empty_module = make_module
      (Module.make_id "builtin:__empty_module__")
      "__empty_module__"
      "module.exports = {};"
  in

  let runtime_module = make_module
      (Module.make_id "builtin:__fastpack_runtime__")
      "__fastpack_runtime__"
      FastpackTranspiler.runtime
  in

  match location with
  | Module.EmptyModule ->
    Lwt.return empty_module

  | Module.Runtime ->
    (* Printf.printf ("RUNTIME\n"); *)
    Lwt.return runtime_module

  | Module.File filename ->
    (* Printf.printf "FILENAMEME: %s\n" filename; *)
    let filename = FS.abs_path ctx.package_dir filename in

    let%lwt _ =
      if not (FilePath.is_subdir filename ctx.package_dir)
      then Lwt.fail (PackError (ctx, CannotLeavePackageDir filename))
      else Lwt.return_unit
    in
    let%lwt m, _ =
      Lwt.catch
        (fun () -> cache.get_module filename (relative_name ctx filename))
        (function
          | Cache.FileDoesNotExist filename ->
            Lwt.fail (PackError (ctx, CannotReadModule filename))
          | exn ->
            raise exn
        )
    in
    let%lwt m =
      if m.state = Module.Initial
      then begin
        let { Preprocessor. process; _ } = ctx.preprocessor in
        let relname = relative_name ctx filename in
        let%lwt content, build_dependencies =
          Lwt.catch
            (fun () -> process relname m.workspace.Workspace.value)
            (function
             | FlowParser.Parse_error.Error args ->
               Lwt.fail (PackError (ctx, CannotParseFile (filename, args)))
             | Preprocessor.Error message ->
               Lwt.fail (PackError (ctx, PreprocessorError message))
             | exn ->
               Lwt.fail exn
            )
        in
        let m = {
          m with
          state = Module.Preprocessed;
          workspace = Workspace.of_string content
        } in
        let%lwt () = cache.modify_content m content in
        let%lwt () = cache.add_build_dependencies m build_dependencies in
        Lwt.return m
      end
      else
        Lwt.return m
    in
    Lwt.return m

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
    | S.Expression {
        expression = (_, E.Assignment {
            operator = E.Assignment.Assign;
            left = (_, P.Expression (_, E.Member {
                _object = (_, E.Identifier (_, "exports"));
                property = E.Member.PropertyIdentifier (_, "__esModule");
                computed = false
              }));
            right = (_, E.Literal { value = L.Boolean true; _});
        });
        _
      }
    | S.ExportDefaultDeclaration _
    | S.ExportNamedDeclaration _
    | S.ImportDeclaration _ ->
      true
    | _ ->
      false
  in
  List.exists import_or_export stmts

