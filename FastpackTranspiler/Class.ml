let transpile _context program =
  let map_expression ((loc, node) : Ast.Expression.t) =
    (loc, node)
  in

  let map_statement ((loc, stmt) : Ast.Statement.t) =
    (loc, stmt)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_statement;
    map_expression;
  } in

  AstMapper.map mapper program

