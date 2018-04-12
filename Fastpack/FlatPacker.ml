open PackerUtil

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal
module P = Ast.Pattern

module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit
module UTF8 = FastpackUtil.UTF8
module FS = FastpackUtil.FS

module StringSet = Set.Make(String)
module M = Map.Make(String)
module DM = Map.Make(Module.Dependency)
module MDM = Module.DependencyMap

let debug = Logs.debug

type binding_type = Collision

let pack (cache : Cache.t) (ctx : Context.t) result_channel =

  let read_module = read_module ~ctx ~cache in

  let bytes = Lwt_bytes.create 50_000_000 in
  let channel = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
  let total_modules = ref (StringSet.empty) in
  let has_dynamic_modules = ref false in

  (* internal top-level bindings in the file *)
  let gen_int_binding module_id name =
    Printf.sprintf "$i__%s__%s" module_id name
  in

  let gen_ext_binding module_id name =
    Printf.sprintf "$e__%s__%s" module_id name
  in

  let gen_ext_namespace_binding module_id =
    Printf.sprintf "$n__%s" module_id
  in

  let gen_wrapper_binding location =
    let module_id = Module.make_id ctx.project_dir location in
    Printf.sprintf "$w__%s" module_id
  in

  (* potential collisions, never appear on the top-level
   * It should be safe to move this generator into the `analyze` function
   * since these names are always scoped
   * *)
  let gen_collision_binding module_id name =
    Printf.sprintf "$c__%s__%s" module_id name
  in

  let may_collide name =
    Str.string_match (Str.regexp "^\\$[iewcn]__") name 0
  in

  let rec pack ?(with_wrapper=false) (ctx : Context.t) entry_location modules =

    debug (fun m -> m "Packing: %s" (Module.location_to_string entry_location));

    let module_processed =
      modules
      |> MDM.bindings
      |> List.filter_map
          (fun (_, m) ->
            if m.Module.location = entry_location then Some m else None
          )
    in

    match with_wrapper, module_processed with
    | true, m :: _ ->
      let wrapper =
        Printf.sprintf
          "function %s() {return %s.exports;}\n"
          (gen_wrapper_binding entry_location)
          (gen_ext_namespace_binding m.Module.id)
      in
      Lwt_io.write channel wrapper

    | _ ->
      let resolved_requests = ref DM.empty in
      let add_resolved_request req resolved =
        resolved_requests := DM.add req resolved !resolved_requests
      in
      let get_resolved_request req =
        DM.get req !resolved_requests
      in

      let has_module location =
        modules
        |> MDM.bindings
        |> List.exists (fun (_, m) -> m.Module.location = location)
      in

      let get_module location =
        let matching =
          modules
          |> MDM.bindings
          |> List.filter (fun (_, m) -> m.Module.location = location)
        in
        match matching with
        | [] -> None
        | (_, m) :: _ -> Some m
      in

      let name_of_binding ?(typ=None) module_id name (binding : Scope.binding) =
        match typ with
        | Some Collision -> gen_collision_binding module_id name
        | None ->
          match binding.exported with
          | Some exported ->
            begin
              match exported, binding.typ with
              | (["default"], Scope.Function) when name <> "default" ->
                gen_int_binding module_id name
              | _ ->
                gen_ext_binding module_id @@ String.concat "_" exported
            end
          | None -> gen_int_binding module_id name
      in

      (* Keep track of all dynamic dependencies while packing *)
      let dynamic_deps = ref [] in
      let add_dynamic_dep ctx m request location =
        let dep = {
          Module.Dependency.
          request;
          requested_from = location
        }
        in
        let () = dynamic_deps := (ctx, m, dep) :: !dynamic_deps in
        let () = has_dynamic_modules := true in
        dep
      in

      let rec process (ctx : Context.t) graph (m : Module.t) =

        let ctx = { ctx with current_location = Some m.location } in

        let analyze module_id location source =
          debug (fun m -> m "Analyzing: %s" (Module.location_to_string location));

          let ((_, stmts, _) as program), _ = Parser.parse_source source in

          let workspace = ref (Workspace.of_string source) in
          let ({ Workspace.
                patch;
                sub_loc;
                patch_loc;
                patch_with;
                patch_loc_with;
                remove_loc;
                remove;
                _
              } as patcher) = Workspace.make_patcher workspace
          in

          let patch_binding ?(typ=None) name (binding : Scope.binding) =
            patch_loc binding.loc @@ name_of_binding ~typ module_id name binding;
            if binding.shorthand
            then patch binding.loc.start.offset 0 @@ name ^ ": "
          in

          let program_scope, exports = Scope.of_program stmts in
          (* always add the namespace binding *)
          patch 0 0
          @@ Printf.sprintf "let %s = { id: \"%s\", exports: {}};\n"
            (gen_ext_namespace_binding module_id)
            module_id;

          let () =
            Scope.iter
              (fun (name, binding) ->
                match binding.typ with
                | Scope.Import _ -> ()
                | _ -> patch_binding name binding

              )
              program_scope
          in

          let patch_namespace ?(add_exports=false) loc =
            let patch_content =
              gen_ext_namespace_binding module_id
              ^ (if add_exports then ".exports" else "")
            in
            patch_loc loc patch_content;
          in

          let rec resolve_import dep_map location source remote =
            let dep = {
              Module.Dependency.
              request = source;
              requested_from = location
            }
            in
            let m = MDM.get dep dep_map in
            match m with
            | None ->
              raise (PackError (ctx, CannotResolveModule (dep.request, dep)))
            | Some m ->
              match remote with
              | None ->
                Printf.sprintf "%s.exports"
                @@ gen_ext_namespace_binding m.Module.id
              | Some remote ->
                match Module.(m.module_type = ESM || m.module_type = CJS_esModule), remote with
                | false, "default" ->
                  Printf.sprintf "%s.exports"
                  @@ gen_ext_namespace_binding m.Module.id
                | false, remote ->
                  Printf.sprintf
                    "%s.exports.%s"
                    (gen_ext_namespace_binding m.Module.id)
                    remote
                | true, remote ->
                  (* TODO: this doesn't take into account batch re-exports *)
                  match M.get remote m.exports.Scope.names with
                  | None ->
                    if m.module_type = Module.ESM
                    then
                      let location_str =
                        Module.location_to_string
                          ~base_dir:(Some ctx.project_dir)
                          m.location
                      in
                      raise (PackError (ctx, CannotFindExportedName (remote, location_str)))
                    else
                      Printf.sprintf "%s.exports.%s"
                        (gen_ext_namespace_binding m.id)
                        remote
                  | Some export ->
                    match export with
                    | Scope.Default ->
                      gen_ext_binding m.id "default"
                    | Scope.Own (_, {typ = Scope.Import {source; remote}; _})
                    | Scope.ReExport {Scope. remote;  source} ->
                      resolve_import dep_map m.location source remote
                    | Scope.Own (_, binding) ->
                      name_of_binding m.id remote binding
                    | Scope.ReExportNamespace _ ->
                      failwith "not impl"
          in

          let add_exports es_module =
            let namespace = gen_ext_namespace_binding module_id in
            patch_with (UTF8.length source) 0
              (fun (_, dep_map) ->
                let expr =
                  exports.names
                  |> M.bindings
                  |> List.map
                    (fun (exported_name, export) ->
                       let value =
                         match export with
                         | Scope.Default ->
                           gen_ext_binding module_id "default"
                         | Scope.ReExport {Scope. remote; source}
                         | Scope.Own (_, {typ = Scope.Import { source; remote }; _}) ->
                           resolve_import dep_map m.location source remote
                         | Scope.Own (internal_name, binding) ->
                           name_of_binding module_id internal_name binding
                         | Scope.ReExportNamespace _ ->
                           failwith "not impl"
                       in
                       Printf.sprintf "%s.exports.%s = %s;\n" namespace exported_name value
                    )
                  |> String.concat ""
                in
                Printf.sprintf
                  "\ntry{%s%s.exports.__esModule = %s.exports.__esModule || %s;}catch(_){}\n"
                  expr
                  namespace
                  namespace
                  (if es_module then "true" else "false")
              )
          in

          let add_target_export () =
            patch_with (UTF8.length source) 0
              (fun (_, dep_map) ->
                match ctx.target with
                | Target.Application ->
                  ""
                | Target.ESM ->
                  exports.names
                  |> M.bindings
                  |> List.map
                    (fun (exported_name, export) ->
                       let value =
                         match export with
                         | Scope.Default ->
                           gen_ext_binding module_id "default"
                         | Scope.ReExport {Scope. remote; source}
                         | Scope.Own (_, {typ = Scope.Import { source; remote }; _}) ->
                           resolve_import dep_map m.location source remote
                         | Scope.Own (internal_name, binding) ->
                           name_of_binding module_id internal_name binding
                         | Scope.ReExportNamespace _ ->
                           failwith "not impl"
                       in
                       if exported_name = "default"
                       then Printf.sprintf "export default %s;\n" value
                       else Printf.sprintf "export {%s as %s};\n" value exported_name
                    )
                  |> String.concat ""
                | Target.CommonJS ->
                  Printf.sprintf "module.exports = %s.exports;\n"
                  @@ gen_ext_namespace_binding module_id
              )
          in

          (* Static dependencies *)
          let static_deps = ref [] in
          let add_static_dep request =
            let dep = {
              Module.Dependency.
              request;
              requested_from = location
            }
            in
            begin
              static_deps := dep :: !static_deps;
              dep
            end
          in

          let used_imports = ref (
            Scope.fold_left
              (fun used_imports (name, binding) ->
                 match binding.typ with
                 | Scope.Import { source; _ } ->
                   M.add name (source, false) used_imports
                 | _
                   ->
                   used_imports
              )
              M.empty
              program_scope
          ) in
          let use_name name =
            match M.get name !used_imports with
            | Some (source, _) ->
              used_imports := M.add name (source, true) !used_imports;
            | None ->
              ()
          in

          let scopes = ref [program_scope] in
          let collisions = ref [M.empty] in
          let top_scope () = List.hd !scopes in
          let top_collisions () = List.hd !collisions in

          let push_scope scope =
            let scope_collisions =
              Scope.fold_left
                (fun acc (name, binding) ->
                  let update_acc () =
                    let () = patch_binding ~typ:(Some Collision) name binding in
                    M.add name binding acc
                  in
                  if may_collide name
                  then begin
                    match M.get name acc with
                    | None ->
                      update_acc ()
                    | Some prev_binding when prev_binding.loc <> binding.loc ->
                      update_acc ()
                    | _ ->
                      acc
                  end
                  else
                    acc
                )
                (top_collisions ())
                scope
            in
            begin
              (* let () = print_col (top_collisions ()) in *)
              (* let () = print_col scope_collisions in *)
              collisions := scope_collisions :: !collisions;
              scopes := scope :: !scopes;
            end;
          in
          let pop_scope () =
            collisions := List.tl !collisions;
            scopes := List.tl !scopes;
          in

          let get_top_level_binding name =
            let binding = Scope.get_binding name (top_scope ()) in
            match binding with
            | None -> None
            | Some b ->
              let top_level_binding = Scope.get_binding name program_scope in
              match top_level_binding with
              | Some top_level -> if b == top_level then Some b else None
              | None -> None
          in

          let patch_identifier (loc, name) =
            match get_top_level_binding name with
            | Some binding ->
              use_name name;
              patch_loc_with
                loc
                (fun (_, dep_map) ->
                   match binding.typ with
                   | Scope.Import { source; remote } ->
                     resolve_import dep_map location source remote
                   | _ ->
                     name_of_binding module_id name binding
                )
            | None ->
              match M.get name (top_collisions ()) with
              | Some binding ->
                patch_loc loc
                @@ name_of_binding ~typ:(Some Collision) module_id name binding
              | None -> ()
          in

          let rec patch_pattern (_, node) =
            match node with
            | P.Object { properties; _ } ->
              let on_property = function
                | P.Object.Property (loc, { pattern; shorthand; _ }) ->
                  if shorthand
                  then patch loc.Loc.start.offset 0 @@ sub_loc loc ^ ": ";
                  patch_pattern pattern
                | P.Object.RestProperty (_,{ argument }) ->
                  patch_pattern argument
              in
              List.iter on_property properties
            | P.Array { elements; _ } ->
              let on_element = function
                | None ->
                  ()
                | Some (P.Array.Element node) ->
                  patch_pattern node
                | Some (P.Array.RestElement (_, { argument })) ->
                  patch_pattern argument
              in
              List.iter on_element elements
            | P.Assignment { left; _ } ->
              patch_pattern left
            | P.Identifier { name; _ } ->
              patch_identifier name
            | P.Expression _ ->
              ()
          in

          let patch_dynamic_dep loc dep require =
            patch_loc_with
              loc
              (fun _ ->
                 match get_resolved_request dep with
                 | None ->
                   Error.ie "At this point dependency should be resolved"
                 | Some Module.EmptyModule
                 | Some Module.Runtime ->
                   Error.ie "Unexpected module for the dynamic dependency"
                 | Some location ->
                   let wrapper = gen_wrapper_binding location in
                   Printf.sprintf "%s(%s)" require wrapper
              )
          in

          (* Level of statement *)
          let stmt_level = ref 0 in

          let enter_function { Visit. parents; _ } f =
            push_scope (Scope.of_function parents f (top_scope ()))
          in

          let leave_function _ _ =
            pop_scope ()
          in

          let enter_block { Visit. parents; _ } block =
            push_scope (Scope.of_block parents block (top_scope ()))
          in

          let leave_block _ _ =
            pop_scope ()
          in

          let enter_statement { Visit. parents; _ } (loc, stmt) =
            let () =
              push_scope (Scope.of_statement parents (loc, stmt) (top_scope ()))
            in
            match stmt, !stmt_level with
            | S.Block _, 0 -> ()
            | _ -> stmt_level := !stmt_level + 1;
          in

          let leave_statement _ (_, stmt) =
            let () = pop_scope () in
            match stmt, !stmt_level with
            | S.Block _, 0 -> ()
            | _ -> stmt_level := !stmt_level - 1;
          in

          let visit_statement visit_ctx (loc, stmt) =
            let action =
              Mode.patch_statement patcher ctx.Context.mode visit_ctx (loc, stmt)
            in
            match action with
            | Visit.Break ->
              Visit.Break
            | Visit.Continue visit_ctx ->
              match stmt with
              | S.ImportDeclaration {
                  source = (_, { value = request; _ });
                  specifiers = None;
                  default = None;
                _
                } ->
                let _ = add_static_dep request in
                remove_loc loc;
                Visit.Continue visit_ctx;

              | S.ImportDeclaration _ ->
                remove_loc loc;
                Visit.Continue visit_ctx;

              | S.ExportNamedDeclaration { source = Some (_, { value; _ }); _} ->
                let _ = add_static_dep value in
                remove_loc loc;
                Visit.Break;

              | S.ExportNamedDeclaration {
                  specifiers = Some S.ExportNamedDeclaration.ExportSpecifiers specifiers;
                  _ } ->
                List.iter
                  (fun (_, {
                       S.ExportNamedDeclaration.ExportSpecifier.
                       local = (_, local); _
                     }) ->
                     use_name local;
                  )
                  specifiers;
                remove_loc loc;
                Visit.Break;

              | S.ExportNamedDeclaration {
                  specifiers =
                    Some S.ExportNamedDeclaration.ExportBatchSpecifier _;
                  _ } ->
                remove_loc loc;
                Visit.Break;

              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Declaration (
                      expr_loc,
                      S.FunctionDeclaration { id = Some (_, name); _ }
                  );
                  _
                } ->
                (* TODO: check named class as well *)
                remove
                  loc.Loc.start.offset
                  (expr_loc.Loc.start.offset - loc.Loc.start.offset);
                patch loc.Loc._end.offset 0
                @@ Printf.sprintf ";const %s = %s;"
                    (gen_ext_binding module_id "default")
                    (gen_int_binding module_id name);
                Visit.Continue visit_ctx;

              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Declaration (
                      expr_loc,
                      S.FunctionDeclaration _
                  );
                  _
                }
              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Declaration (
                      expr_loc,
                      S.ClassDeclaration _
                  );
                  _
                }
              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Expression (expr_loc, _);
                  _ } ->
                patch
                  loc.Loc.start.offset
                  (expr_loc.Loc.start.offset - loc.Loc.start.offset)
                @@ Printf.sprintf "const %s = "
                @@ gen_ext_binding module_id "default";
                Visit.Continue visit_ctx

              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Declaration (stmt_loc, _);
                  _ }
              | S.ExportNamedDeclaration { declaration = Some (stmt_loc, _); _ } ->
                remove
                  loc.Loc.start.offset
                  (stmt_loc.Loc.start.offset - loc.Loc.start.offset);
                Visit.Continue visit_ctx;


              | S.ForIn {left = S.ForIn.LeftPattern pattern; _}
              | S.ForOf {left = S.ForOf.LeftPattern pattern; _} ->
                patch_pattern pattern;
                Visit.Continue visit_ctx

              | _ ->
                Visit.Continue visit_ctx
          in

          let visit_expression visit_ctx (loc, expr) =
            let action =
              Mode.patch_expression patcher ctx.Context.mode visit_ctx (loc,expr)
            in
            match action with
            | Visit.Break -> Visit.Break
            | Visit.Continue visit_ctx ->
              match expr with
              (* patch shorthands, since we will be doing renaming *)
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

              (* static imports *)
              | E.Call {
                  callee = (_, E.Identifier (_, "require"));
                  arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
                } ->
                  if (not @@ Scope.has_binding "require" (top_scope ()))
                  then begin
                    let dep = add_static_dep request in
                    patch_loc_with loc
                      (fun (_, dep_map) ->
                         match MDM.get dep dep_map with
                         | None ->
                           raise (PackError (ctx, CannotResolveModule (dep.request, dep)))
                         | Some m ->
                           Printf.sprintf "(%s.exports)" @@ gen_ext_namespace_binding m.id
                      );
                  end;
                  Visit.Break;

              | E.Import (_, E.Literal { value = L.String request; _ }) ->
                let dep = add_dynamic_dep ctx m request location in
                patch_dynamic_dep loc dep "__fastpack_import__";
                Visit.Break;

              | E.Import _ ->
                let msg =
                  "import(_) is supported only with the constant argument"
                in
                raise (PackError (ctx, NotImplemented (Some loc, msg)))

              (* replace identifiers *)
              | E.Identifier ((loc, name) as id) ->
                let () =
                  match name with
                  | "module"
                    when not (Scope.has_binding "module" @@ top_scope ()) ->
                    patch_namespace loc
                  | "exports"
                    when not (Scope.has_binding "exports" @@ top_scope ()) ->
                    patch_namespace ~add_exports:true loc
                  | _ ->
                    patch_identifier id
                in
                Visit.Break;

              | E.Assignment { left; _ } ->
                patch_pattern left;
                Visit.Continue visit_ctx

              | _ ->
                Visit.Continue visit_ctx;
          in

          let handler = {
            Visit.default_visit_handler with
            visit_statement;
            visit_expression;
            enter_statement;
            leave_statement;
            enter_function;
            leave_function;
            enter_block;
            leave_block;
          } in
          let module_type = get_module_type stmts in
          Visit.visit handler program;
          add_exports (module_type = Module.ESM || module_type = Module.CJS_esModule);
          if (Some location = ctx.entry_location) then add_target_export ();

          !used_imports
          |> M.bindings
          |> List.filter_map
            (fun (_, (source, used)) -> if used then Some source else None)
          |> List.iter (fun source -> let _ = add_static_dep source in ());


          (!workspace,
           !static_deps,
           program_scope,
           exports,
           module_type)
        in

        let source = m.Module.workspace.Workspace.value in
        let (workspace, static_deps, scope, exports, module_type) =
          match is_json m.location with
          | true ->
            let workspace =
              Workspace.of_string
              @@ Printf.sprintf "const %s = %s;"
                (gen_ext_namespace_binding m.id)
                source
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
        let m = {
          m with
          workspace;
          scope;
          exports;
          module_type;
        } in
        DependencyGraph.add_module graph m;

        (* check all static dependecies *)
        let%lwt () = Lwt_list.iter_s
          (fun req ->
            let%lwt resolved, _ = resolve ctx m.package req in
            if has_module resolved
            then begin
              let () = add_resolved_request req resolved in
              Lwt.return_unit
            end
            else begin
              let resolved_str = Module.location_to_string resolved in
              let%lwt dep_module =
                match DependencyGraph.lookup_module graph resolved_str with
                | None ->
                  let%lwt m = read_module ~from_module:(Some m) resolved in
                  let%lwt m =
                    process { ctx with stack = req :: ctx.stack } graph m
                  in
                  begin
                    let () = add_resolved_request req resolved in
                    Lwt.return m
                  end
                | Some m ->
                  let () = add_resolved_request req resolved in
                  Lwt.return m
              in
              let () =
                DependencyGraph.add_dependency graph m (req, Some dep_module.location)
              in
              Lwt.return_unit
            end
          )
          static_deps
        in
        Lwt.return m
      in

      let emit graph entry =
        let emit bytes = Lwt_io.write channel bytes in
        let emit_module dep_map (m : Module.t) =
          debug (fun m_ -> m_ "Emitting: %s" (Module.location_to_string m.location));
          let%lwt () = emit_module_files ctx m in
          let%lwt () = emit (Printf.sprintf "\n/* %s */\n\n" m.id) in
          let%lwt _ = Workspace.write channel m.Module.workspace (m, dep_map) in
          Lwt.return_unit
        in

        let emit_wrapper_start, emit_wrapper_end =
          if with_wrapper then
            (fun () ->
               emit @@ "\nfunction " ^ gen_wrapper_binding entry.Module.location ^ "() {\n"
            ),
            (fun () ->
               emit
               @@ Printf.sprintf "\nreturn %s.exports;\n}\n"
               @@ gen_ext_namespace_binding entry.Module.id
            )
          else
            (fun () -> emit ""), (fun () -> emit "")
        in

        let%lwt () = emit_wrapper_start () in
        let%lwt modules =
          let sorted =
            try
              DependencyGraph.sort graph entry
            with
            | DependencyGraph.Cycle filenames ->
              raise (PackError (ctx, DependencyCycle filenames))
          in
          sorted
          |> Lwt_list.fold_left_s
            (fun dependency_map m ->
              let%lwt () = emit_module dependency_map m in
              !resolved_requests
              |> DM.bindings
              |> List.filter (fun (_, value) -> value = m.location)
              |> List.fold_left (fun acc (k, _) -> MDM.add k m acc) dependency_map
              |> Lwt.return
            )
            (!resolved_requests
             |> DM.bindings
             |> List.filter
               (fun (_, resolved) ->
                  let resolved_str = Module.location_to_string resolved in
                  if has_module resolved
                  then true
                  else
                    match DependencyGraph.lookup_module graph resolved_str with
                    | Some m ->
                      Module.(m.module_type = ESM || m.module_type = CJS_esModule)
                    | None -> false
               )
             |> List.fold_left
               (fun modules (dep, resolved) ->
                  let resolved_str = Module.location_to_string resolved in
                  match get_module resolved with
                  | Some m -> MDM.add dep m modules
                  | None ->
                    match DependencyGraph.lookup_module graph resolved_str with
                    | Some m -> MDM.add dep m modules
                    | None ->
                      Error.ie ("Module should be found. See previous step: "
                                ^ resolved_str)
               )
              modules
            )
        in
        let%lwt () = emit_wrapper_end () in
        Lwt.return modules
      in

      let graph = DependencyGraph.empty () in
      let%lwt entry = read_module entry_location in
      let%lwt entry = process ctx graph entry in
      let%lwt dynamic_deps =
        Lwt_list.map_s
          (fun (ctx, m, req) ->
             let%lwt resolved, _ = resolve ctx m.Module.package req in
             add_resolved_request req resolved;
             Lwt.return (ctx, resolved)
          )
          !dynamic_deps
      in
      let%lwt modules = emit graph entry in
      let%lwt _ =
        Lwt_list.fold_left_s
          (fun seen (ctx, resolved) ->
             match resolved with
             | Module.Runtime
             | Module.EmptyModule ->
               Error.ie ("Unexpected dynamic dependency")
             | location ->
               let location_str = Module.location_to_string location in
               if StringSet.mem location_str seen
               then Lwt.return seen
               else
                 let%lwt () =
                   pack
                    ~with_wrapper:true
                    ctx
                    location
                    modules
                 in
                 Lwt.return (StringSet.add location_str seen)

          )
          StringSet.empty
          dynamic_deps
        in
        let new_modules =
          graph
          |> DependencyGraph.get_modules
        in
        total_modules := StringSet.(of_list new_modules |> union !total_modules);
        Lwt.return_unit
  in
  match ctx.entry_location with
  | Some entry_location ->
    let%lwt () = pack ctx entry_location MDM.empty in

    let bundle = channel
      |> Lwt_io.position
      |> Int64.to_int
      |> Lwt_bytes.extract bytes 0
      |> Lwt_bytes.to_string
    in

    let header, footer = (
      match ctx.target with
      | Target.Application -> "(function() {\n", "})()\n"
      | Target.CommonJS -> "", ""
      | Target.ESM -> "", ""
    )
    in
    let dynamic_import_runtime = (if !has_dynamic_modules then
"var __fastpack_cache__ = {};

function __fastpack_import__(f) {
  if (!window.Promise) {
    throw 'window.Promise is undefined, consider using a polyfill';
  }
  return new Promise(function(resolve, reject) {
    try {
      if (__fastpack_cache__[f.name] === undefined) {
        __fastpack_cache__[f.name] = f();
      }
      resolve(__fastpack_cache__[f.name]);
    } catch (e) {
      reject(e);
    }
  });
}
"
      else "")
    in

    let%lwt () = Lwt_io.write result_channel header in
    let%lwt () = Lwt_io.write result_channel dynamic_import_runtime in
    let%lwt () = Lwt_io.write result_channel bundle in
    let%lwt () = Lwt_io.write result_channel footer in
    Lwt.return {
      Reporter.
      modules = !total_modules;
      size = Lwt_io.position result_channel |> Int64.to_int
    }
  | _ ->
    Error.ie "Entry location should be resolved at this point"
