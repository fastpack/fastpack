module M = Map.Make(String)

let analyze _id filename source =
  let ((_, stmts, _) as program), _ = Parser.parse_source source in

  let module S = Ast.Statement in
  let module E = Ast.Expression in
  let module L = Ast.Literal in

  let dependencies = ref [] in
  let dependency_id = ref 0 in
  let workspace = ref (Workspace.of_string source) in
  let {Workspace. patch_loc_with; _ } = Workspace.make_patcher workspace in

  let scopes = ref [Scope.of_program stmts Scope.empty] in
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

  let module_bindings = ref M.empty in
  let n_module = ref 0 in
  let get_module_binding module_request =
    M.get module_request !module_bindings
  in
  let add_module_binding ?(binding=None) module_request =
    let rec gen_module_binding () =
      n_module := !n_module + 1;
      let binding = "$lib" ^ (string_of_int !n_module) in
      if not (Scope.has_binding binding (top_scope ()))
      then binding
      else gen_module_binding ()
    in
    let binding =
      match binding with
      | Some binding -> binding
      | None -> gen_module_binding ()
    in
    begin
      module_bindings := M.add module_request binding !module_bindings;
      binding
    end
  in

  let dependency_to_module_id ctx dep =
    try
      let m = Module.DependencyMap.find dep ctx in
      m.Module.id
    with |
      Not_found -> "fastpack/not_found"
  in

  let add_dependency request =
    dependency_id := !dependency_id + 1;
    let dep = {
      Dependency.
      request;
      requested_from_filename = filename;
    } in
    begin
      dependencies := dep::!dependencies;
      dep
    end
  in

  let define_binding = Printf.sprintf "const %s = %s;" in

  let fastpack_require id filename =
    Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")"
      filename
      id
  in

  let enter_function f =
    push_scope (Scope.of_function f (top_scope ()))
  in

  let leave_function _ =
    pop_scope ()
  in

  let enter_statement stmt =
    push_scope (Scope.of_statement stmt (top_scope ()))
  in

  let leave_statement _ =
    pop_scope ()
  in

  let visit_statement ((loc: Loc.t), stmt) =
    let _ = match stmt with
      | S.ImportDeclaration {
          source = (_, { value = L.String request; _ });
          specifiers;
          _;
        } ->
        let dep = add_dependency request in
        patch_loc_with
          loc
          (fun ctx ->
            let module_id = dependency_to_module_id ctx dep in
            let namespace =
              List.filter_map
                (fun spec ->
                   match spec with
                   | S.ImportDeclaration.ImportNamespaceSpecifier (_,(_, name)) ->
                     Some name
                   | _ ->
                     None
                )
                specifiers
            in
            match specifiers, get_module_binding dep.request, namespace with
            | [], _, _ ->
              (fastpack_require module_id dep.request) ^ ";\n"
            | _, Some binding, spec :: [] ->
              define_binding spec binding
            | _, None, spec::[] ->
              define_binding
                (add_module_binding ~binding:(Some spec) dep.request)
                (fastpack_require module_id dep.request)
            | _, Some _, [] ->
              ""
            | _, None, [] ->
              define_binding
                (add_module_binding dep.request)
                (fastpack_require module_id dep.request)
            | _ -> failwith "Unexpected several namespace specifiers"
          );
      | _ -> ()
    in Visit.Continue
  in

  let visit_expression ((loc: Loc.t), expr) =
    match expr with
    | E.Call {
        callee = (_, E.Identifier (_, "require"));
        arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
      } ->
      let dep = add_dependency request in
      patch_loc_with loc (fun ctx ->
          let module_id = dependency_to_module_id ctx dep in
          fastpack_require module_id dep.request
        );
      Visit.Break
    | E.Identifier (loc, name) ->
      let () =
        match get_binding name with
        | Some (_, Scope.Import { source; remote = Some remote}) ->
          patch_loc_with
            loc
            (fun _ ->
               match get_module_binding source with
               | Some module_binding ->
                 module_binding ^ "." ^ remote
               | None ->
                 (* TODO: provide better error report*)
                 failwith "Usage of binding before import"
            )
        | _ -> ();
      in Visit.Break;
    | _ ->
      Visit.Continue;
  in

  let handler = {
    Visit.default_visit_handler with
    visit_statement;
    visit_expression;
    enter_function;
    leave_function;
    enter_statement;
    leave_statement;
  } in

  Visit.visit handler program;

  (!workspace, !dependencies)

