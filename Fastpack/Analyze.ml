module M = Map.Make(String)

let analyze _id filename source =
  let ((_, stmts, _) as program), _ = Parser.parse_source source in

  let module S = Ast.Statement in
  let module E = Ast.Expression in
  let module L = Ast.Literal in

  let dependencies = ref [] in
  let dependency_id = ref 0 in
  let workspace = ref (Workspace.of_string source) in
  let {Workspace.
        patch;
        patch_loc_with;
        patch_loc;
        sub_loc;
        remove_loc;
        _
      } = Workspace.make_patcher workspace
  in

  let program_scope = Scope.of_program stmts Scope.empty in
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

  let get_module dep ctx =
    match Module.DependencyMap.get dep ctx with
    | Some m -> m
    | None -> failwith ("Module node found: " ^ dep.request)
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

  let exports_from_specifiers =
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

  let define_binding = Printf.sprintf "const %s = %s;" in

  let fastpack_require id filename =
    Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")"
      filename
      id
  in

  let update_exports exports =
    exports
    |> List.map
      (fun (name, value) ->
         Printf.sprintf
           "Object.defineProperty(exports, \"%s\", {get: () => %s});"
           name
           value
      )
    |> String.concat " "
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
          specifiers = [];
          _;
        } ->
        let is_skipped =
          List.exists
            (fun e -> String.suffix ~suf:("." ^ e) request)
            ["css"; "less"; "sass"; "woff"; "svg"; "png"; "jpg"; "jpeg";
             "gif"; "ttf"]
        in
        if is_skipped
        then remove_loc loc
        else
          let dep = add_dependency request in
          patch_loc_with
            loc
            (fun ctx ->
              let {Module. id = module_id; _} = get_module dep ctx in
              (fastpack_require module_id dep.request) ^ ";\n"
            )

      | S.ImportDeclaration {
          source = (_, { value = L.String request; _ });
          specifiers;
          _;
        } ->
        let dep = add_dependency request in
        patch_loc_with
          loc
          (fun ctx ->
            let {Module. id = module_id; _} = get_module dep ctx in
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
            match get_module_binding dep.request, namespace with
            | Some binding, spec :: [] ->
              define_binding spec binding
            | None, spec::[] ->
              define_binding
                (add_module_binding ~binding:(Some spec) dep.request)
                (fastpack_require module_id dep.request)
            | Some _, [] ->
              ""
            | None, [] ->
              define_binding
                (add_module_binding dep.request)
                (fastpack_require module_id dep.request)
            | _ -> failwith "Unexpected several namespace specifiers"
          );

      | S.ExportNamedDeclaration {
          exportKind = S.ExportValue;
          declaration = Some ((stmt_loc, _) as declaration);
          _
        } ->
        let exports =
          List.map (fun (name, _) -> (name, name))
          @@ Scope.names_of_node declaration
        in
        begin
          patch_loc loc @@ sub_loc stmt_loc;
          patch loc._end.offset 0 @@ "\n" ^ update_exports exports ^ "\n";
        end;

      | S.ExportNamedDeclaration {
          exportKind = S.ExportValue;
          declaration = None;
          specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
          source = None;
        } ->
        patch_loc loc @@ update_exports @@ exports_from_specifiers specifiers

      | S.ExportNamedDeclaration {
          exportKind = S.ExportValue;
          declaration = None;
          specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
          source = Some (_, { value = L.String request; _ });
        } ->
        let dep = add_dependency request in
        let exports_from binding =
          exports_from_specifiers specifiers
          |> List.map (fun (exported, local) -> exported, binding ^ "." ^ local)
          |> update_exports
        in
        patch_loc_with
          loc
          (fun ctx ->
            let {Module. id = module_id; _} = get_module dep ctx in
            match get_module_binding dep.request with
            | Some binding ->
              exports_from binding
            | None ->
              let binding = add_module_binding dep.request in
              define_binding
                binding
                (fastpack_require module_id dep.request)
              ^ "\n"
              ^ exports_from binding
          );

      | S.ExportNamedDeclaration {
          exportKind = S.ExportValue;
          declaration = None;
          specifiers = Some (
              S.ExportNamedDeclaration.ExportBatchSpecifier (_, Some (_, spec)));
          source = Some (_, { value = L.String request; _ });
        } ->
        let dep = add_dependency request in
        patch_loc_with
          loc
          (fun ctx ->
            let {Module. id = module_id; _} = get_module dep ctx in
            match get_module_binding dep.request with
            | Some binding ->
              update_exports [(spec, binding)]
            | None ->
              let binding = add_module_binding dep.request in
              define_binding
                binding
                (fastpack_require module_id dep.request)
              ^ "\n"
              ^ update_exports [(spec, binding)]
          )

      | S.ExportNamedDeclaration {
          exportKind = S.ExportValue;
          declaration = None;
          specifiers = Some (
              S.ExportNamedDeclaration.ExportBatchSpecifier (_, None));
          source = Some (_, { value = L.String request; _ });
        } ->
        let dep = add_dependency request in
        patch_loc_with
          loc
          (fun ctx ->
            let {Module. id = module_id; scope; _} = get_module dep ctx in
            let exports_from binding =
              Scope.get_exports scope
              |> List.map (fun name -> name, binding ^ "." ^ name)
            in
            match get_module_binding dep.request with
            | Some binding ->
              update_exports @@ exports_from binding
            | None ->
              let binding = add_module_binding dep.request in
              define_binding
                binding
                (fastpack_require module_id dep.request)
              ^ "\n"
              ^ update_exports @@ exports_from binding

          )

      | S.ExportDefaultDeclaration {
          exportKind = S.ExportValue;
          declaration = S.ExportDefaultDeclaration.Expression (expr_loc, _)
        }
      | S.ExportDefaultDeclaration {
          exportKind = S.ExportValue;
          declaration = S.ExportDefaultDeclaration.Declaration (
              expr_loc,
              S.FunctionDeclaration { id=None; _ }
            )
        }
      | S.ExportDefaultDeclaration {
          exportKind = S.ExportValue;
          declaration = S.ExportDefaultDeclaration.Declaration (
              expr_loc,
              S.ClassDeclaration { id=None; _ }
            )
        } ->
        let expr = sub_loc expr_loc in
        patch_loc loc @@ update_exports [("default", expr)]

      | S.ExportDefaultDeclaration {
          exportKind = S.ExportValue;
          declaration = S.ExportDefaultDeclaration.Declaration (
              expr_loc,
              S.FunctionDeclaration { id = Some (_, id); _ }
            )
        }
      | S.ExportDefaultDeclaration {
          exportKind = S.ExportValue;
          declaration = S.ExportDefaultDeclaration.Declaration (
              expr_loc,
              S.ClassDeclaration { id = Some (_, id); _ }
            )
        } ->
        let expr = sub_loc expr_loc in
        begin
          patch_loc loc expr;
          patch loc._end.offset 0
          @@ "\n" ^ update_exports [("default", id)] ^ "\n";
        end;

      | _ -> ()
    in Visit.Continue
  in

  let visit_expression ((loc: Loc.t), expr) =
    (* TODO: E.Import *)
    match expr with
    | E.Call {
        callee = (_, E.Identifier (_, "require"));
        arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
      } ->
      let dep = add_dependency request in
      patch_loc_with loc (fun ctx ->
          let {Module. id = module_id; _} = get_module dep ctx in
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

  (!workspace, !dependencies, program_scope)

