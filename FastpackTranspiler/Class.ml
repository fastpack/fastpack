let transpile _context program =
  let module S = Ast.Statement in
  let module E = Ast.Expression in
  let module C = Ast.Class in
  let module F = Ast.Function in
  let module L = Ast.Literal in

  let transpile_class cls =
    let {C. id; body = (_, { body }); _ } = cls in
    let props, rest =
      List.partition
        (fun element ->
           match element with
           | C.Body.Property (_, { static = false; _ }) -> true
           | _ -> false
        )
        body
    in
    let props =
      List.flatten
      @@ List.map
        (fun element ->
           match element with
           | C.Body.Property (_, { static = false; key; value; _ }) ->
             [(key, value)]
           | _ ->
             []
        )
        props
    in
    let move_props_to_constructor props =
      match props with
      | [] -> cls
      | props ->
        let prop_stmts =
          let define_property_stmt (key, value) =
            let key =
              match key with
              | E.Object.Property.Identifier (_, name) ->
                let raw = "\"" ^ name ^ "\"" in
                {L. value = L.String raw; raw }
              | E.Object.Property.Literal (_, lit) ->
                lit
              | E.Object.Property.Computed _ ->
                failwith "Computed properties are not supported here"
            in
            let value =
              match value with
              | Some (_, value) -> value
              | None -> E.Unary {
                  operator = E.Unary.Void;
                  prefix = true;
                  argument = (Loc.none,
                              E.Literal {L. value = Number 0.0; raw = "0"})
                }
            in
            let callee =
              (Loc.none,
               E.Member {
                 _object = (Loc.none, E.Identifier (Loc.none, "Object"));
                 property = E.Member.PropertyIdentifier (Loc.none,
                                                         "defineProperty");
                 computed = false;
               }
              )
            in
            let prop name lit =
              let raw = "\"" ^ name ^ "\"" in
              E.Object.Property (Loc.none, {
                key = E.Object.Property.Literal (
                    Loc.none, {L. value = L.String raw; raw }
                );
                value = E.Object.Property.Init (Loc.none, lit);
                _method = false;
                shorthand = false
              });
            in
            let true_prop name =
              prop name (E.Literal {L. value = L.Boolean true; raw = "true"})
            in
            let arguments = [
              E.Expression (Loc.none, E.This);
              E.Expression (Loc.none, E.Literal key);
              E.Expression (Loc.none, E.Object {
                properties=[
                  true_prop "configurable";
                  true_prop "enumerable";
                  true_prop "writable";
                  prop "value" value;
                ]
              })
            ]
            in
            (Loc.none,
             S.Expression {
               expression = ( Loc.none, E.Call { callee; arguments; });
               directive = None;
             }
            )
          in
          List.map define_property_stmt props
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
            let body =
              match value.body with
              | F.BodyBlock (body_loc, { body }) ->
                F.BodyBlock (body_loc, { body = prop_stmts @ body })
              | F.BodyExpression expr ->
                F.BodyBlock (Loc.none, {
                  body = prop_stmts
                         @ [(Loc.none, S.Return {argument = Some expr})]
                })
            in
            (i, i + 1, C.Body.Method (
                c_loc,
                { constructor with
                  value = (value_loc, { value with body })
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
    (move_props_to_constructor props, id, [], [])
  in

  let map_expression ((loc, node) : E.t) =
    (loc, node)
  in

  let map_statement ((loc, stmt) : S.t) =
    match stmt with
    | S.ClassDeclaration cls ->
      let cls, _, _, _ = transpile_class cls in
      (loc, S.ClassDeclaration cls)
    | _ -> (loc, stmt)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_statement;
    map_expression;
  } in

  AstMapper.map mapper program

