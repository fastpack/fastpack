module Ast = FlowParser.Ast
module Loc = FlowParser.Loc

let transpile _context program =
  let map_function _scope (loc, func) : (Loc.t * Loc.t Ast.Function.t) =
    (loc,
     { func with
       predicate = None;
       returnType = None;
       typeParameters = None;
     })
  in

  let map_pattern _scope (loc, pattern) : Loc.t Ast.Pattern.t =
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

  let map_class (cls : Loc.t Ast.Class.t) =
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

  let map_expression _scope ((loc, node) : Loc.t Ast.Expression.t) =
    let module E = Ast.Expression in
    let node =
      match node with
      | E.TypeCast { expression = (_, expression); _ } -> expression
      | E.Class cls -> E.Class (map_class cls)
      | _ -> node
    in
    (loc, node)
  in

  let map_statement _scope ((loc, stmt) : Loc.t Ast.Statement.t) =
    let module S = Ast.Statement in
    let stmt =
      match stmt with
      | S.ClassDeclaration cls ->
        S.ClassDeclaration (map_class cls)
      | S.ImportDeclaration ({
          importKind = S.ImportDeclaration.ImportValue;
          specifiers = Some (S.ImportDeclaration.ImportNamedSpecifiers specifiers);
          default;
          _;
        } as import_decl) ->
        let specifiers =
          List.filter
            (fun {S.ImportDeclaration. kind; _ } ->
               match kind with
               | Some S.ImportDeclaration.ImportTypeof
               | Some S.ImportDeclaration.ImportType -> false
               | _ -> true
            )
            specifiers
        in
        begin
          match default, specifiers with
          | None, [] -> S.Empty;
          | Some _, [] ->
            S.ImportDeclaration {
              import_decl with
              specifiers = None
            }
          | _ ->
            S.ImportDeclaration {
              import_decl with
              specifiers = Some (S.ImportDeclaration.ImportNamedSpecifiers specifiers);
            }
        end
      | S.ImportDeclaration { importKind = S.ImportDeclaration.ImportType; _ }
      | S.ImportDeclaration { importKind = S.ImportDeclaration.ImportTypeof; _ }
      | S.ExportNamedDeclaration { exportKind = S.ExportType; _ }
      | S.DeclareModule _
      | S.DeclareExportDeclaration _
      | S.DeclareVariable _
      | S.DeclareFunction _
      | S.DeclareClass _
      | S.InterfaceDeclaration _
      | S.DeclareModuleExports _
      | S.TypeAlias _
      | S.DeclareInterface _
      | S.DeclareTypeAlias _
      | S.DeclareOpaqueType _
      | S.OpaqueType _ ->
        S.Empty
      | node -> node
    in
    (loc, stmt)
  in

  let mapper = {
    FastpackUtil.AstMapper.
    map_statement;
    map_expression;
    map_function;
    map_pattern;
  } in

  FastpackUtil.AstMapper.map mapper program
