module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module C = Ast.Class;
module F = Ast.Function;
module L = Ast.Literal;

module AstMapper = FastpackUtil.AstMapper;
module AstHelper = FastpackUtil.AstHelper;
module APS = FastpackUtil.AstParentStack;
module Scope = FastpackUtil.Scope;

type transpiledClass = {
  name: string,
  func: F.t(Loc.t, Loc.t),
};

type classInfo = {
  constructor: option(F.t(Loc.t, Loc.t)),
  props: list(string),
};

let emptyClassInfo = {constructor: None, props: []};

let transpile = (ctx: Context.t, program, modified) => {
  let getClassInfo = ({body: (_, {body}), _}: C.t(Loc.t, Loc.t)) =>
    List.fold_left(
      (info, element) =>
        switch (element) {
        | C.Body.Method((
            _,
            {kind: Constructor, value: (_, f), static: false, _},
          )) => {
            ...info,
            constructor: Some(f),
          }
        | C.Body.Method(_) => info
        | C.Body.Property(_) => info
        | C.Body.PrivateField(_) => info
        },
      emptyClassInfo,
      body,
    );

  let transpileClass = (scope: Scope.t, {id, _} as cls: C.t(Loc.t, Loc.t)) => {
    let name =
      switch (id) {
      | None => ctx.gen_binding(scope)
      | Some((_, name)) => name
      };
    let classInfo = getClassInfo(cls);
    {
      name,
      func: {
        F.id: None,
        params: (Loc.none, {params: [], rest: None}),
        body: BodyBlock((Loc.none, {body: []})),
        async: false,
        generator: false,
        predicate: None,
        expression: false,
        return: None,
        tparams: None,
      },
    };
  };

  let map_statement =
      ({AstMapper.parents, scope, _}, (loc, stmt): S.t(Loc.t, Loc.t)) =>
    switch (stmt) {
    | S.ExportDefaultDeclaration(
        {
          declaration:
            S.ExportDefaultDeclaration.Declaration((
              _,
              S.ClassDeclaration({id: Some(_), _} as cls),
            )),
          _,
        } as export,
      ) =>
      ctx.require_runtime();
      let {name, func} = transpileClass(scope, cls);
      [
        AstHelper.(
          const_stmt(name, call((Loc.none, E.Function(func)), []))
        ),
        (
          Loc.none,
          S.ExportDefaultDeclaration({
            ...export,
            declaration:
              S.ExportDefaultDeclaration.Expression(
                AstHelper.e_identifier(name),
              ),
          }),
        ),
      ];

    | S.ClassDeclaration(cls) =>
      switch (APS.top_statement(parents)) {
      | Some((
          _,
          S.ExportDefaultDeclaration({
            declaration:
              S.ExportDefaultDeclaration.Declaration((
                _,
                S.ClassDeclaration({id: Some(_), _}),
              )),
            _,
          }),
        )) => [
          (loc, stmt),
        ]
      | _ =>
        ctx.require_runtime();
        let {name, func} = transpileClass(scope, cls);
        [
          AstHelper.(
            const_stmt(name, call((Loc.none, E.Function(func)), []))
          ),
        ];
      }
    | _ => [(loc, stmt)]
    };

  let mapper = {...AstMapper.default_mapper, map_statement};

  AstMapper.map(~modified, mapper, program);
};
