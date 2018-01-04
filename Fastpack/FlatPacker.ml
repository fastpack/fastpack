open PackerUtil
(* open Lwt.Infix *)

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

type bindings = {
  exports : string M.t;
  internals: string M.t;
}

let pack ctx channel =

  (* internal top-level bindings in the file *)
  let gen_int_binding module_id name =
    Printf.sprintf "$i$__%s__%s" module_id name
  in

  let gen_ext_binding module_id name =
    Printf.sprintf "$e$__%s__%s" module_id name
  in

  let gen_ext_namespace_binding module_id =
    gen_ext_binding module_id "$$NAMESPACE$$"
  in

  (* potential collisions, never appear on the top-level
   * It should be safe to move this generator into the `analyze` function
   * since these names are always scoped
   * *)
  let collision = ref 0 in
  let gen_collision_binding () =
    collision := !collision + 1;
    "$_c" ^ (string_of_int !collision)
  in

  (* names of wrapper functions used to handle dynamic imports *)
  let wrap = ref 0 in
  let wrappers = ref M.empty in
  let add_wrapper filename =
    if not (M.mem filename !wrappers)
    then begin
      wrap := !wrap + 1;
      wrappers := M.add filename ("$_w" ^ (string_of_int !wrap)) !wrappers;
    end
  in
  let get_wrapper filename =
    M.get filename !wrappers
  in

  let may_collide _name =
    false
    (* Str.string_match (Str.regexp "^\\$_[iewc][0-9]+$") name 0 *)
  in

  let rec pack ?(with_wrapper=None) ctx modules =

    let () = Printf.printf "Packing: %s \n" ctx.entry_filename in

    let () = Printf.printf "------------- \n" in
    let () =
      modules
      |> MDM.bindings
      |> List.iter
        (fun ({Dependency. request; requested_from_filename = rf }, _) ->
          Printf.printf "%s from %s \n" request rf
        )
    in
    let () = Printf.printf "------------- \n" in

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

    let name_of_binding module_id name (binding : Scope.binding) =
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

    let rec process ({transpile; _} as ctx) graph (m : Module.t) =

      let analyze module_id filename source =
        let () = Printf.printf "Analyzing: %s \n" filename in

        let ((_, stmts, _) as program), _ = Parser.parse_source source in

        let workspace = ref (Workspace.of_string source) in
        let {Workspace.
              patch;
              sub_loc;
              patch_loc;
              patch_with;
              patch_loc_with;
              remove_loc;
              remove;
              _
            } = Workspace.make_patcher workspace
        in


        let patch_binding name (binding : Scope.binding) =
          patch_loc binding.loc @@ name_of_binding module_id name binding
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

        let add_export_all () =
          patch_with (String.length source) 0
            (fun _ ->
              let expr =
                Scope.bindings program_scope
                |> List.filter_map
                  (fun (name, binding) ->
                     match binding.Scope.exported with
                     | None -> None
                     | Some exported ->
                       Some (Printf.sprintf "%s: %s" exported @@ name_of_binding module_id name binding)
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



        (* scope stack *)
        (* let print_col col = *)
        (*   let () = Printf.printf "-----\n" in *)
        (*   let () = *)
        (*     List.iter *)
        (*       (fun (n, v) -> Printf.printf "%s = %s\n" n v) *)
        (*       (M.bindings col) *)
        (*   in *)
        (*   Printf.printf "-----\n" *)
        (* in *)
        let scopes = ref [program_scope] in
        let collisions = ref [M.empty] in
        let top_scope () = List.hd !scopes in
        let top_collisions () = List.hd !collisions in

        let push_scope scope =
          let scope_collisions =
            Scope.fold_left
              (fun acc (name, { loc; _ }) ->
                let update_acc () =
                  let binding = gen_collision_binding () in
                  let () = patch_loc loc binding in
                  M.add name (binding, loc) acc
                in
                if may_collide name
                then begin
                  match M.get name acc with
                  | None ->
                    update_acc ()
                  | Some (_, prev_loc) when (prev_loc <> loc) ->
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

        let rec resolve_import dep_map {Scope. source; remote } =
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
              let names =
                Scope.bindings m.scope
                |> List.filter
                  (fun (name, {Scope. exported; _}) ->
                     name = remote && exported <> None
                  )
              in
              match names with
              | [] ->
                failwith ("Name " ^ remote ^ " not found in module " ^ m.Module.filename)
              | (name, ({ Scope. typ; _} as binding)) :: _ ->
                match typ with
                | Scope.Import import -> resolve_import dep_map import
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
                   resolve_import dep_map import
                 | _ ->
                   name_of_binding module_id name binding
              )
          | None ->
            match M.get name (top_collisions ()) with
            | Some (name, _) -> patch_loc loc name
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

        (* Level of statement *)
        let stmt_level = ref 0 in

        let enter_function f =
          push_scope (Scope.of_function f (top_scope ()))
        in

        let leave_function _ =
          pop_scope ()
        in

        let enter_statement (loc, stmt) =
          let () = push_scope (Scope.of_statement (loc, stmt) (top_scope ())) in
          match stmt, !stmt_level with
          | S.Block _, 0 -> ()
          | _ -> stmt_level := !stmt_level + 1;
        in

        let leave_statement (_, stmt) =
          let () = pop_scope () in
          match stmt, !stmt_level with
          | S.Block _, 0 -> ()
          | _ -> stmt_level := !stmt_level - 1;
        in

        let visit_statement (loc, stmt) =
          match stmt with
          | S.ExportNamedDeclaration { source = Some _; _} ->
            remove_loc loc;
            Visit.Break;

          | S.ExportNamedDeclaration { declaration = Some (stmt_loc, _); _ } ->
            remove
              loc.Loc.start.offset
              (stmt_loc.Loc.start.offset - loc.Loc.start.offset);
            Visit.Continue;

          | S.ImportDeclaration { source = (_, { value = request; _ }); _ } ->
            let _ = add_static_dep request in
            remove_loc loc;
            Visit.Continue;

          | _ ->
            Visit.Continue
        in

        let visit_expression (loc, expr) =
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
          | E.Import (_, E.Literal { value = L.String request; _ })
          | E.Call {
              callee = (_, E.Identifier (_, "require"));
              arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
            } when !stmt_level = 1 ->
              let dep = add_static_dep request in
              patch_loc_with loc
                (fun dep_map ->
                   match MDM.get dep dep_map with
                   | None -> failwith ("Cannot resolve request: " ^ request)
                   | Some m ->
                     Printf.sprintf "(%s)" @@ gen_ext_namespace_binding m.id
                );
              Visit.Break;

          (* dynamic imports *)
          | E.Import (_, E.Literal { value = L.String request; _ })
          | E.Call {
              callee = (_, E.Identifier (_, "require"));
              arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
            } when !stmt_level > 1 ->
              let dep = add_dynamic_dep ctx request filename in
              patch_loc_with
                loc
                (fun _ ->
                   match get_resolved_request dep with
                   | None ->
                     failwith "Something wrong"
                   | Some filename ->
                     match get_wrapper filename with
                     | None ->
                       failwith "Cannot find wrapper for module"
                     | Some wrapper ->
                       Printf.sprintf "__fpack__.cached(%s)" wrapper
                );
              Visit.Break;

          (* replace identifiers with previously calculated names *)
          | E.Identifier id ->
            patch_identifier id;
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
        } in
        begin
          Visit.visit handler program;
          add_export_all ();
        end;

        (!workspace, !static_deps, program_scope)
      in

      let source = m.Module.workspace.Workspace.value in
      let (workspace, static_deps, scope) =
        try
            analyze m.id m.filename (transpile m.filename source)
        with
        | FlowParser.Parse_error.Error args ->
          raise (PackError (ctx, CannotParseFile (m.filename, args)))
      in
      let m = { m with workspace; scope; } in
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
                   let%lwt m = read_module ctx resolved in
                   let%lwt m =
                     process { ctx with stack = req :: ctx.stack } graph m
                   in
                   begin
                     let () = add_resolved_request req resolved in
                     Lwt.return m
                   end
                 | Some m ->
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
      let emit_if_some value f =
        match value with
        | Some value -> f value
        | None -> emit ""
      in
      let emit_module dep_map m =
        let () = Printf.printf "Emitting: %s \n" m.Module.filename in
        emit (Printf.sprintf "\n/* %s */\n\n" m.id)
        >> emit_if_some
          with_wrapper
          (fun wrapper -> emit @@ "\nfunction " ^ wrapper ^ "() {\n")
        >> Workspace.write channel m.Module.workspace dep_map
        >> emit_if_some with_wrapper (fun _ -> emit "\n}\n")
      in
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
              let () = Printf.printf "In Fold: %s \n" filename in
              match get_module filename with
              | Some m -> MDM.add dep m modules
              | None -> failwith "Should not happen"
           )
          modules
        )
    in

    let graph = DependencyGraph.empty () in
    let%lwt entry = read_module ctx ctx.entry_filename in
    let%lwt entry = process ctx graph entry in
    let%lwt dynamic_deps =
      Lwt_list.map_s
        (fun (ctx, req) ->
           let%lwt resolved = Dependency.resolve req in
           begin
             match resolved with
             | Some filename ->
               let () = add_resolved_request req filename in
               add_wrapper filename
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
                 let () = Printf.printf "%s %d\n" entry_filename (List.length dynamic_deps) in

                 let () = Printf.printf "**----------- \n" in
                 let () =
                   modules
                   |> MDM.bindings
                   |> List.iter
                     (fun ({Dependency. request; requested_from_filename = rf }, _) ->
                       Printf.printf "%s from %s \n" request rf
                     )
                 in
                 let () = Printf.printf "**----------- \n" in

                 let%lwt () =
                   pack
                    ~with_wrapper:(get_wrapper entry_filename)
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
  pack ctx MDM.empty
