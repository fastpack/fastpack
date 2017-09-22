let transpile _context program =
  let map_function _scope (loc, func) : (Loc.t * Ast.Function.t) =
    (loc,
     { func with
       predicate = None;
       returnType = None;
       typeParameters = None;
     })
  in

  let map_pattern _scope (loc, pattern) : Ast.Pattern.t =
    let module P = Ast.Pattern in
    let pattern =
      match pattern with
      | P.Object obj -> P.Object { obj with typeAnnotation = None}
      | P.Array arr -> P.Array { arr with typeAnnotation = None }
      | P.Identifier ident ->
        P.Identifier { ident with typeAnnotation = None; optional = false }
      | node -> node
    in
    (loc, pattern)
  in

  let map_class (cls : Ast.Class.t) =
    let module C = Ast.Class in
    let (body_loc, {C.Body. body}) = cls.body in
    let body =
      List.map
        (fun el ->
           match el with
           | C.Body.Property (loc, prop) ->
             C.Body.Property (loc, {
                 prop with
                 typeAnnotation = None;
                 variance = None;
             })
           | node -> node
        )
      body
    in
    { cls with
      typeParameters = None;
      superTypeParameters = None;
      implements = [];
      body=(body_loc, {C.Body. body})
    }
  in

  let map_expression _scope ((loc, node) : Ast.Expression.t) =
    let module E = Ast.Expression in
    let node =
      match node with
      | E.TypeCast { expression = (_, expression); _ } -> expression
      | E.Class cls -> E.Class (map_class cls)
      | _ -> node
    in
    (loc, node)
  in

  let map_statement _scope ((loc, stmt) : Ast.Statement.t) =
    let module S = Ast.Statement in
    let stmt =
      match stmt with
      | S.ClassDeclaration cls ->
        S.ClassDeclaration (map_class cls)
      | S.ImportDeclaration ({
          importKind = S.ImportDeclaration.ImportValue;
          specifiers = (_ :: _) as specifiers; _
        } as import_decl) ->
        let specifiers =
          List.filter
            (fun spec ->
               match spec with
               | S.ImportDeclaration.ImportNamedSpecifier {
                   kind = Some S.ImportDeclaration.ImportType; _ }
               | S.ImportDeclaration.ImportNamedSpecifier {
                   kind = Some S.ImportDeclaration.ImportTypeof; _ } -> false
               | _ -> true
            )
            specifiers
        in
        begin
          match (List.length specifiers) with
          | 0 -> S.Empty;
          | _ -> S.ImportDeclaration { import_decl with specifiers; }
        end
      | S.ImportDeclaration { importKind = S.ImportDeclaration.ImportType; _ }
      | S.ImportDeclaration { importKind = S.ImportDeclaration.ImportTypeof; _ }
      | S.DeclareModule _
      | S.DeclareExportDeclaration _
      | S.DeclareVariable _
      | S.DeclareFunction _
      | S.DeclareClass _
      | S.InterfaceDeclaration _
      | S.DeclareModuleExports _
      | S.ExportNamedDeclaration _
      | S.ExportDefaultDeclaration _
      | S.TypeAlias _ ->
        S.Empty
      | node -> node
    in
    (loc, stmt)
  in

  let mapper = {
    AstMapper.
    map_statement;
    map_expression;
    map_function;
    map_pattern;
  } in

  AstMapper.map mapper program
