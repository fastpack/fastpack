module StringSet = Set.Make(String)
module M = Map.Make(String)

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module P = Ast.Pattern
module L = Ast.Literal

module FS = FastpackUtil.FS

let debug = Logs.debug

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
            _
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
          _
        });
        operator;
      })
    | (_, E.Binary {
        left = (_, E.Member {
          _object = (_, E.Member {
            _object = (_, E.Identifier (_, "process"));
            property = E.Member.PropertyIdentifier (_, "env");
            computed = false;
            _
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
          _
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
                (consequent_loc.Loc._end.offset)
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
            _
          });
          property = E.Member.PropertyIdentifier (_, "NODE_ENV");
          computed = false;
          _
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
    project_root : string;
    current_dir : string;
    project_package : Package.t;
    output_dir : string;
    entry_location : Module.location;
    current_location : Module.location;
    stack : Module.Dependency.t list;
    mode : Mode.t;
    target : Target.t;
    resolver : Resolver.t;
    preprocessor : Preprocessor.t;
    export_finder : ExportFinder.t;
    graph : DependencyGraph.t;
  }

  let to_string { current_dir; stack; mode; current_location; _ } =
    let stack =
      stack
      |> List.map (Module.Dependency.to_string ~dir:(Some current_dir))
      |> String.concat "\t\n"
    in
    let location_str =
      Module.location_to_string ~base_dir:(Some current_dir) current_location
    in
    Printf.([
        sprintf "Project Directory: %s" current_dir;
        sprintf "Mode: %s" (Mode.to_string mode);
        "Call Stack:" ^ if stack <> ""
                        then sprintf "\n\t%s" stack
                        else " (empty)";
        sprintf "Processing Module: %s" location_str;
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
    (Error.to_string ctx.current_dir error)

let relative_name {Context. current_dir; _} filename =
  match Str.string_match (Str.regexp "^builtin:") filename 0 with
  | true ->
    filename
  | false ->
    String.(
      sub
        filename
        (length current_dir + 1)
        (length filename - length current_dir - 1)
    )

let resolve (ctx : Context.t) (request : Module.Dependency.t) =
  let basedir =
    match request.requested_from with
    | Module.File { filename = Some filename; _ } ->
      FilePath.dirname filename
    | Module.File { filename = None; _ }
    | Module.Runtime
    | Module.EmptyModule
    | Module.Main _ ->
      ctx.current_dir
  in
  Lwt.catch
    (fun () ->
       ctx.resolver.resolve ~basedir request.request
       (* ctx.resolver.resolve request.request basedir *)
    )
    (function
      | Resolver.Error path ->
        Lwt.fail (PackError (ctx, CannotResolveModule (path, request)))
      | exn ->
        raise exn
    )


let read_module
    ?(from_module=None)
    ~(ctx : Context.t)
    ~(cache : Cache.t)
    (location : Module.location) =
  debug (fun x -> x "READING: %s" (Module.location_to_string location));
  let make_module location source =
    let%lwt package =
      match location with
      | Module.EmptyModule | Module.Runtime ->
        Lwt.return Package.empty
      | Module.Main _ ->
        Lwt.return ctx.project_package
      | Module.File { filename = Some filename; _ } ->
        let%lwt package, _ =
          cache.find_package_for_filename ctx.current_dir filename
        in
        Lwt.return package
      | Module.File { filename = None; _ } ->
        match from_module with
        | None -> Lwt.return ctx.project_package
        | Some (m : Module.t) -> Lwt.return m.package
    in
    Module.{
      id = make_id ctx.current_dir location;
      location;
      package;
      resolved_dependencies = [];
      build_dependencies = M.empty;
      module_type = Module.CJS;
      files = [];
      state = Initial;
      workspace = Workspace.of_string source;
      scope = FastpackUtil.Scope.empty;
      exports = FastpackUtil.Scope.empty_exports;
    }
    |> Lwt.return
  in

  match location with
  | Module.Main entry_points ->
    let source =
      entry_points
      |> List.map (fun req -> Printf.sprintf "import '%s';\n" req)
      |> String.concat ""
    in
    make_module location source

  | Module.EmptyModule ->
    make_module location "module.exports = {};"

  | Module.Runtime ->
    make_module location FastpackTranspiler.runtime

  | Module.File { filename; _ } ->
    match%lwt cache.get_module location with
    | Some m ->
      Lwt.return m
    | None ->
      (* filename is Some (abs path) or None at this point *)
      let%lwt source, self_dependency =
        match filename with
        | Some filename ->
          let%lwt _ =
            if not (FilePath.is_subdir filename ctx.project_root)
            then Lwt.fail (PackError (ctx, CannotLeavePackageDir filename))
            else Lwt.return_unit
          in
          let%lwt { content; _ }, _ =
            Lwt.catch
              (fun () -> cache.get_file filename )
              (function
                | Cache.FileDoesNotExist filename ->
                  Lwt.fail (PackError (ctx, CannotReadModule filename))
                | exn ->
                  raise exn
              )
          in
          (* strip #! from the very beginning *)
          let content_length = String.length content in
          let content =
            if  content_length > 2
            then
              if String.get content 0 = '#' && String.get content 1 = '!'
              then
                let nl_index = String.find ~sub:"\n" content in
                String.sub content nl_index (content_length - nl_index)
              else
                content
            else
              content
          in
          Lwt.return (Some content, [filename])
        | None ->
          Lwt.return (None, [])
      in
      let { Preprocessor. process; _ } = ctx.preprocessor in
      let%lwt source, build_dependencies, files =
        Lwt.catch
          (fun () -> process location source)
          (function
           | FlowParser.Parse_error.Error args ->
             let location_str = Module.location_to_string location in
             Lwt.fail (PackError (ctx, CannotParseFile (location_str, args)))
           | Preprocessor.Error message ->
             Lwt.fail (PackError (ctx, PreprocessorError message))
           | FastpackUtil.Error.UnhandledCondition message ->
             Lwt.fail (PackError (ctx, UnhandledCondition message))
           | exn ->
             Lwt.fail exn
          )
      in

      let%lwt files =
        Lwt_list.map_s
          (fun filename ->
            let%lwt {content; _}, _ = cache.get_file filename in
            Lwt.return (filename, content)
          )
          files
      in

      let%lwt m = make_module location source in
      let%lwt build_dependencies =
        Lwt_list.fold_left_s
          (fun build_dependencies filename ->
             let%lwt { digest; _ }, _ = cache.get_file filename in
             Lwt.return (M.add filename digest build_dependencies)
          )
          M.empty
          (self_dependency @ build_dependencies)
      in
      let m = {
        m with
        state = Module.Preprocessed;
        files;
        build_dependencies;
      } in

      let () = cache.modify_content m source in
      Lwt.return m


let emit_module_files (ctx : Context.t) (m : Module.t) =
  Lwt_list.iter_s
    (fun (filename, content) ->
      let path = FS.abs_path ctx.output_dir filename in
      let%lwt () = FS.makedirs (FilePath.dirname path) in
      Lwt_io.(with_file
                ~mode:Lwt_io.Output
                ~perm:0o640
                ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                path
                (fun ch -> write ch content)
             )
    )
    m.files

let is_json (location : Module.location) =
  match location with
  | Module.File { filename = Some filename; _ } ->
    String.suffix ~suf:".json" filename
  | _ ->
    false


let get_module_type stmts =
  (* TODO: what if module has only import() expression? *)
  let import_or_export module_type ((_, stmt) : Loc.t S.t) =
    match module_type with
    | Module.ESM | Module.CJS_esModule -> module_type
    | Module.CJS ->
      match stmt with
      | S.Expression {
          expression = (_, E.Assignment {
              operator = E.Assignment.Assign;
              left = (_, P.Expression (_, E.Member {
                  _object = (_, E.Identifier (_, "exports"));
                  property = E.Member.PropertyIdentifier (_, "__esModule");
                  computed = false;
                  _
                }));
              right = (_, E.Literal { value = L.Boolean true; _});
          });
          _
        } ->
        Module.CJS_esModule
      | S.ExportDefaultDeclaration _
      | S.ExportNamedDeclaration _
      | S.ImportDeclaration _ ->
        Module.ESM
      | _ ->
        module_type
  in
  List.fold_left import_or_export Module.CJS stmts

