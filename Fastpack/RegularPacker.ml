
module MLSet = Module.LocationSet 
module StringSet = Set.Make(String)
module M = Map.Make(String)
module UTF8 = FastpackUtil.UTF8

open PackerUtil

module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit

let debug = Logs.debug

let re_name = Re.Posix.compile_pat "[^A-Za-z0-9_]+"

let pack (cache : Cache.t) (ctx : Context.t) output_channel =

  (* TODO: handle this at a higher level, IllegalConfiguration error *)
  let%lwt () =
    if (ctx.Context.target = Target.ESM)
    then Lwt.fail (PackError (ctx, NotImplemented (
        None, "EcmaScript6 target is not supported "
              ^ "for the regular packer - use flat\n"
      )))
    else Lwt.return_unit
  in

  let modifier s =
    let json = Yojson.to_string (`String s) in
    String.(sub json 1 (length json - 2))
  in

  let analyze _id location source =
    let ((_, stmts, _) as program), _ = Parser.parse_source source in


    let module Ast = FlowParser.Ast in
    let module Loc = FlowParser.Loc in
    let module S = Ast.Statement in
    let module E = Ast.Expression in
    let module L = Ast.Literal in

    let dependencies = ref [] in
    let workspace = ref (Workspace.of_string ~modifier:(Some modifier) source) in
    let ({Workspace.
          patch;
          patch_with;
          patch_loc;
          patch_loc_with;
          remove;
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
        raise (PackError (ctx, CannotResolveModule (dep.request, dep)))
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
    (* let get_module_var (m : Module.t) = *)
    (*   M.get m.id !module_vars *)
    (* in *)
    let ensure_module_var ?(name=None) request (m : Module.t) =
      match M.get m.Module.id !module_vars, name with
      | Some var, None ->
        var, ""
      | Some var, Some name ->
        if var = name
        then var, ""
        else var, define_var name var
      | None, Some name ->
        module_vars := M.add m.Module.id name !module_vars;
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
    (* let get_module_default_var (m : Module.t) = *)
    (*   M.get m.id !module_default_vars *)
    (* in *)

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
          Module.location_to_string ~base_dir:(Some ctx.project_dir) m.location
        in
        raise (PackError (ctx, CannotFindExportedName (name, location_str)))
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
        "Object.defineProperty(exports, \"%s\", {get: function() {return %s;}});"
        exported
        local
    in

    let patch_imported_name ~dep_map ~from_request (loc, local_name) remote =
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
        let default_var, default_definition =
          ensure_module_default_var m
        in
        if default_definition <> ""
        then raise (PackError(ctx, CannotRenameModuleBinding (loc, local_name, dep)))
        else default_var
      | _ ->
        let module_var, module_var_definition =
          ensure_module_var "" m
        in
        if module_var_definition <> ""
        then raise (PackError(ctx, CannotRenameModuleBinding (loc, local_name, dep)))
        else module_var ^ "." ^ remote
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
            patch_loc_with
              loc
              (fun (_, dep_map) ->
                let (m : Module.t) = get_module dep dep_map
                in
                let namespace, _names =
                  match specifiers with
                  | Some (S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, name))) ->
                    Some name, []
                  | Some (S.ImportDeclaration.ImportNamedSpecifiers specifiers) ->
                    None,
                    specifiers
                    |> List.map
                      (fun {S.ImportDeclaration. remote = (_, remote); _ } -> remote)
                  | None ->
                    None, []
                in
                let has_names = default <> None || specifiers <> None in
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
              );

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
          if (not @@ has_binding "require") then begin
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
            if (not @@ has_binding "require")
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
          raise (PackError (ctx, NotImplemented (Some loc, msg)))

        | _ ->
          Visit.Continue visit_ctx;
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
    let module_type = get_module_type stmts in
    let () =
      if module_type = Module.ESM
      then patch 0 0 "module.exports.__esModule = true;\n"
      else ()
    in

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
              |> Workspace.of_string ~modifier:(Some modifier)
            in
            (workspace, [], Scope.empty, Scope.empty_exports, Module.CJS)
          | false ->
            try
                analyze m.id m.location source
            with
            | FlowParser.Parse_error.Error args ->
              let location_str = Module.location_to_string m.location in
              raise (PackError (ctx, CannotParseFile (location_str, args)))
            | Scope.ScopeError reason ->
              raise (PackError (ctx, ScopeError reason))
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
                 resolve ctx m.package req
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

  (* emit required runtime *)
  let emit_runtime out prefix entry_id =
    Lwt_io.write out
    @@ Printf.sprintf
"
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
%s(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(moduleId) {

    // Check if module is in cache
    if(installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    // Create a new module (and put it into the cache)
    var module = installedModules[moduleId] = {
      id: moduleId,
      l: false,
      exports: {}
    };

    // Execute the module function
    modules[moduleId].call(
      module.exports,
      module,
      module.exports,
      __fastpack_require__,
      __fastpack_import__
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(moduleId) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(moduleId));
      } catch (e) {
        reject(e);
      }
    });
  }

  __fastpack_require__.m = modules;
  __fastpack_require__.c = installedModules;
  __fastpack_require__.omitDefault = function(moduleVar) {
    var keys = Object.keys(moduleVar);
    var ret = {};
    for(var i = 0, l = keys.length; i < l; i++) {
      var key = keys[i];
      if (key !== 'default') {
        ret[key] = moduleVar[key];
      }
    }
    return ret;
  }
  return __fastpack_require__(__fastpack_require__.s = '%s');
})
" prefix entry_id
  in

  let emitted_modules = ref (MLSet.empty) in
  let emit graph entry =
    let emit bytes = Lwt_io.write output_channel bytes in
    let rec emit_module (m : Module.t) =
      if MLSet.mem m.location !emitted_modules
      then Lwt.return_unit
      else begin
        emitted_modules := MLSet.add m.location !emitted_modules;
        let%lwt () = emit_module_files ctx m in
        let workspace = m.Module.workspace in
        let dep_map = Module.DependencyMap.empty in
        let dependencies = DependencyGraph.lookup_dependencies graph m in
        let%lwt dep_map =
          Lwt_list.fold_left_s
            (fun dep_map (dep, m) ->
               match m with
               | None ->
                 Lwt.return dep_map
               | Some m ->
                 let%lwt () = emit_module m in
                 let dep_map = Module.DependencyMap.add dep m dep_map in
                 Lwt.return dep_map
            )
            dep_map
            dependencies
        in
        let%lwt () =
          m.id
          |> Printf.sprintf "\"%s\": function(module, exports, __fastpack_require__, __fastpack_import__) {\n"
          |> emit
        in
        let%lwt () = emit "eval(\"" in
        let%lwt content =
          Workspace.write
            ~output_channel
            ~workspace
            ~ctx:(m, dep_map) in
        let%lwt () =
          Module.location_to_string ~base_dir:(Some ctx.project_dir) m.location
          |> Printf.sprintf "\\n//# sourceURL=fpack:///%s\");"
          |> emit
        in
        let m = { m with state = Module.Analyzed } in
        let () =
          match m.location with
          | Module.File _ ->
            cache.modify_content m content
          | _ ->
            ()
        in
        let () =
          match m.workspace.Workspace.modifier with
          | None -> ()
          | Some _ ->
            DependencyGraph.add_module
              graph
              { m with workspace = Workspace.of_string content }
        in
        let%lwt () = emit "\n},\n" in
        Lwt.return_unit
      end
    in

    let export =
      match ctx.target with
      | Target.CommonJS ->
        "module.exports = "
      | _ ->
        ""
    in

    let%lwt () = emit_runtime output_channel export entry.Module.id in
    let%lwt () = emit "({\n" in
    let%lwt _ = emit_module entry in
    let%lwt () = emit "\n});\n" in
    Lwt.return_unit
  in

  let {Context. entry_location; current_location; _ } = ctx in
  let%lwt entry = read_module ~ctx ~cache current_location in
  let%lwt _ = process ctx ctx.graph entry in
  let entry_location_str = Module.location_to_string entry_location in
  let global_entry =
    match DependencyGraph.lookup_module ctx.graph entry_location_str with
    | Some m -> m
    | None -> Error.ie (entry_location_str ^ " not found in the graph")
  in
  let%lwt _ = emit ctx.graph global_entry in
  let emitted_modules =
    Module.LocationSet.fold
      (fun location acc ->
        StringSet.add (Module.location_to_string location) acc
      )
      !emitted_modules
      StringSet.empty
  in

  Lwt.return {
    Reporter.
    graph = DependencyGraph.cleanup ctx.graph emitted_modules;
    size = Lwt_io.position output_channel |> Int64.to_int
  }
