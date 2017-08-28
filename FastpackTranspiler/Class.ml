let transpile _context program =
  let module S = Ast.Statement in
  let module E = Ast.Expression in
  let module C = Ast.Class in

  let transpile_class cls =
    let {C. id; body = (_, { body }); _ } = cls in
    let props =
      List.filter
        (fun element ->
           match element with
           | C.Body.Property (_, { static = false; _ }) -> true
           | _ -> false
        )
        body
    in
    let move_props_to_constructor props =
      match props with
      | [] -> cls
      | _ -> cls
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

