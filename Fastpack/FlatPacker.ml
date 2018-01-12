open PackerUtil
open Lwt.Infix

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal
module P = Ast.Pattern

module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit

module StringSet = Set.Make(String)
module M = Map.Make(String)
module DM = Map.Make(Dependency)
module MDM = Module.DependencyMap

let debug = Logs.debug

type binding_type = Collision

let pack ?(cache=Cache.fake) (ctx : Context.t) channel =

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

  let gen_wrapper_binding filename =
    let module_id = relative_name ctx filename |> Module.make_id in
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

  let rec pack ?(with_wrapper=false) (ctx : Context.t) modules =

    let () = debug (fun m -> m "Packing: %s" ctx.entry_filename) in

    let module_processed =
      modules
      |> MDM.bindings
      |> List.filter_map
          (fun (_, m) ->
            if m.Module.filename = ctx.entry_filename then Some m else None
          )
    in

    match with_wrapper, module_processed with
    | true, m :: _ ->
      let wrapper =
        Printf.sprintf
          "function %s() {return %s;}\n"
          (gen_wrapper_binding ctx.entry_filename)
          (gen_ext_namespace_binding m.Module.id)
      in
      Lwt_io.write channel wrapper

    | _ ->
      let resolved_requests = ref DM.empty in
      let add_resolved_request req filename =
        resolved_requests := DM.add req filename !resolved_requests
      in
      let get_resolved_request req =
        DM.get req !resolved_requests
      in

      let has_module filename =
        modules
        |> MDM.bindings
        |> List.exists (fun (_, m) -> m.Module.filename = filename)
      in

      let get_module filename =
        let matching =
          modules
          |> MDM.bindings
          |> List.filter (fun (_, m) -> m.Module.filename = filename)
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
          | Some exported -> gen_ext_binding module_id exported
          | None -> gen_int_binding module_id name
      in

      (* Keep track of all dynamic dependencies while packing *)
      let dynamic_deps = ref [] in
      let add_dynamic_dep ctx request filename =
        let dep = {
          Dependency.
          request;
          requested_from_filename = filename;
        } in
        let () = dynamic_deps := (ctx, dep) :: !dynamic_deps in
        dep
      in

      let rec process ({Context. transpile; _} as ctx) graph (m : Module.t) =

        let analyze module_id filename source =
          debug (fun m -> m "Analyzing: %s" filename);

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

          let program_scope = Scope.of_program stmts Scope.empty in
          let () =
            Scope.iter
              (fun (name, binding) ->
                match binding.typ with
                | Scope.Import _ -> ()
                | _ -> patch_binding name binding

              )
              program_scope
          in

          let has_namespace_binding = ref false in
          let patch_namespace loc =
            patch_loc loc @@ gen_ext_namespace_binding module_id;
            if (not !has_namespace_binding) then begin
              patch 0 0
              @@ Printf.sprintf "let %s;"
              @@ gen_ext_namespace_binding module_id;
              has_namespace_binding := true;
            end
          in

          let add_namespace_binding () =
            patch_with (String.length source) 0
              (fun _ ->
                let expr =
                  Scope.get_exports program_scope
                  |> List.map
                    (fun (exported_name, internal_name, binding) ->
                       match internal_name with
                       | Some internal_name ->
                         Printf.sprintf "%s: %s" exported_name
                         @@ name_of_binding module_id internal_name binding
                       | None ->
                         Printf.sprintf "default: %s"
                         @@ gen_ext_binding module_id "default"
                    )
                  |> String.concat ", "
                  |> Printf.sprintf "{%s}"
                in
                Printf.sprintf "\nconst %s = %s;\n"
                  (gen_ext_namespace_binding module_id)
                  expr
              )
          in

          (* Static dependencies *)
          let static_deps = ref [] in
          let add_static_dep request =
            let dep = {
              Dependency.
              request;
              requested_from_filename = filename;
            } in
            begin
              static_deps := dep :: !static_deps;
              dep
            end
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

          let rec resolve_import dep_map filename {Scope. source; remote } =
            let dep = {
              Dependency.
              request = source;
              requested_from_filename = filename
            }
            in
            let m = MDM.get dep dep_map in
            match m with
            | None ->
              failwith ("Cannot find module: " ^ source ^ " from " ^ filename)
            | Some m ->
              match remote with
              | None ->
                gen_ext_namespace_binding m.Module.id
              | Some remote ->
                match m.Module.es_module, remote with
                | false, "default" ->
                  gen_ext_namespace_binding m.Module.id
                | false, remote ->
                  Printf.sprintf
                    "%s.%s"
                    (gen_ext_namespace_binding m.Module.id)
                    remote
                | true, remote ->
                  let names =
                    Scope.get_exports m.scope
                    |> List.filter
                      (fun (name, _, _) -> name = remote)
                  in
                  match names with
                  | [] ->
                    failwith ("Cannot find name " ^ remote ^ " in module " ^ m.Module.filename)
                  | (name, _, ({ Scope. typ; _} as binding)) :: _ ->
                    match typ with
                    | Scope.Import import -> resolve_import dep_map m.filename import
                    | _ -> name_of_binding m.id name binding
          in

          let patch_identifier (loc, name) =
            match get_top_level_binding name with
            | Some binding ->
              patch_loc_with
                loc
                (fun dep_map ->
                   match binding.typ with
                   | Scope.Import import ->
                     resolve_import dep_map filename import
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
                 | Some filename ->
                   let wrapper = gen_wrapper_binding filename in
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
            | Visit.Continue ->
              match stmt with
              | S.ExportNamedDeclaration { source = Some _; _ }
              | S.ExportNamedDeclaration { specifiers = Some _; _ }->
                remove_loc loc;
                Visit.Break;

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
                Visit.Continue

              | S.ExportDefaultDeclaration {
                  declaration = S.ExportDefaultDeclaration.Declaration (stmt_loc, _);
                  _ }
              | S.ExportNamedDeclaration { declaration = Some (stmt_loc, _); _ } ->
                remove
                  loc.Loc.start.offset
                  (stmt_loc.Loc.start.offset - loc.Loc.start.offset);
                Visit.Continue;

              | S.ImportDeclaration { source = (_, { value = request; _ }); _ } ->
                if (not @@ is_ignored_request request)
                then begin
                  let _ = add_static_dep request in
                  remove_loc loc;
                end
                else
                  remove_loc loc;
                Visit.Continue;

              | S.ForIn {left = S.ForIn.LeftPattern pattern; _}
              | S.ForOf {left = S.ForOf.LeftPattern pattern; _} ->
                patch_pattern pattern;
                Visit.Continue;

              | _ ->
                Visit.Continue
          in

          let visit_expression visit_ctx (loc, expr) =
            let action =
              Mode.patch_expression patcher ctx.Context.mode visit_ctx (loc,expr)
            in
            match action with
            | Visit.Break -> Visit.Break
            | Visit.Continue ->
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
                  Visit.Continue

              (* static imports *)
              | E.Call {
                  callee = (_, E.Identifier (_, "require"));
                  arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
                } when !stmt_level = 1 ->
                  let dep = add_static_dep request in
                  patch_loc_with loc
                    (fun dep_map ->
                       match MDM.get dep dep_map with
                       | None ->
                         failwith ("Cannot resolve request: " ^ request)
                       | Some m ->
                         Printf.sprintf "(%s)" @@ gen_ext_namespace_binding m.id
                    );
                  Visit.Break;

              (* dynamic imports *)
              | E.Call {
                  callee = (_, E.Identifier (_, "require"));
                  arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
                } when !stmt_level > 1 ->
                let dep = add_dynamic_dep ctx request filename in
                patch_dynamic_dep loc dep "__fastpack_require__";
                Visit.Break;

              | E.Import (_, E.Literal { value = L.String request; _ }) ->
                let dep = add_dynamic_dep ctx request filename in
                patch_dynamic_dep loc dep "__fastpack_import__";
                Visit.Break;


              | E.Member {
                  _object = (_, E.Identifier (_, "module"));
                  property = E.Member.PropertyIdentifier (_, "exports");
                  _
                } ->
                patch_namespace loc;
                Visit.Break;

              (* replace identifiers *)
              | E.Identifier ((loc, name) as id) ->
                if (name = "exports")
                then patch_namespace loc
                else patch_identifier id;
                Visit.Break;

              | E.Assignment { left; _ } ->
                patch_pattern left;
                Visit.Continue

              | _ ->
                Visit.Continue;
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
          begin
            Visit.visit handler program;
            if (not !has_namespace_binding) then add_namespace_binding ();
          end;

          (!workspace, !static_deps, program_scope, is_es_module stmts)
        in

        let source = m.Module.workspace.Workspace.value in
        let (workspace, static_deps, scope, es_module) =
          try
              analyze m.id m.filename (transpile ctx m.filename source)
          with
          | FlowParser.Parse_error.Error args ->
            raise (PackError (ctx, CannotParseFile (m.filename, args)))
        in
        let m = {
          m with
          workspace;
          scope;
          dependencies = static_deps;
          es_module;
        } in
        DependencyGraph.add_module graph m;

        (* check all static dependecies *)
        let%lwt missing = Lwt_list.filter_map_s
          (fun req ->
            (match%lwt Dependency.resolve req with
             | None ->
               Lwt.return_some req
             | Some resolved ->
               (* check if this modules is seen earlier in the stack *)
               if has_module resolved
               then begin
                 let () = add_resolved_request req resolved in
                 Lwt.return_none
               end
               else begin
                 let%lwt dep_module =
                   match DependencyGraph.lookup_module graph resolved with
                   | None ->
                     let%lwt m = read_module ctx cache resolved in
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
                   DependencyGraph.add_dependency graph m (req, Some dep_module)
                 in
                 Lwt.return_none
               end
            )
          )
          static_deps
        in
        match missing with
        | [] -> Lwt.return m
        | _ -> raise (PackError (ctx, CannotResolveModules missing))
      in

      let emit graph entry =
        let emit bytes = Lwt_io.write channel bytes in
        let emit_module dep_map m =
          debug (fun m_ -> m_ "Emitting: %s" m.Module.filename);
          emit (Printf.sprintf "\n/* %s */\n\n" m.id)
          >> Workspace.write channel m.Module.workspace dep_map
          >>= (fun _ -> Lwt.return_unit)
        in

        let emit_wrapper_start, emit_wrapper_end =
          if with_wrapper then
            (fun () ->
               emit @@ "\nfunction " ^ gen_wrapper_binding entry.Module.filename ^ "() {\n"
            ),
            (fun () ->
               emit
               @@ Printf.sprintf "\nreturn %s;\n}\n"
               @@ gen_ext_namespace_binding entry.Module.id
            )
          else
            (fun () -> emit ""), (fun () -> emit "")
        in

        let%lwt () = emit_wrapper_start () in
        let%lwt modules =
          DependencyGraph.sort graph entry
          |> Lwt_list.fold_left_s
            (fun dependency_map m ->
              let%lwt () = emit_module dependency_map m in
              !resolved_requests
              |> DM.bindings
              |> List.filter (fun (_, value) -> value = m.filename)
              |> List.fold_left (fun acc (k, _) -> MDM.add k m acc) dependency_map
              |> Lwt.return
            )
            (!resolved_requests
             |> DM.bindings
             |> List.filter (fun (_, filename) -> has_module filename)
             |> List.fold_left
               (fun modules (dep, filename) ->
                  match get_module filename with
                  | Some m -> MDM.add dep m modules
                  | None -> failwith "Should not happen"
               )
              modules
            )
        in
        let%lwt () = emit_wrapper_end () in
        Lwt.return modules
      in

      let graph = DependencyGraph.empty () in
      let%lwt entry = read_module ctx cache ctx.entry_filename in
      let%lwt entry = process ctx graph entry in
      let%lwt dynamic_deps =
        Lwt_list.map_s
          (fun (ctx, req) ->
             let%lwt resolved = Dependency.resolve req in
             begin
               match resolved with
               | Some filename -> add_resolved_request req filename
               | None -> ()
             end;
             Lwt.return (ctx, req, resolved)
          )
          !dynamic_deps
      in
      let missing_dynamic_deps =
        List.filter (fun (_, _, resolved) -> resolved = None) dynamic_deps
      in
      match missing_dynamic_deps with
      | (ctx, req, None) :: _ ->
        raise (PackError (ctx, CannotResolveModules [req]))
      | _ ->
        let%lwt modules = emit graph entry in
        let%lwt _ =
          Lwt_list.fold_left_s
            (fun seen (ctx, _, resolved) ->
               match resolved with
               | Some entry_filename ->
                 if StringSet.mem entry_filename seen
                 then Lwt.return seen
                 else
                   let%lwt () =
                     pack
                      ~with_wrapper:true
                      { ctx with entry_filename }
                      modules
                   in
                   Lwt.return (StringSet.add entry_filename seen)
               | None ->
                 failwith "Never happens!"
            )
            StringSet.empty
            dynamic_deps
          in
          Lwt.return_unit
  in
  let%lwt () =
    Lwt_io.write channel
    @@ Printf.sprintf "
var process = {env: {NODE_ENV: '%s'}};
var __fastpack_cache__ = {};

function __fastpack_require__(f) {
  if (__fastpack_cache__[f.name] === undefined) {
    __fastpack_cache__[f.name] = f();
  }
  return __fastpack_cache__[f.name];
}

function __fastpack_import__(f) {
  return new Promise((resolve, reject) => {
    try {
      resolve(__fastpack_require__(f));
    } catch (e) {
      reject(e);
    }
  });
}
"
    @@ Mode.to_string ctx.mode
  in
  pack ctx MDM.empty
