let analyze _id filename source =
  let (program, _errors) = Parser_flow.program_file source None in
  let module S = Ast.Statement in
  let module E = Ast.Expression in
  let module L = Ast.Literal in

  let dependencies = ref [] in
  let dependency_id = ref 0 in
  let workspace = ref (Workspace.of_string source) in


  let add_patch offset_start offset_end patch =
    (* TODO: refactor to use the make_patcher API *)
    workspace := Workspace.patch !workspace {
        Workspace.
        patch;
        offset_start;
        offset_end;
        order=0;
      }
  in

  let dependency_to_module_id ctx dep =
    try
      let m = Module.DependencyMap.find dep ctx in
      m.Module.id
    with |
      Not_found -> "fastpack/not_found"
  in

  let visit_statement ((loc: Loc.t), stmt) =
    let _ = match stmt with
      | S.ImportDeclaration {
          source = (_, { value = L.String request; _ });
          _;
        } ->
        add_patch loc.start.offset loc._end.offset (fun _ctx -> "OKOKOK");
        dependency_id := !dependency_id + 1;
        dependencies := {
          Dependency.
          request;
          requested_from_filename = filename;
        }::!dependencies
      | _ -> ()
    in Visit.Continue
  in

  let visit_expression ((loc: Loc.t), expr) =
    let _ = match expr with
      | E.Call {
          callee = (_, E.Identifier (_, "require"));
          arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
        } ->
        let dep = {
          Dependency.
          request;
          requested_from_filename = filename;
        } in
        dependency_id := !dependency_id + 1;
        dependencies := dep::!dependencies;
        add_patch loc.start.offset loc._end.offset (fun ctx ->
            let module_id = dependency_to_module_id ctx dep in
            Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")"
              dep.request
              module_id
          );
      | _ ->
        ()
    in Visit.Continue
  in

  let handler = {
    Visit.
    visit_statement;
    visit_expression;
    visit_function = Visit.do_nothing;
    visit_pattern = Visit.do_nothing;
  } in

  Visit.visit handler program;

  (!workspace, !dependencies)

