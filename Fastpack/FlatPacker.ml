open PackerUtil
(* open Lwt.Infix *)

module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal

module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit

module StringSet = Set.Make(String)
module M = Map.Make(String)
module DM = Map.Make(Dependency)

type binding = Normal | Wrapper

let pack ctx channel =

  (* binding generators*)
  let ext = ref 0 in
  let gen_ext_binding () =
    ext := !ext + 1;
    "$_e" ^ (string_of_int !ext)
  in

  let rec pack ?(with_wrapper=None) ctx modules =

    let () = Printf.printf "Packing: %s \n" ctx.entry_filename in

    let resolved_requests = ref DM.empty in
    let add_resolved_request req filename =
      resolved_requests := DM.add req filename !resolved_requests
    in
    let get_resolved_request req =
      DM.get req !resolved_requests
    in

    let wrappers = ref M.empty in
    let get_wrapper filename =
      M.get filename !wrappers
    in

    let modules = ref modules in
    let add_module filename =
      modules := M.add filename M.empty !modules
    in
    let has_module filename =
      M.mem filename !modules
    in
    let get_module filename =
      M.get filename !modules
    in
    let add_module_binding ?(with_wrapper=false) filename binding value =
      let expr =
        if with_wrapper
        then begin
          wrappers := M.add filename value !wrappers;
          Printf.sprintf "__fpack_cache__(\"%s\", %s)" value value
        end
        else value
      in
      let mod_map =
        match get_module filename with
        | Some mod_map -> mod_map
        | None -> M.empty
      in
      modules := M.add filename (M.add binding expr mod_map) !modules
    in
    let get_module_binding filename binding =
      match get_module filename with
      | Some mod_map -> M.get binding mod_map
      | None -> None
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

      let analyze _id filename source =
        let () = Printf.printf "Analyzing: %s \n" filename in

        let ((_, stmts, _) as program), _ = Parser.parse_source source in

        let workspace = ref (Workspace.of_string source) in
        let {Workspace.
              patch;
              (* patch_with; *)
              patch_loc_with;
              (* remove_loc; *)
              (* remove; *)
              _
            } = Workspace.make_patcher workspace
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

        let program_scope = Scope.of_program stmts Scope.empty in

        (* Level of statement *)
        let stmt_level = ref 0 in

        let enter_statement (_, stmt) =
          match stmt, !stmt_level with
          | S.Block _, 0 -> ()
          | _ -> stmt_level := !stmt_level + 1;
        in

        let leave_statement (_, stmt) =
          match stmt, !stmt_level with
          | S.Block _, 0 -> ()
          | _ -> stmt_level := !stmt_level - 1;
        in

        let visit_statement (loc, stmt) =
          let () =
            match stmt with
            | S.ImportDeclaration { source = (_, { value = request; _ }); _ } ->
              let _ = add_static_dep request in
              patch loc.Loc.start.offset 0 "/* static */ "
            | _ -> ()
          in
          Visit.Continue
        in

        let visit_expression (loc, expr) =
          match expr with
          | E.Import (_, E.Literal { value = L.String request; _ })
          | E.Call {
              callee = (_, E.Identifier (_, "require"));
              arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
            } when !stmt_level = 1 ->
              let _ = add_static_dep request in
              patch loc.Loc.start.offset 0 "/* static */ ";
              Visit.Break;

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
                     match get_module_binding filename "*" with
                     | None -> failwith "Cannot find * of module"
                     | Some binding -> binding
                );
              Visit.Break;
          | _ -> Visit.Continue;

        in

        let handler = {
          Visit.default_visit_handler with
          visit_statement;
          visit_expression;
          enter_statement;
          leave_statement;
        } in
        begin
          begin
            match with_wrapper with
            | Some wrapper -> patch 0 0 @@ "\nfunction " ^ wrapper ^ "() {\n"
            | None -> ()
          end;
          Visit.visit handler program;
          begin
            match with_wrapper with
            | Some _ -> patch (String.length source - 1) 0 @@ "\n}\n"
            | None -> ()
          end;
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
      let%lwt missing = Lwt_list.filter_map_s (
          fun req ->
            (match%lwt Dependency.resolve req with
             | None ->
               Lwt.return_some req
             | Some resolved ->
               (* check if this modules is seen earlier in the stack *)
               if not (has_module resolved)
               then begin
                 let%lwt dep_module =
                   match DependencyGraph.lookup_module graph resolved with
                   | None ->
                     let%lwt m = read_module ctx resolved in
                     let%lwt m =
                       process { ctx with stack = req :: ctx.stack } graph m
                     in
                     begin
                       let () = add_resolved_request req resolved in
                       add_module resolved;
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
               else
                 Lwt.return_none
            )
        ) static_deps
      in
      match missing with
      | [] -> Lwt.return m
      | _ -> raise (PackError (ctx, CannotResolveModules missing))
    in

    let emit graph entry =
      let emit bytes = Lwt_io.write channel bytes in
      let emit_module m =
        let dependencies = DependencyGraph.lookup_dependencies graph m in
        let ctx =
          List.fold_left
            (fun ctx (dep, m) ->
               match m with
               | None -> failwith "Module dependency not found"
               | Some m -> Module.DependencyMap.add dep m ctx
            )
            Module.DependencyMap.empty
            dependencies
        in
        let () = Printf.printf "Emitting: %s \n" m.filename in
        emit (Printf.sprintf "\n/* %s */\n\n" m.id)
        >> Workspace.write channel m.Module.workspace ctx
      in
      let modules = DependencyGraph.sort graph entry in
      Lwt_list.iter_s emit_module modules;
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
               let binding = gen_ext_binding () in
               let () = add_resolved_request req filename in
               add_module_binding ~with_wrapper:true filename "*" binding
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
      let%lwt () = emit graph entry in
      let%lwt _ =
        Lwt_list.fold_left_s
          (fun seen (ctx, _, resolved) ->
             match resolved with
             | Some entry_filename ->
               if StringSet.mem entry_filename seen
               then Lwt.return seen
               else
                 let () = Printf.printf "%s %d\n" entry_filename (List.length dynamic_deps) in
                 begin
                   match get_wrapper entry_filename with
                   | None ->
                     failwith "Cannot find wrapper!"
                   | Some wrapper ->
                     let%lwt () =
                       pack
                        ~with_wrapper:(Some wrapper)
                        { ctx with entry_filename }
                        !modules
                     in
                     Lwt.return (StringSet.add entry_filename seen)
                 end
             | None ->
               failwith "Never happens!"
          )
          StringSet.empty
          dynamic_deps
        in
        Lwt.return_unit
  in
  pack ctx M.empty
