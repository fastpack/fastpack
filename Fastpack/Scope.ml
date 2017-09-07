module Expression = Ast.Expression
module Pattern = Ast.Pattern
module Statement = Ast.Statement

module StringSet = Set.Make(String)

type t = {
  kind : scope_kind;
  parent : t option;
  bindings : StringSet.t;
}

and scope_kind = | FunctionScope | BlockScope

let empty = {
  kind = FunctionScope;
  parent = None;
  bindings = StringSet.empty;
}

let new_block_scope scope = {
  kind = BlockScope;
  parent = Some scope;
  bindings = StringSet.empty;
}

let new_func_scope scope = {
  kind = FunctionScope;
  parent = Some scope;
  bindings = StringSet.empty;
}

let peek_func_scope scope =
  let rec peek_func_scope' scope trace =
    match scope with
    | { parent = Some parent; kind = BlockScope; _ } -> peek_func_scope' parent (scope::trace)
    | _ -> scope, trace
  in
  peek_func_scope' scope []

let add_block_binding scope name = {
  scope with
  bindings = StringSet.add name scope.bindings
}

let add_func_binding scope name =
  let func_scope, trace = peek_func_scope scope in
  let func_scope = {
    func_scope
    with bindings = StringSet.add name func_scope.bindings
  } in
  List.fold_left
    (fun parent scope -> { scope with parent = Some parent; })
    func_scope
    trace

let bindings scope =
  StringSet.to_list scope.bindings

let block_scope_boundary (_, node) = 
  match node with
  | Statement.Block _
  | Statement.For _
  | Statement.ForIn _
  | Statement.ForOf _
  | Statement.ClassDeclaration _
  | Statement.FunctionDeclaration _ ->
    true
  | _ ->
    false

let func_scope_boundary (_, node) =
  match node with
  | Statement.ClassDeclaration _
  | Statement.FunctionDeclaration _ ->
    true
  | _ ->
    false

let name_of_identifier (_, name) =
  name

let names_of_pattern node =
  let rec names_of_pattern' names (_, node) =
    match node with
    | Pattern.Object { properties; _ } ->
      let on_property names = function
        | Pattern.Object.Property (_,{ key; pattern; shorthand }) ->
          if shorthand then
            match key with
            | Pattern.Object.Property.Identifier id -> (name_of_identifier id)::names
            | _ -> names
          else
            names_of_pattern' names pattern
        | Pattern.Object.RestProperty (_,{ argument }) ->
          names_of_pattern' names argument
      in
      List.fold_left on_property names properties
    | Pattern.Array { elements; _ } ->
      let on_element names = function
        | None ->
          names
        | Some (Pattern.Array.Element node) ->
          names_of_pattern' names node
        | Some (Pattern.Array.RestElement (_, { argument })) ->
          names_of_pattern' names argument
      in
      List.fold_left on_element names elements
    | Pattern.Assignment { left; _ } ->
      names_of_pattern' names left
    | Pattern.Identifier { name = id; _ } ->
      (name_of_identifier id)::names
    | Pattern.Expression _ ->
      names
  in names_of_pattern' [] node

let rec on_program scope program = 
  let (_, statements, _) = program in
  List.fold_left on_statement scope statements

and on_statement scope ((_, node) as whole_node) =

  let update_scope_with scope (_, node) =
    match node with
    (* Populate scope with bindings *)
    | Statement.ClassDeclaration { id = Some id; _ } ->
      add_block_binding scope (name_of_identifier id)

    | Statement.FunctionDeclaration { id = Some id; _ } ->
      add_block_binding scope (name_of_identifier id)

    | Statement.ImportDeclaration { importKind = Statement.ImportDeclaration.ImportValue; specifiers; _ } ->
      let on_specifier scope = function
        | Statement.ImportDeclaration.ImportDefaultSpecifier id
        | Statement.ImportDeclaration.ImportNamespaceSpecifier (_, id)
        | Statement.ImportDeclaration.ImportNamedSpecifier {
            kind = None;
            local = Some id;
            _
          }
        | Statement.ImportDeclaration.ImportNamedSpecifier {
            kind = Some (Statement.ImportDeclaration.ImportValue);
            local = Some id;
            _
          } ->
          add_block_binding scope (name_of_identifier id)
        | _ -> scope
      in
      List.fold_left on_specifier scope specifiers

    | Statement.VariableDeclaration { declarations; kind } ->
      let on_declaration add_binding scope node =
        let (_, { Statement.VariableDeclaration.Declarator. id; _ }) = node in
        let names = names_of_pattern id in
        List.fold_left add_binding scope names
      in begin
        match kind with
        | Statement.VariableDeclaration.Var ->
          List.fold_left (on_declaration add_func_binding) scope declarations
        | Statement.VariableDeclaration.Let
        | Statement.VariableDeclaration.Const ->
          List.fold_left (on_declaration add_block_binding) scope declarations
      end

    | _ ->
      scope
  in

  let populate_scope ~break_on scope root_node =
    let scope = ref scope in
    let visit_statement node = 
      scope := update_scope_with !scope node;
      if node <> root_node && break_on node
      then Visit.Break
      else Visit.Continue
    in
    let handler = {
      Visit.default_visit_handler with
      visit_statement = visit_statement
    } in
    Visit.visit_statement handler root_node;
    !scope
  in

  (* check if we need to create & populate a new scope *)
  match node with
  | Statement.Block _ ->
    let scope = new_block_scope scope in
    populate_scope ~break_on:block_scope_boundary scope whole_node

  | Statement.ForIn _ ->
    let scope = new_block_scope scope in
    populate_scope ~break_on:block_scope_boundary scope whole_node

  | Statement.ForOf _ ->
    let scope = new_block_scope scope in
    populate_scope ~break_on:block_scope_boundary scope whole_node

  | Statement.FunctionDeclaration _ ->
    let scope = new_func_scope scope in
    populate_scope ~break_on:func_scope_boundary scope whole_node

  (* XXX: This is the case where we can't statically analyze the scope *)
  | Statement.With _ ->
    scope

  (* Return an existing scope *)
  | _ ->
    scope
