let transpile _context program =
  let map_expression ((loc, node) : Ast.Expression.t) =
    let module E = Ast.Expression in
    let node =
      match node with
      | E.TypeCast { expression = (_, expression); _ } -> expression
      | _ -> node
    in
    (loc, node)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_expression;
  } in

  AstMapper.map mapper program
