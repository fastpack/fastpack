
module MLSet = Module.LocationSet 
module StringSet = Set.Make(String)
module M = Map.Make(String)

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module P = Ast.Pattern
module L = Ast.Literal

module UTF8 = FastpackUtil.UTF8
module FS = FastpackUtil.FS
module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit

let debug = Logs.debug
let re_name = Re_posix.compile_pat "[^A-Za-z0-9_]+"


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
    )
    (function
      | Resolver.Error path ->
        Lwt.fail (Context.PackError (ctx, CannotResolveModule (path, request)))
      | exn ->
        raise exn
    )

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
            if not (FilePath.is_subdir filename ctx.current_dir)
            then Lwt.fail (Context.PackError (ctx, CannotLeavePackageDir filename))
            else Lwt.return_unit
          in
          let%lwt { content; _ }, _ =
            Lwt.catch
              (fun () -> cache.get_file filename )
              (function
                | Cache.FileDoesNotExist filename ->
                  Lwt.fail (Context.PackError (ctx, CannotReadModule filename))
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
              let src = match source with 
                | Some src -> src
                | None -> "" in
              Lwt.fail (Context.PackError (ctx, CannotParseFile (location_str, args, src)))
            | Preprocessor.Error message ->
              Lwt.fail (Context.PackError (ctx, PreprocessorError message))
            | FastpackUtil.Error.UnhandledCondition message ->
              Lwt.fail (Context.PackError (ctx, UnhandledCondition message))
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


let build (ctx : Context.t) =

  (* TODO: handle this at a higher level, IllegalConfiguration error *)
  let%lwt () =
    if (ctx.Context.target = Target.ESM)
    then Lwt.fail (Context.PackError (ctx, NotImplemented (
        None, "EcmaScript6 target is not supported "
              ^ "for the regular packer - use flat\n"
      )))
    else Lwt.return_unit
  in

  let cache = ctx.cache in

  let analyze _id location source =
    let ((_, stmts, _) as program), _ = Parser.parse_source source in


    let module Ast = FlowParser.Ast in
    let module Loc = FlowParser.Loc in
    let module S = Ast.Statement in
    let module E = Ast.Expression in
    let module L = Ast.Literal in

    let dependencies = ref [] in
    let workspace = ref (Workspace.of_string source) in
    let ({Workspace.
           patch;
           patch_with;
           patch_loc;
           patch_loc_with;
           remove;
           remove_loc;
           _
         } as patcher) = Workspace.make_patcher workspace
    in

    let program_scope, exports = Scope.of_program stmts in
    let scopes = ref [program_scope] in
    let top_scope () = List.hd !scopes in
    let push_scope scope =
      scopes := scope :: !scopes
    in
    let pop_scope () =
      scopes := List.tl !scopes
    in
    let get_binding name =
      Scope.get_binding name (top_scope ())
    in
    let has_binding name =
      Scope.has_binding name (top_scope ())
    in

    let define_var = Printf.sprintf "const %s = %s;" in

    let fastpack_require id request =
      Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")"
        request
        id
    in

    let fastpack_import id request =
      Printf.sprintf "__fastpack_import__(/* \"%s\" */ \"%s\")"
        request
        id
    in

    let get_module (dep : Module.Dependency.t) dep_map =
      match Module.DependencyMap.get dep dep_map with
      | Some m -> m
      | None ->
        raise (Context.PackError (ctx, CannotResolveModule (dep.request, dep)))
    in

    let rec avoid_name_collision ?(n=0) name =
      let name =
        match n with
        | 0 -> name
        | _ -> Printf.sprintf "%s_%d" name n
      in
      if not (has_binding name)
      then name
      else avoid_name_collision ~n:(n + 1) name
    in

    let n_module = ref 0 in
    let module_vars = ref M.empty in
    let ensure_module_var ?(name=None) request (m : Module.t) =
      match M.get m.Module.id !module_vars, name with
      | Some var, None ->
        var, ""
      | Some var, Some name ->
        if var = name
        then var, ""
        else var, define_var name var
      | None, Some name ->
        module_vars := M.add m.id name !module_vars;
        name, define_var name (fastpack_require m.id request)
      | None, None ->
        let var =
          n_module := !n_module + 1;
          let name = Re.replace ~f:(fun _ -> "_") re_name request in
          avoid_name_collision (Printf.sprintf "_%d_%s" !n_module name)
        in
        module_vars := M.add m.Module.id var !module_vars;
        var, define_var var (fastpack_require m.id request)
    in

    let module_default_vars = ref M.empty in
    let ensure_module_default_var m =
      match M.get m.Module.id !module_default_vars with
      | Some var ->
        var, ""
      | None ->
        let module_var, module_var_definition = ensure_module_var "" m in
        match m.module_type with
        | Module.ESM ->
          module_var ^ ".default", module_var_definition
        | Module.CJS | Module.CJS_esModule ->
          let var = avoid_name_collision (module_var ^ "__default") in
          let expression =
            Printf.sprintf "%s.__esModule ? %s.default : %s"
              module_var
              module_var
              module_var
          in
          module_default_vars := M.add m.Module.id var !module_default_vars;
          var, module_var_definition ^ (define_var var expression)
    in

    let add_dependency request =
      let dep = {
        Module.Dependency.
        request;
        requested_from = location;
      } in
      begin
        dependencies := dep :: !dependencies;
        dep
      end
    in

    let ensure_export_exists ~dep_map (m: Module.t) name =
      match ctx.export_finder.exists dep_map m name with
      | ExportFinder.Yes | ExportFinder.Maybe -> ()
      | ExportFinder.No ->
        let location_str =
          Module.location_to_string ~base_dir:(Some ctx.current_dir) m.location
        in
        raise (Context.PackError (ctx, CannotFindExportedName (name, location_str)))
    in

    let export_from_specifiers =
      List.map
        (fun (_,{S.ExportNamedDeclaration.ExportSpecifier.
                  local = (_, local);
                  exported }) ->
          let exported =
            match exported with
            | Some (_, name) -> name
            | None -> local
          in
          exported, local
        )
    in

    let define_export exported local =
      Printf.sprintf
        "Object.defineProperty(exports, \"%s\", {enumerable: true, get: function() {return %s;}});"
        exported
        local
    in

    let patch_imported_name ~dep_map ~from_request _ remote =
      let dep = {
        Module.Dependency.
        request = from_request;
        requested_from = location
      }
      in
      let m = get_module dep dep_map in
      let () = ensure_export_exists ~dep_map m remote in
      match remote with
      | "default" ->
        let default_var, _ =
          ensure_module_default_var m
        in
        default_var
      | _ ->
        let module_var, _ =
          ensure_module_var "" m
        in
        module_var ^ "." ^ remote
    in

    let define_local_exports ~dep_map exports =
      exports
      |> List.map
        (fun (exported, local) ->
           let local =
             match get_binding local with
             | Some { typ = Scope.Import { source; remote = Some remote}; loc; _ } ->
               patch_imported_name
                 ~dep_map
                 ~from_request:source
                 (loc, local)
                 remote
             | None ->
               failwith ("Cannot export previously undefined name:" ^ local)
             | _ ->
               local
           in
           define_export exported local
        )
      |> String.concat ""
    in

    let define_remote_exports ~dep_map ~request ~from_module exports =
      let module_var, module_var_definition =
        ensure_module_var request from_module
      in
      let exports =
        exports
        |> List.map
          (fun (exported, remote) ->
             let () = ensure_export_exists ~dep_map from_module remote in
             match remote with
             | "default" ->
               let default_var, default_definition =
                 ensure_module_default_var from_module
               in
               default_definition ^ (define_export exported default_var)
             | _ ->
               define_export exported (module_var ^ "." ^ remote)
          )
        |> String.concat ""
      in
      module_var_definition ^ exports
    in

    (* let top_imports = ref [] in *)
    (* let add_top_import stmt = *)
    (*   top_imports := stmt :: !top_imports *)
    (* in *)


    let enter_function {Visit. parents; _} f =
      push_scope (Scope.of_function parents f (top_scope ()))
    in

    let leave_function _ _ =
      pop_scope ()
    in

    let enter_block {Visit. parents; _} block =
      push_scope (Scope.of_block parents block (top_scope ()))
    in

    let leave_block _ _ =
      pop_scope ()
    in

    let enter_statement {Visit. parents; _} stmt =
      push_scope (Scope.of_statement parents stmt (top_scope ()))
    in

    let leave_statement _ _ =
      pop_scope ()
    in


    let visit_statement visit_ctx ((loc: Loc.t), stmt) =
      let action =
        Mode.patch_statement patcher ctx.Context.mode visit_ctx (loc, stmt)
      in
      match action with
      | Visit.Break ->
        Visit.Break
      | Visit.Continue visit_ctx ->
        let _ =
          match stmt with
          | S.ImportDeclaration {
              source = (_, { value = request; _ });
              specifiers;
              default;
              _;
            } ->
            let dep = add_dependency request in
            patch_with 0 0
              (fun (_, dep_map) ->
                 let (m : Module.t) = get_module dep dep_map in
                 let namespace =
                   match specifiers with
                   | Some (S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, name))) ->
                     Some name
                   | _ ->
                     None
                 in
                 let has_names = default <> None || specifiers <> None in
                 let patch =
                   match has_names with
                   (* import 'some'; *)
                   | false ->
                     fastpack_require m.id dep.request ^ ";\n"
                   | true ->
                     let _, module_var_definition =
                       ensure_module_var ~name:namespace dep.request m
                     in
                     let _, module_default_var_definition =
                       match default with
                       | None -> "", ""
                       | Some _ -> ensure_module_default_var m
                     in
                     module_var_definition ^ module_default_var_definition
                 in
                 if patch = "" then "" else (patch ^ "\n")
              );
              remove_loc loc;

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = Some ((stmt_loc, _) as declaration);
              _
            } ->
            let exports =
              Scope.names_of_node declaration
              |> List.map (fun ((_, name), _, _) -> (name, name))
            in
            remove
              loc.start.offset
              (stmt_loc.start.offset - loc.start.offset);
            patch_with loc._end.offset 0
              (fun (_, dep_map) ->
                 ";" ^ (define_local_exports ~dep_map exports)
              )

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
              source = None;
            } ->
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                 specifiers
                 |> export_from_specifiers
                 |> define_local_exports ~dep_map
              )

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                 let m = get_module dep dep_map in
                 specifiers
                 |> export_from_specifiers
                 |> define_remote_exports ~dep_map ~request ~from_module:m
              );

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (
                  S.ExportNamedDeclaration.ExportBatchSpecifier (_, Some (_, spec)));
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                 let m = get_module dep dep_map in
                 let module_var, module_var_definition =
                   ensure_module_var dep.request m
                 in
                 module_var_definition ^ define_export spec module_var
              )

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (
                  S.ExportNamedDeclaration.ExportBatchSpecifier (_, None)
                );
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                 let m = get_module dep dep_map in
                 let module_var, module_var_definition =
                   ensure_module_var dep.request m
                 in
                 let updated_exports =
                   match m.module_type with
                   | Module.CJS
                   | Module.CJS_esModule ->
                     Printf.sprintf
                       "Object.assign(module.exports, __fastpack_require__.omitDefault(%s));"
                       module_var
                   | Module.ESM ->
                     let {ExportFinder. exports; _ } =
                       ctx.export_finder.get_all dep_map m
                     in
                     exports
                     |> M.bindings
                     |> List.filter (fun (name, _) -> name <> "default")
                     |> List.map (fun (name, _) -> (name, module_var ^ "." ^ name))
                     |> List.map (fun (exported, local) -> define_export exported local)
                     |> String.concat ""
                 in
                 module_var_definition ^ "" ^ updated_exports
              )

          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Expression _;
              default;
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  _,
                  S.FunctionDeclaration { id=None; _ }
                );
              default;
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  _,
                  S.ClassDeclaration { id=None; _ }
                );
              default
            } ->
            patch
              loc.start.offset
              (default._end.offset - loc.start.offset)
              "exports.default ="

          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.FunctionDeclaration { id = Some (_, id); _ }
                );
              _
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.ClassDeclaration { id = Some (_, id); _ }
                );
              _
            } ->
            remove
              loc.start.offset
              (expr_loc.start.offset - loc.start.offset);
            patch loc._end.offset 0
              (Printf.sprintf "\nexports.default = %s;\n" id);

          | _ -> ()
        in
        Visit.Continue visit_ctx
    in

    let visit_expression visit_ctx ((loc: Loc.t), expr) =
      let action =
        Mode.patch_expression patcher ctx.Context.mode visit_ctx (loc,expr)
      in
      match action with
      | Visit.Break -> Visit.Break
      | Visit.Continue visit_ctx ->
        match expr with
        | E.Object { properties } ->
          properties
          |> List.iter
            (fun prop ->
               match prop with
               | E.Object.Property (loc, E.Object.Property.Init {
                   key = E.Object.Property.Identifier (_, name) ;
                   shorthand = true;
                   _
                 })  -> patch loc.Loc.start.offset 0 @@ name ^ ": "
               | _ -> ()
            );
          Visit.Continue visit_ctx

        | E.Import (_, E.Literal { value = L.String request; _ }) ->
          let dep = add_dependency request in
          patch_loc_with
            loc
            (fun (_, dep_map) ->
               let {Module. id = module_id; _} = get_module dep dep_map in
               fastpack_import module_id dep.request
            );
          Visit.Break

        | E.Call {
            callee = (_, E.Identifier (_, "require"));
            arguments = [E.Expression (_, E.Literal { value = L.String request; _ })];
            _
          } ->
          if not (has_binding "require") then begin
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                 let {Module. id = module_id; _} = get_module dep dep_map in
                 fastpack_require module_id dep.request
              );
          end;
          Visit.Break

        | E.Identifier (loc, "require") ->
          let () =
            if not (has_binding "require")
            then patch_loc loc "__fastpack_require__"
            else ()
          in
          Visit.Break

        | E.Identifier (loc, name) ->
          let () =
            match get_binding name with
            | Some { typ = Scope.Import { source; remote = Some remote}; _ } ->
              patch_loc_with
                loc
                (fun (_, dep_map) ->
                   patch_imported_name
                     ~dep_map
                     ~from_request:source
                     (loc, name)
                     remote
                )
            | _ -> ()
          in Visit.Break;

        | E.Import _ ->
          let msg = "import(_) is supported only with the constant argument" in
          raise (Context.PackError (ctx, NotImplemented (Some loc, msg)))

        | _ ->
          Visit.Continue visit_ctx;
    in

    let module_type = get_module_type stmts in
    let () =
      if module_type = Module.ESM
      then patch 0 0 "module.exports.__esModule = true;\n"
      else ()
    in

    let handler =
      {
        Visit.default_visit_handler with
        visit_statement;
        visit_expression;
        enter_function;
        leave_function;
        enter_block;
        leave_block;
        enter_statement;
        leave_statement;
      }
    in
    Visit.visit handler program;

    (!workspace, !dependencies, program_scope, exports, module_type)
  in

  (* Gather dependencies *)
  let rec process (ctx : Context.t) graph (m : Module.t) =
    let ctx = { ctx with current_location = m.location } in
    let m, dependencies =
      if m.state <> Module.Analyzed
      then begin
        let source = m.Module.workspace.Workspace.value in
        let (workspace, dependencies, scope, exports, module_type) =
          match is_json m.location with
          | true ->
            let workspace =
              Printf.sprintf "module.exports = %s;" source
              |> Workspace.of_string
            in
            (workspace, [], Scope.empty, Scope.empty_exports, Module.CJS)
          | false ->
            try
              analyze m.id m.location source
            with
            | FlowParser.Parse_error.Error args ->
              let location_str = Module.location_to_string m.location in 
              raise (Context.PackError (ctx, CannotParseFile (location_str, args, source)))
            | Scope.ScopeError reason ->
              raise (Context.PackError (ctx, ScopeError reason))
        in
        { m with workspace; scope; exports; module_type }, dependencies
      end
      else
        m, []
    in
    let%lwt m =
      if m.state <> Module.Analyzed
      then begin
        let%lwt dependencies =
          Lwt_list.map_p
            (fun req ->
               let%lwt resolved, build_dependencies =
                 resolve ctx req
               in
               Lwt.return ((req, resolved), build_dependencies)
            )
            dependencies
        in
        let%lwt resolved_dependencies, build_dependencies =
          Lwt_list.fold_left_s
            (fun (resolved, build) (r, b) ->
               let%lwt build =
                 Lwt_list.fold_left_s
                   (fun build filename ->
                      let%lwt { digest; _ }, _ = cache.get_file filename in
                      Lwt.return (M.add filename digest build)
                   )
                   build
                   b
               in
               Lwt.return (r :: resolved, build)
            )
            ([], m.build_dependencies)
            dependencies
        in
        Lwt.return {
          m with
          resolved_dependencies = List.rev resolved_dependencies;
          build_dependencies
        }
      end
      else
        Lwt.return m
    in
    DependencyGraph.add_module graph m;

    let%lwt () =
      Lwt_list.iter_s
        (fun (req, resolved) ->
           let resolved_str = Module.location_to_string resolved in
           let%lwt dep_module = match DependencyGraph.lookup_module graph resolved_str with
             | None ->
               let ctx = { ctx with stack = req :: ctx.stack } in
               let%lwt m = read_module ~ctx ~cache ~from_module:(Some m) resolved in
               process ctx graph m
             | Some m ->
               Lwt.return m
           in
           DependencyGraph.add_dependency graph m (req, Some dep_module.location);
           Lwt.return_unit
        )
        m.resolved_dependencies
    in
    Lwt.return m
  in

  let {Context. current_location; _ } = ctx in
  let%lwt entry = read_module ~ctx ~cache current_location in
  let%lwt _ = process ctx ctx.graph entry in
  Lwt.return_unit
