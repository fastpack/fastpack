module Ast = FlowParser.Ast
module Loc = FlowParser.Loc

module E = Ast.Expression
module I = Ast.Identifier

module AstMapper = FastpackUtil.AstMapper

let transpile _ program =

  let null_expression =
    Loc.none, E.Literal { value = Ast.Literal.Null; raw = "null"; }
  in

  let true_expression =
    Loc.none, E.Literal (FastpackUtil.AstHelper.literal_true)
  in

  let map_expression context ((loc, node) : Loc.t Ast.Expression.t) =
    let open Ast.JSX in

    (** Transpile JSX elememnt name *)
    let transpile_name (name : Loc.t name) =
      let aux_property ((loc, { name }) : Loc.t Identifier.t) =
        (loc, name)
      in
      let rec aux_object (_object : Loc.t MemberExpression._object) =
        match _object with
        | MemberExpression.Identifier (loc, { name }) ->
          E.Identifier (loc, name)
        | MemberExpression.MemberExpression (loc, { _object; property }) ->
          E.Member {
            _object = loc, aux_object _object;
            property = E.Member.PropertyIdentifier (aux_property property);
            computed = false;
            optional = false;
          }
      in

      match name with
      | Identifier (loc, { name }) ->
        if Str.string_match (Str.regexp "^[A-Z]") name 0
        then E.Expression (loc, E.Identifier (loc, name))
        else E.Expression (FastpackUtil.AstHelper.e_literal_str name)
      | MemberExpression (loc, { _object; property }) ->
        E.Expression (loc, E.Member {
            _object = Loc.none, aux_object _object;
            property = E.Member.PropertyIdentifier (aux_property property);
            computed = false;
            optional = false;
          })
      | NamespacedName (loc, _) ->
        raise (Error.TranspilerError (
          loc, "Namespaced tags are not supported. ReactJSX is not XML"))
    in

    (** Transpile JSX attributes *)
    let transpile_attributes (attributes : Loc.t Opening.attribute list) =

      let empty_object_literal =
        Loc.none, E.Object { properties = [] }
      in

      let object_assign arguments =
        Loc.none, E.Call {
          callee = Loc.none, E.Member {
              computed = false;
              _object = Loc.none, E.Identifier (Loc.none, "Object");
              property = E.Member.PropertyIdentifier (Loc.none, "assign");
              optional = false;
            };
          arguments = (E.Expression empty_object_literal)::(List.rev arguments);
          optional = false;
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
            (fun (bucket, expressions) (attr : Loc.t Opening.attribute) ->
               match attr with
               | Opening.Attribute (loc, { name; value }) ->
                 let key = match name with
                   | Attribute.Identifier (loc, { name }) ->
                     E.Object.Property.Literal (loc, {
                         value = Ast.Literal.String name;
                         raw = "\"" ^ name ^ "\""
                       })
                   | Attribute.NamespacedName (loc, _) ->
                     raise (Error.TranspilerError (
                       loc,
                        "Namespaced tags are not supported. ReactJSX is not XML"
                     ))
                 in
                 let value = match value with
                   | None ->
                     true_expression
                   | Some (Attribute.Literal (loc, {value; raw})) ->
                     loc, E.Literal {
                       value;
                       raw = raw
                             |> String.split_on_char '\n'
                             |> List.map String.trim
                             |> String.concat "\\n"
                     }
                   | Some (Attribute.ExpressionContainer (_loc, { expression = ExpressionContainer.Expression expr })) ->
                     AstMapper.map_expression context expr
                   | Some (Attribute.ExpressionContainer (loc, { expression = ExpressionContainer.EmptyExpression _ })) ->
                     raise (Error.TranspilerError (
                       loc,
                       "Found EmptyExpression container"
                     ))
                 in
                 let prop = E.Object.Property (
                     loc, E.Object.Property.Init { key; value; shorthand = false }
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
        let is_not_empty_line line =
          String.trim line <> ""
        in
        text
        |> String.split_on_char '\n'
        |> List.filter is_not_empty_line
        |> String.concat " "
      in
      let transpile_child ((loc, child) : Loc.t child) =
        let expr = match child with
          | Element element ->
            (loc, transpile_element element)
          | ExpressionContainer { expression = ExpressionContainer.Expression expression } ->
            AstMapper.map_expression context expression
          | ExpressionContainer { expression = ExpressionContainer.EmptyExpression _ } ->
            raise (Error.TranspilerError (
              loc,
              "Found EmptyExpression container"
            ))
          | Text { value; raw } ->
            let raw = trim_text raw in
            (loc, E.Literal {
                value = Ast.Literal.String value;
                raw = ("'" ^ String.replace ~sub:"'" ~by:"\\'" raw ^ "'");
              })
          | Fragment fragment ->
            (loc, transpile_fragment fragment)
          | SpreadChild _ ->
            raise (Error.TranspilerError (
              loc,
              "SpreadChild are not implemented"
            ))
        in
        E.Expression expr
      in
      children
      |> List.map transpile_child
      |> List.filter
        (fun child ->
          match child with
          | E.Expression (_, E.Literal { raw = "''"; _ }) -> false
          | _ -> true
        )

    and transpile_element { openingElement = (_, openingElement); children; _ } =
      let { Opening. name; attributes; _ } = openingElement in
      E.Call {
        callee = Loc.none, E.Member {
            computed = false;
            _object = Loc.none, E.Identifier (Loc.none, "React");
            property = E.Member.PropertyIdentifier (Loc.none, "createElement");
            optional = false;
          };
        arguments = (transpile_name name)::(transpile_attributes attributes)::(transpile_children children);
        optional = false;
      }

    and transpile_fragment { frag_openingElement = _; frag_closingElement = _; frag_children } =
      let elements =
        frag_children
        |> transpile_children
      in

      let name = E.Expression (loc, E.Member {
          _object = Loc.none, E.Identifier (Loc.none, "React");
          property = E.Member.PropertyIdentifier (Loc.none, "Fragment");
          computed = false;
          optional = false;
        })
      in

      E.Call {
        callee = Loc.none, E.Member {
            computed = false;
            _object = Loc.none, E.Identifier (Loc.none, "React");
            property = E.Member.PropertyIdentifier (Loc.none, "createElement");
            optional = false;
          };
        arguments = name::(E.Expression null_expression)::elements;
        optional = false;
      }
    in

    let node = match node with
      | E.JSXElement element ->
        transpile_element element
      | E.JSXFragment fragment ->
        transpile_fragment fragment
      | node -> node
    in
    (loc, node)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_expression;
  } in

  AstMapper.map mapper program
