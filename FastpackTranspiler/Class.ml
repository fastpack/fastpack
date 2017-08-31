module S = Ast.Statement
module E = Ast.Expression
module C = Ast.Class
module F = Ast.Function
module L = Ast.Literal
open AstHelper

module Helper = struct

  let op_key_to_literal key =
    match key with
    | E.Object.Property.Identifier (_, name) ->
      literal_str name
    | E.Object.Property.Literal (_, lit) ->
      lit
    | E.Object.Property.Computed _ ->
      failwith "Computed properties are not supported here"

  let op_value_to_expr value =
    match value with
    | Some (_, value) -> Loc.none, value
    | None -> void_0

end

module Transform = struct

  let transform_class cls =
    let {C. id; body = (_, { body }); _ } = cls in
    let props, rest =
      List.partition
        (fun element ->
           match element with
           | C.Body.Property _ -> true
           | _ -> false
        )
        body
    in
    let props, statics =
      List.partition_map
        (fun element ->
           match element with
           | C.Body.Property (_, { static; key; value; _ }) ->
             if static
             then `Right (key, value)
             else `Left (key, value)
           | _ ->
             `Drop
        )
        props
    in

    let move_props_to_constructor props =
      match props with
      | [] -> cls
      | props ->
        let prop_stmts =
          props
          |> List.map
            (fun (key, value) ->
              (Loc.none, S.Expression {
                 expression = object_define_property
                     (Helper.op_key_to_literal key)
                     (Helper.op_value_to_expr value);
               directive = None;
              })
            )
        in
        let insert_after_super stmts =
          let take, drop =
            stmts
            |> List.take_drop_while
              (fun stmt ->
                 match stmt with
                 | (_, S.Expression {
                     expression=(_, E.Call { callee = (_, E.Super); _ }); _
                   }) ->
                   false
                 | _ -> true
              )
          in
          match drop with
          | [] -> prop_stmts @ take
          | super :: rest -> take @ (super :: prop_stmts) @ rest
        in
        let constructor =
          List.head_opt
          @@ List.filter
            (fun (_, el) ->
               match el with
               | C.Body.Method (_, { kind = C.Method.Constructor; _}) -> true
               | _ -> false
            )
          @@ List.mapi (fun index el -> (index, el)) rest
        in
        let (take, drop, constructor) =
          match constructor with
          | Some (i, C.Body.Method (c_loc, ({
              value = (value_loc, value); _
            } as constructor))) ->
            let body_loc, body =
              match value.body with
              | F.BodyBlock (body_loc, { body }) -> body_loc, body
              | F.BodyExpression expr -> Loc.none, [return expr]
            in
            (i, i + 1, C.Body.Method (
                c_loc,
                { constructor with
                  value = (value_loc, {
                      value with
                      body = F.BodyBlock (body_loc, {
                          body = insert_after_super body
                      })
                    })
                }
            ))
          | None ->
            (0, 0, C.Body.Method (
                Loc.none, {
                  kind = C.Method.Constructor;
                  static = false;
                  decorators = [];
                  key = E.Object.Property.Identifier (Loc.none,
                                                      "constructor");
                  value = (Loc.none, {
                      id = None;
                      params = ([], None);
                      body = F.BodyBlock (Loc.none, { body = prop_stmts });
                      async = false;
                      generator = false;
                      predicate = None;
                      expression = false;
                      returnType = None;
                      typeParameters = None;
                  })
                }))
          | _ -> failwith "Only constructor is expected here"
        in
        let (body_loc, _) = cls.body in
        let body = List.take take rest @ [constructor] @ List.drop drop rest in
        { cls with
          body = (body_loc, { body })
        }
    in
    (move_props_to_constructor props, id, statics, [])

  let wrap_class cls statics =
    let statics =
      statics
      |> to_array
        (fun (key, value) ->
           object_ [
             object_property "name"
               (Loc.none, E.Literal (Helper.op_key_to_literal key));
             object_property "value" (Helper.op_value_to_expr value)
           ]
        )
    in
    fpack_define_class cls statics

end

let transpile _context program =

  let map_expression ((loc, node) : E.t) =
    (loc, node)
  in

  let map_statement ((loc, stmt) : S.t) =
    match stmt with
    | S.ClassDeclaration cls ->
      begin
        match Transform.transform_class cls with
        | cls, _, [], [] ->
          (loc, S.ClassDeclaration cls)
        | cls, Some (_, name), statics, _ ->
          let_stmt loc name (Transform.wrap_class cls statics)
        | _ -> failwith "should not happen"
      end
    | _ -> (loc, stmt)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_statement;
    map_expression;
  } in

  AstMapper.map mapper program

