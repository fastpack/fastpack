module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module C = Ast.Class;
module F = Ast.Function;
module L = Ast.Literal;

module AstMapper = FastpackUtil.AstMapper;
module AstHelper = FastpackUtil.AstHelper;
module APS = FastpackUtil.AstParentStack;
open FastpackUtil.AstHelper;

let helperName = "defineClass";
TranspilerRuntimeHelpers.register(
  helperName,
  {|
  function applyDecorator(decorator, proto, property, descriptor) {
    var ret = decorator(proto, property, descriptor);
    // TODO: assert all descriptor properties;
    return ret;
  }

  function decorateProperty(cls, property, decorators) {
    var proto = cls.prototype;
    var descriptor = Object.assign(
      {},
      Object.getOwnPropertyDescriptor(proto, property)
    );

    for (
      var i = 0, reversed = decorators.reverse(), l = reversed.length;
      i < l;
      i++
    ) {
      descriptor = applyDecorator(reversed[i], proto, property, descriptor);
    }

    Object.defineProperty(proto, property, descriptor);
  }

  function defineClass(cls, statics, classDecorators, propertyDecorators) {
    for (var i = 0, l = propertyDecorators.length; i < l; i++) {
      decorateProperty(
        cls,
        propertyDecorators[i].method,
        propertyDecorators[i].decorators
      );
    }

    for (var i = 0, l = statics.length; i < l; i++) {
      Object.defineProperty(cls, statics[i].name, {
        configurable: true,
        enumerable: true,
        writable: true,
        value: statics[i].value
      });
    }

    var _cls = cls;
    classDecorators = classDecorators.reverse();
    for (var i = 0; i < classDecorators.length; i++) {
      _cls = classDecorators[i](_cls);
    }
    return _cls;
  }

  module.exports = defineClass;
|},
);

module Helper = {
  let op_key_to_literal = key =>
    switch (key) {
    | E.Object.Property.Identifier((_, name)) => literal_str(name)
    | E.Object.Property.Literal((_, lit)) => lit
    | E.Object.Property.PrivateName((loc, _)) =>
      raise(
        Error.TranspilerError((loc, "PrivateName is not implemented yet")),
      )
    | E.Object.Property.Computed((loc, _)) =>
      raise(
        Error.TranspilerError((
          loc,
          "Computed properties are not supported here",
        )),
      )
    };

  let op_value_to_expr = value =>
    switch (value) {
    | Some((_, value)) => (Loc.none, value)
    | None => void_0
    };
};

module Transform = {
  let undecorate_methods = ({C.body: (body_loc, {body}), _} as cls) => {
    let methods =
      body
      |> List.filter_map(m =>
           switch (m) {
           | C.Body.Method((loc, m)) =>
             Some(C.Body.Method((loc, {...m, decorators: []})))
           | _ => None
           }
         );

    {...cls, body: (body_loc, {body: methods})};
  };

