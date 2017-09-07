let transpile _context program =
  let map_expression _scope ((loc, node) : Ast.Expression.t) =
    let module E = Ast.Expression in
    let module I = Ast.Identifier in
    let open Ast.JSX in

    (** Transpile JSX elememnt name *)
    let transpile_name (name : name) =
      let aux_property ((loc, { name }) : Identifier.t) =
        (loc, name)
      in
      let rec aux_object (_object : MemberExpression._object) =
        match _object with
        | MemberExpression.Identifier (loc, { name }) ->
          E.Identifier (loc, name)
        | MemberExpression.MemberExpression (loc, { _object; property }) ->
          E.Member {
            _object = loc, aux_object _object;
            property = E.Member.PropertyIdentifier (aux_property property);
            computed = false;
          }
      in

      match name with
      | Identifier (loc, { name }) ->
        E.Expression (loc, E.Identifier (loc, name))
      | MemberExpression (loc, { _object; property }) ->
        E.Expression (loc, E.Member {
            _object = Loc.none, aux_object _object;
            property = E.Member.PropertyIdentifier (aux_property property);
            computed = false;
          })
      | NamespacedName _ ->
        failwith "Namespaced tags are not supported. ReactJSX is not XML"
    in

    (** Transpile JSX attributes *)
    let transpile_attributes (attributes : Opening.attribute list) =

      let null_expression =
        Loc.none, E.Literal { value = Ast.Literal.Null; raw = "null"; }
      in

      let empty_object_literal =
        Loc.none, E.Object { properties = [] }
      in

      let object_assign arguments =
        Loc.none, E.Call {
          callee = Loc.none, E.Member {
              computed = false;
              _object = Loc.none, E.Identifier (Loc.none, "Object");
              property = E.Member.PropertyIdentifier (Loc.none, "assign");
            };
          arguments = (E.Expression empty_object_literal)::(List.rev arguments)
        }
      in

      match attributes with
      (** If no attributes present we pass null *)
      | [] -> E.Expression null_expression
      | attributes ->
        let add_to_expressions bucket expressions =
          match bucket with
          | [] -> expressions
          | properties ->
            let expr = (Loc.none, E.Object { properties = List.rev properties }) in
            (`Expression expr)::expressions
        in
        let bucket, expressions = List.fold_left
            (fun (bucket, expressions) (attr : Opening.attribute) ->
               match attr with
               | Opening.Attribute (loc, { name; value }) ->
                 let key = match name with
                   | Attribute.Identifier (loc, { name }) ->
                     E.Object.Property.Literal (loc, { value = Ast.Literal.String name; raw = name })
                   | Attribute.NamespacedName _ ->
                     failwith "Namespaced tags are not supported. ReactJSX is not XML"
                 in
                 let value = match value with
                   | None ->
                     null_expression
                   | Some (Attribute.Literal (loc, lit)) ->
                     loc, E.Literal lit
                   | Some (Attribute.ExpressionContainer (_loc, { expression = ExpressionContainer.Expression expr })) ->
                     expr
                   | Some (Attribute.ExpressionContainer (_loc, { expression = ExpressionContainer.EmptyExpression _ })) ->
                     failwith "Found EmptyExpression container"
                 in
                 let prop = E.Object.Property (
                     loc,
                     { key; value = E.Object.Property.Init value; _method = false; shorthand = false }
                   ) in
                 (prop::bucket, expressions)
               | Opening.SpreadAttribute (_loc, { argument }) ->
                 let expressions = add_to_expressions bucket expressions in
                 let spread = `Spread argument in
                 ([], spread::expressions))
            ([], [])
            attributes
        in
        let expressions = expressions |> add_to_expressions bucket in
        match expressions with
        | [] -> E.Expression null_expression
        | [`Spread expr] -> E.Expression (object_assign [E.Expression expr])
        | [`Expression expr] -> E.Expression expr
        | items ->
          let items =
            items
            |> List.map (function
                | `Spread expr -> E.Expression expr
                | `Expression expr -> E.Expression expr
              )
          in
          E.Expression (object_assign items)
    in

    let rec transpile_children children =
      let trim_text text =
        (** TODO: Lookup how babel does this as there are some subtle nuances *)
        let is_not_empty_line line =
          String.trim line <> ""
        in
        text
        |> String.split_on_char '\n'
        |> List.filter is_not_empty_line
        |> String.concat " "
      in
      let transpile_child ((loc, child) : child) =
        let expr = match child with
          | Element element ->
            (loc, transpile_element element)
          | ExpressionContainer { expression = ExpressionContainer.Expression expression } ->
            expression
          | ExpressionContainer { expression = ExpressionContainer.EmptyExpression _ } ->
            failwith "Found EmptyExpression container"
          | Text { value; raw } ->
            let raw = trim_text raw in
            (loc, E.Literal { value = Ast.Literal.String value; raw = ("'" ^ raw ^ "'"); })
        in
        E.Expression expr
      in
      List.map transpile_child children

    and transpile_element { openingElement = (_, openingElement); children; _ } =
      let { Opening. name; attributes; _ } = openingElement in
      E.Call {
        callee = Loc.none, E.Member {
            computed = false;
            _object = Loc.none, E.Identifier (Loc.none, "React");
            property = E.Member.PropertyIdentifier (Loc.none, "createElement");
          };
        arguments = (transpile_name name)::(transpile_attributes attributes)::(transpile_children children)
      }
    in

    let node = match node with
      | E.JSXElement element ->
        transpile_element element
      | node -> node
    in
    (loc, node)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_expression;
  } in

  AstMapper.map mapper program
