module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;

let transpile = (_context, program, modified) => {
  let map_function =
      (_scope, (loc, func)): (Loc.t, Ast.Function.t(Loc.t, Loc.t)) => (
    Ast.Function.(
      func.predicate != None || func.return != None || func.tparams != None
    ) ?
      Loc.none : loc,
    {...func, predicate: None, return: None, tparams: None},
  );

  let map_pattern = (_scope, (loc, pattern)): Ast.Pattern.t(Loc.t, Loc.t) => {
    module P = Ast.Pattern;
    let (modified, pattern) =
      switch (pattern) {
      | P.Object(obj) => (obj.annot != None, P.Object({...obj, annot: None}))
      | P.Array(arr) => (arr.annot != None, P.Array({...arr, annot: None}))
      | P.Identifier(ident) => (
          ident.annot != None || ident.optional,
          P.Identifier({...ident, annot: None, optional: false}),
        )
      | node => (false, node)
      };

    (modified ? Loc.none : loc, pattern);
  };

  let map_class = (loc: Loc.t, cls: Ast.Class.t(Loc.t, Loc.t)) => {
    module C = Ast.Class;
    let (body_loc, {C.Body.body}) = cls.body;
    let modified = ref(false);
    let body =
      CCList.filter_map(
        el =>
          switch (el) {
          | C.Body.Property((
              loc,
              {value, annot, static, variance, _} as prop,
            )) =>
            /* this strips away properties declared only as type annotations */
            if (!static && value == None && (annot != None || variance != None)) {
              modified := true;
              None;
            } else {
              modified :=
                modified^ || prop.annot != None || prop.variance != None;
              Some(
                C.Body.Property((
                  loc,
                  {...prop, annot: None, variance: None},
                )),
              );
            }
          | node => Some(node)
          },
        body,
      );

    modified :=
      modified^ || cls.tparams != None || List.length(cls.implements) > 0;
    (
      modified^ ? Loc.none : loc,
      {
        ...cls,
        tparams: None,
        implements: [],
        extends:
          switch (cls.extends) {
          | None => None
          | Some((loc, {C.Extends.expr, targs})) =>
            modified := modified^ || targs != None;
            Some((loc, {C.Extends.expr, targs: None}));
          },
        body: (body_loc, {C.Body.body: body}),
      },
    );
  };

  let map_expression = (_scope, (loc, node): Ast.Expression.t(Loc.t, Loc.t)) => {
    module E = Ast.Expression;
    switch (node) {
    | E.TypeCast({expression: (_, expression), _}) => (Loc.none, expression)
    | E.Class(cls) =>
      let (loc, cls) = map_class(loc, cls);
      (loc, E.Class(cls));
    | _ => (loc, node)
    };
  };

  let map_statement = (_scope, (loc, stmt): Ast.Statement.t(Loc.t, Loc.t)) => {
    module S = Ast.Statement;
    let stmt =
      switch (stmt) {
      | S.ClassDeclaration(cls) =>
        let (loc, cls) = map_class(loc, cls);
        (loc, S.ClassDeclaration(cls));
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

        (
          Loc.none,
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
          },
        );
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
      | S.OpaqueType(_) => (Loc.none, S.Empty)
      | node => (loc, node)
      };

    [stmt];
  };

  let mapper = {
    FastpackUtil.AstMapper.map_statement,
    map_expression,
    map_function,
    map_pattern,
  };

  FastpackUtil.AstMapper.map(~modified, mapper, program);
};