  let transform_class = cls => {
    let {C.id, classDecorators, superClass, body: (_, {body}), _} = cls;

    let (props, methods) =
      List.partition(
        element =>
          switch (element) {
          | C.Body.Property(_) => true
          | _ => false
          },
        body,
      );

    let (props, statics) =
      List.partition_map(
        element =>
          switch (element) {
          | C.Body.Property((_, {static, key, value, _})) =>
            if (static) {
              `Right((key, value));
            } else {
              `Left((key, value));
            }
          | _ => `Drop
          },
        props,
      );

    let decorators =
      List.filter_map(
        m =>
          switch (m) {
          | C.Body.Method((
              _,
              {C.Method.key, decorators: [_, ..._] as decorators, _},
            )) =>
            Some((key, decorators))
          | _ => None
          },
        methods,
      );

    let move_props_to_constructor = (cls: C.t(Loc.t)) =>
      switch (props) {
      | [] => cls
      | props =>
        let prop_stmts =
          props
          |> List.map(((key, value)) =>
               (
                 Loc.none,
                 S.Expression({
                   expression:
                     object_define_property(
                       Helper.op_key_to_literal(key),
                       Helper.op_value_to_expr(value),
                     ),
                   directive: None,
                 }),
               )
             );

        let insert_after_super = stmts => {
          let (take, drop) =
            stmts
            |> List.take_drop_while(stmt =>
                 switch (stmt) {
                 | (
                     _,
                     S.Expression({
                       expression: (_, E.Call({callee: (_, E.Super), _})),
                       _,
                     }),
                   ) =>
                   false
                 | _ => true
                 }
               );

          switch (drop) {
          | [] => prop_stmts @ take
          | [super, ...rest] => take @ [super, ...prop_stmts] @ rest
          };
        };

        let constructor =
          List.head_opt @@
          List.filter(((_, el)) =>
            switch (el) {
            | C.Body.Method((_, {kind: C.Method.Constructor, _})) => true
            | _ => false
            }
          ) @@
          List.mapi((index, el) => (index, el), methods);

        let (take, drop, constructor) =
          switch (constructor) {
          | Some((
              i,
              C.Body.Method((
                c_loc,
                {value: (value_loc, value), _} as constructor,
              )),
            )) =>
            let (body_loc, body) =
              switch (value.body) {
              | F.BodyBlock((body_loc, {body})) => (body_loc, body)
              | F.BodyExpression(expr) => (Loc.none, [return(expr)])
              };

            (
              i,
              i + 1,
              C.Body.Method((
                c_loc,
                {
                  ...constructor,
                  value: (
                    value_loc,
                    {
                      ...value,
                      body:
                        F.BodyBlock((
                          body_loc,
                          {body: insert_after_super(body)},
                        )),
                    },
                  ),
                },
              )),
            );
          | None =>
            let maybe_super =
              switch (superClass) {
              | None => []
              | Some(_) => [
                  (
                    Loc.none,
                    S.Expression({
                      expression: (
                        Loc.none,
                        E.Call({
                          callee: (Loc.none, E.Super),
                          arguments: [
                            E.Spread((
                              Loc.none,
                              {argument: AstHelper.e_identifier("args")},
                            )),
                          ],
                          optional: false,
                        }),
                      ),
                      directive: None,
                    }),
                  ),
                ]
              };

            (
              0,
              0,
              C.Body.Method((
                Loc.none,
                {
                  kind: C.Method.Constructor,
                  static: false,
                  decorators: [],
                  key:
                    E.Object.Property.Identifier((Loc.none, "constructor")),
                  value: (
                    Loc.none,
                    {
                      id: None,
                      params: (
                        Loc.none,
                        {
                          params: [],
                          rest:
                            Some((
                              Loc.none,
                              {
                                argument: (
                                  Loc.none,
                                  AstHelper.p_identifier("args"),
                                ),
                              },
                            )),
                        },
                      ),
                      body:
                        F.BodyBlock((
                          Loc.none,
                          {body: maybe_super @ prop_stmts},
                        )),
                      async: false,
                      generator: false,
                      predicate: None,
                      expression: false,
                      returnType: None,
                      typeParameters: None,
                    },
                  ),
                },
              )),
            );
          | _ => Error.ie("Only constructor is expected here")
          };

        let (body_loc, _) = cls.body;
        let body =
          List.take(take, methods)
          @ [constructor]
          @ List.drop(drop, methods);

        {...cls, body: (body_loc, {body: body})};
      };

    let cls = {
      ...cls |> move_props_to_constructor |> undecorate_methods,
      classDecorators: [],
    };

    (cls, id, statics, classDecorators, decorators);
  };

  let wrap_class = (cls, statics, classDecorators, decorators) => {
    let to_expr_array = to_array(el => el);

    let statics =
      statics
      |> to_array(((key, value)) =>
           object_([
             object_property(
               "name",
               (Loc.none, E.Literal(Helper.op_key_to_literal(key))),
             ),
             object_property("value", Helper.op_value_to_expr(value)),
           ])
         );

    let decorators =
      decorators
      |> to_array(((key, decorators)) =>
           object_([
             object_property(
               "method",
               (Loc.none, E.Literal(Helper.op_key_to_literal(key))),
             ),
             object_property("decorators", to_expr_array(decorators)),
           ])
         );

    fpack_define_class(
      cls,
      statics,
      to_expr_array(classDecorators),
      decorators,
    );
  };
};

let transpile = ({Context.require_runtime_helper, _}, program) => {
  let map_expression = (_, (loc, node): E.t(Loc.t)) =>
    switch (node) {
    | E.Class(cls) =>
      switch (Transform.transform_class(cls)) {
      | (cls, _, [], [], []) => (loc, E.Class(cls))
      | (cls, _, statics, classDecorators, decorators) =>
        require_runtime_helper(helperName);
        Transform.wrap_class(cls, statics, classDecorators, decorators);
      }
    | _ => (loc, node)
    };

  let map_statement = ({AstMapper.parents, _}, (loc, stmt): S.t(Loc.t)) =>
    switch (stmt) {
    | S.ExportDefaultDeclaration(
        {
          declaration:
            S.ExportDefaultDeclaration.Declaration((
              _,
              S.ClassDeclaration({id: Some((_, name)), _} as cls),
            )),
          _,
        } as export,
      ) =>
      switch (Transform.transform_class(cls)) {
      | (cls, _, [], [], []) => [
          (
            loc,
            S.ExportDefaultDeclaration({
              ...export,
              declaration:
                S.ExportDefaultDeclaration.Declaration((
                  Loc.none,
                  S.ClassDeclaration(cls),
                )),
            }),
          ),
        ]
      | (cls, _, statics, classDecorators, decorators) =>
        require_runtime_helper(helperName);
        [
          Transform.wrap_class(cls, statics, classDecorators, decorators)
          |> let_stmt(~loc=Loc.none, name),
          (
            loc,
            S.ExportDefaultDeclaration({
              ...export,
              declaration:
                S.ExportDefaultDeclaration.Expression(
                  AstHelper.e_identifier(name),
                ),
            }),
          ),
        ];
      }

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
        switch (Transform.transform_class(cls)) {
        | (cls, _, [], [], []) => [(loc, S.ClassDeclaration(cls))]
        | (cls, name, statics, classDecorators, decorators) =>
          require_runtime_helper(helperName);
          let transformed =
            Transform.wrap_class(cls, statics, classDecorators, decorators);

          switch (name) {
          | None => [
              (
                loc,
                S.Expression({expression: transformed, directive: None}),
              ),
            ]
          | Some((_, name)) => [let_stmt(~loc, name, transformed)]
          };
        }
      }
    | _ => [(loc, stmt)]
    };

  let mapper = {...AstMapper.default_mapper, map_statement, map_expression};

  AstMapper.map(mapper, program);
};
