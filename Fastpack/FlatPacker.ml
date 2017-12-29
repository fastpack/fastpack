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

let pack ctx channel =
  let rec pack ?(_with_wrapper=None) ?(_parent_graph=None) ctx =

    let () = Printf.printf "Packing: %s \n" ctx.entry_filename in

    (* Keep track of all dynamic dependencies while packing *)
    let dynamic_deps = ref [] in
    let add_dynamic_dep ctx request filename =
      let dep = {
        Dependency.
        request;
        requested_from_filename = filename;
      } in
      dynamic_deps := (ctx, dep, "wrapper") :: !dynamic_deps
    in

    let rec process ({transpile; _} as ctx) graph (m : Module.t) =

      let analyze _id filename source =
        let () = Printf.printf "Analyzing: %s \n" filename in

        let ((_, stmts, _) as program), _ = Parser.parse_source source in

        let workspace = ref (Workspace.of_string source) in
        let {Workspace.
              patch;
              (* patch_loc_with; *)
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
              let _ = add_dynamic_dep ctx request filename in
              patch loc.Loc.start.offset 0 "/* dynamic */ ";
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
        Visit.visit handler program;

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

      (* check all static dependecies and gather potetial dynamic ones *)
      let%lwt missing = Lwt_list.filter_map_s (
          fun req ->
            (match%lwt Dependency.resolve req with
             | None ->
               Lwt.return_some req
             | Some resolved ->
               let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
                 | None ->
                   let%lwt m = read_module ctx resolved in
                   let%lwt m =
                     process { ctx with stack = req :: ctx.stack } graph m
                   in
                   Lwt.return m
                 | Some m ->
                   Lwt.return m
               in
               DependencyGraph.add_dependency graph m (req, Some dep_module);
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
    let%lwt () = emit graph entry in
    let%lwt dynamic_deps =
      Lwt_list.map_s
        (fun (ctx, req, wrapper) ->
           let%lwt resolved = Dependency.resolve req in
           Lwt.return (ctx, req, wrapper, resolved)
        )
        !dynamic_deps
    in
    let missing_dynamic_deps =
      List.filter (fun (_, _, _, resolved) -> resolved = None) dynamic_deps
    in
    match missing_dynamic_deps with
    | (ctx, req, _, None) :: [] ->
      raise (PackError (ctx, CannotResolveModules [req]))
    | _ ->
      let%lwt _ =
        Lwt_list.fold_left_s
          (fun seen (ctx, _, wrapper, resolved) ->
             match resolved with
             | Some entry_filename ->
               if StringSet.mem entry_filename seen
               then Lwt.return seen
               else
                 let () = Printf.printf "%s %d\n" entry_filename (List.length dynamic_deps) in
                 let%lwt () =
                   pack
                    ~_with_wrapper:(Some wrapper)
                    ~_parent_graph:(Some graph)
                    { ctx with entry_filename }
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
  pack ctx
