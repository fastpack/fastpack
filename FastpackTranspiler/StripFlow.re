module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;

let transpile = (_context, program) => {
  let map_function = (_scope, (loc, func)): (Loc.t, Ast.Function.t(Loc.t)) => (
    loc,
    {...func, predicate: None, returnType: None, typeParameters: None},
  );

  let map_pattern = (_scope, (loc, pattern)): Ast.Pattern.t(Loc.t) => {
    module P = Ast.Pattern;
    let pattern =
      switch (pattern) {
      | P.Object(obj) => P.Object({...obj, typeAnnotation: None})
      | P.Array(arr) => P.Array({...arr, typeAnnotation: None})
      | P.Identifier(ident) =>
        P.Identifier({...ident, typeAnnotation: None, optional: false})
      | node => node
      };

    (loc, pattern);
  };

  let map_class = (cls: Ast.Class.t(Loc.t)) => {
    module C = Ast.Class;
    let (body_loc, {C.Body.body}) = cls.body;
    let body =
      List.filter_map(
        el =>
          switch (el) {
          | C.Body.Property((
              loc,
              {value, typeAnnotation, static, variance, _} as prop,
            )) =>
            /* this strips away properties declared only as type annotations */
            if (!static
                && value == None
                && (typeAnnotation != None || variance != None)) {
              None;
            } else {
              Some(
                C.Body.Property((
                  loc,
                  {...prop, typeAnnotation: None, variance: None},
                )),
              );
            }
          | node => Some(node)
          },
        body,
      );

    {
      ...cls,
      typeParameters: None,
      superTypeParameters: None,
      implements: [],
      body: (body_loc, {C.Body.body: body}),
    };
  };

  let map_expression = (_scope, (loc, node): Ast.Expression.t(Loc.t)) => {
    module E = Ast.Expression;
    let node =
      switch (node) {
      | E.TypeCast({expression: (_, expression), _}) => expression
      | E.Class(cls) => E.Class(map_class(cls))
      | _ => node
      };

    (loc, node);
  };

  let map_statement = (_scope, (loc, stmt): Ast.Statement.t(Loc.t)) => {
    module S = Ast.Statement;
    let stmt =
      switch (stmt) {
      | S.ClassDeclaration(cls) => S.ClassDeclaration(map_class(cls))
      | S.ImportDeclaration(
          {
            importKind: S.ImportDeclaration.ImportValue,
            specifiers:
              Some(S.ImportDeclaration.ImportNamedSpecifiers(specifiers)),
            default,
            _,
          } as import_decl,
        ) =>
        let specifiers =
          List.filter(
            ({S.ImportDeclaration.kind, _}) =>
              switch (kind) {
              | Some(S.ImportDeclaration.ImportTypeof)
              | Some(S.ImportDeclaration.ImportType) => false
              | _ => true
              },
            specifiers,
          );

        switch (default, specifiers) {
        | (None, []) => S.Empty
        | (Some(_), []) =>
          S.ImportDeclaration({...import_decl, specifiers: None})
        | _ =>
          S.ImportDeclaration({
            ...import_decl,
            specifiers:
              Some(S.ImportDeclaration.ImportNamedSpecifiers(specifiers)),
          })
        };
      | S.ImportDeclaration({importKind: S.ImportDeclaration.ImportType, _})
      | S.ImportDeclaration({importKind: S.ImportDeclaration.ImportTypeof, _})
      | S.ExportNamedDeclaration({exportKind: S.ExportType, _})
      | S.DeclareModule(_)
      | S.DeclareExportDeclaration(_)
      | S.DeclareVariable(_)
      | S.DeclareFunction(_)
      | S.DeclareClass(_)
      | S.InterfaceDeclaration(_)
      | S.DeclareModuleExports(_)
      | S.TypeAlias(_)
      | S.DeclareInterface(_)
      | S.DeclareTypeAlias(_)
      | S.DeclareOpaqueType(_)
      | S.OpaqueType(_) => S.Empty
      | node => node
      };

    [(loc, stmt)];
  };

  let mapper = {
    FastpackUtil.AstMapper.map_statement,
    map_expression,
    map_function,
    map_pattern,
  };

  FastpackUtil.AstMapper.map(mapper, program);
};
