let analyze _id filename source =
  let (program, _errors) = Parser_flow.program_file source None in

  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

  let dependencies = ref [] in
  let dependency_id = ref 0 in
  let workspace = ref (Workspace.of_string source) in

  let dependency_to_module_id ctx dep =
    try
      let m = Module.DependencyMap.find dep ctx in
      m.Module.id
    with |
      Not_found -> "fastpack/not_found"
  in

  let visit_import_declaration ((loc: Loc.t), stmt) =
    match stmt with
    | S.ImportDeclaration {
        source = (_, { value = L.String request; _ });
        _;
      } ->
      let rewrite_import = {
        Workspace.
        patch = (fun _ctx -> "OKOKOK");
        offset_start = loc.start.offset;
        offset_end = loc._end.offset;
      } in
      workspace := Workspace.patch !workspace rewrite_import;
      dependency_id := !dependency_id + 1;
      dependencies := {
        Dependency.
        request;
        requested_from_filename = filename;
      }::!dependencies
    | _ -> ()
  in

  let visit_require_call (loc, expr) =
    match expr with
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
      let rewrite_require = {
        Workspace.
        patch = (fun ctx ->
            let module_id = dependency_to_module_id ctx dep in
            Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")" dep.request module_id
          );
        offset_start = loc.Loc.start.offset;
        offset_end = loc.Loc._end.offset;
      } in
      workspace := Workspace.patch !workspace rewrite_require;
    | _ ->
      ()
  in

  let handler = {
    Visit.
    visit_statement = visit_import_declaration;
    visit_expression = visit_require_call;
  } in

  Visit.visit handler program;

  (!workspace, !dependencies)

