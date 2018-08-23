/*
 * This is transform for spread in object literals and rest spread in object
 * patterns
 **/
module AstMapper = FastpackUtil.AstMapper;
module AstHelper = FastpackUtil.AstHelper;
module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;
module E = Ast.Expression;
module F = Ast.Function;
module S = Ast.Statement;
module P = Ast.Pattern;
module L = Ast.Literal;

/**
 * Folds over Ast.
 *
 * TODO: Decide if we need to move this to a top level module.
 **/
module AstFolder = {
  let rec fold_pattern = (f, v, (_loc, node): P.t(Loc.t)) => {
    let v =
      switch (node) {
      | P.Object({properties, _}) =>
        let aux = v => (
          fun
          | P.Object.Property((_, p)) => fold_pattern(f, v, p.pattern)
          | P.Object.RestProperty((_, p)) => fold_pattern(f, v, p.argument)
        );

        List.fold_left(aux, v, properties);

      | P.Array({elements, _}) =>
        let aux = v => (
          fun
          | Some(P.Array.Element(p)) => fold_pattern(f, v, p)
          | Some(P.Array.RestElement((_, p))) =>
            fold_pattern(f, v, p.argument)
          | None => v
        );

        List.fold_left(aux, v, elements);

      | P.Assignment(_) => v
      | P.Identifier(_) => v
      | P.Expression(_) => v
      };

    f(v, node);
  };
};

module Helper = {
  let empty_object_literal = (Loc.none, E.Object({properties: []}));

  let object_assign = arguments => (
    Loc.none,
    E.Call({
      callee: (
        Loc.none,
        E.Member({
          computed: false,
          _object: (Loc.none, E.Identifier((Loc.none, "Object"))),
          property: E.Member.PropertyIdentifier((Loc.none, "assign")),
          optional: false,
        }),
      ),
      arguments: [
        E.Expression(empty_object_literal),
        ...List.rev(arguments),
      ],
      optional: false,
    }),
  );

  let object_omit = (expr, keys) => {
    let keys = List.map(key => Some(E.Expression(key)), keys);
    let keys = (Loc.none, E.Array({elements: keys}));
    (
      Loc.none,
      E.Call({
        callee: (
          Loc.none,
          E.Member({
            computed: false,
            _object: (Loc.none, E.Identifier((Loc.none, "$fpack"))),
            property: E.Member.PropertyIdentifier((Loc.none, "objectOmit")),
            optional: false,
          }),
        ),
        arguments: [E.Expression(expr), E.Expression(keys)],
        optional: false,
      }),
    );
  };

  let object_pattern_key_to_expr =
    fun
    | P.Object.Property.Literal((loc, lit)) => (loc, E.Literal(lit))
    | P.Object.Property.Identifier((loc, id)) => (
        loc,
        E.Literal({
          value: L.String(id),
          /*** TODO: properly escape quotes from the id */
          raw: "\"" ++ id ++ "\"",
        }),
      )
    | P.Object.Property.Computed(expr) => expr;
};

module TranspileObjectSpread = {
  let test = (obj: E.Object.t(Loc.t)) =>
    List.exists(
      fun
      | E.Object.SpreadProperty(_) => true
      | _ => false,
      obj.properties,
    );

  let transpile = (obj: E.Object.t(Loc.t)) => {
    let add_argument = (bucket, arguments) =>
      switch (bucket) {
      | [] => arguments
      | properties =>
        let arg =
          E.Expression((
            Loc.none,
            E.Object({properties: List.rev(properties)}),
          ));
        [arg, ...arguments];
      };

    let aux = ((bucket, arguments), prop) =>
      switch (prop) {
      | E.Object.Property(_) => ([prop, ...bucket], arguments)
      | E.Object.SpreadProperty((_, {argument})) =>
        let arguments = add_argument(bucket, arguments);
        ([], [E.Expression(argument), ...arguments]);
      };

    let (bucket, arguments) = List.fold_left(aux, ([], []), obj.properties);
    let arguments = add_argument(bucket, arguments);
    Helper.object_assign(arguments);
  };
};

module TranspileObjectSpreadRest = {
  module Pattern = {
    type item =
      | Assign((P.t'(Loc.t), E.t(Loc.t)))
      | Omit((P.t'(Loc.t), E.t(Loc.t), list(E.t(Loc.t))));

    type t = {
      before: list(item),
      self: option(item),
      after: list(item),
      result: E.t(Loc.t),
    };

    let test = {
      let check_pattern = (result, node) =>
        switch (result, node) {
        | (true, _) => true
        | (_, P.Object({P.Object.properties, _})) =>
          switch (List.rev(properties)) {
          | [P.Object.RestProperty(_), ..._] => true
          | _ => false
          }
        | _ => false
        };

      AstFolder.fold_pattern(check_pattern, false);
    };

    let transpile = ({Context.gen_binding, _}, scope, left, right) => {
      let before = ref([]);
      let after = ref([]);
      let compute_before = expr =>
        switch (snd(expr)) {
        | E.Identifier((_, name)) => name
        | _ =>
          let name = gen_binding(scope);

          before :=
            [Assign((AstHelper.p_identifier(name), expr)), ...before^];
          name;
        };

      let compute_key = key =>
        switch (key) {
        | P.Object.Property.Computed(expr) =>
          let name = compute_before(expr);
          P.Object.Property.Computed(AstHelper.e_identifier(name));
        | _ => key
        };

      let get_object_property = (obj, key) =>
        switch (key) {
        | P.Object.Property.Literal((_, lit)) =>
          AstHelper.member_expr(obj, AstHelper.e_literal(lit))
        | P.Object.Property.Identifier((_, name)) =>
          AstHelper.member(obj, name)
        | P.Object.Property.Computed(expr) =>
          AstHelper.member_expr(obj, expr)
        };

      let rec strip_rest = (pattern, obj) =>
        switch (pattern) {
        | P.Object({properties, _} as pattern) =>
          let (properties, spread) = strip_properties(properties, obj);
          let () =
            switch (spread) {
            | Some((spread, omit)) =>
              after :=
                [
                  Omit((AstHelper.p_identifier(spread), obj, omit)),
                  ...after^,
                ]
            | _ => ()
            };

          switch (properties) {
          | [] => None
          | _ => Some(P.Object({...pattern, properties}))
          };
        | P.Array({elements, _} as pattern) =>
          let elements =
            elements
            |> List.mapi((i, el) => {
                 let index =
                   P.Object.Property.Computed(
                     AstHelper.e_literal(AstHelper.literal_num(i)),
                   );

                 let obj = get_object_property(obj, index);
                 switch (el) {
                 | Some(P.Array.Element((_, pattern))) =>
                   switch (strip_rest(pattern, obj)) {
                   | Some(pattern) =>
                     Some(P.Array.Element((Loc.none, pattern)))
                   | None => None
                   }
                 | Some(
                     P.Array.RestElement((_, {argument: (_, pattern), _})),
                   ) =>
                   switch (strip_rest(pattern, obj)) {
                   | Some(pattern) =>
                     Some(
                       P.Array.RestElement((
                         Loc.none,
                         {argument: (Loc.none, pattern)},
                       )),
                     )
                   | None => None
                   }
                 | _ => None
                 };
               });

          Some(P.Array({...pattern, elements}));
        | _ => Some(pattern)
        }
      and strip_properties = (properties, obj) => {
        let omit_keys = ref([]);
        let omit = key => {
          let expr =
            switch (key) {
            | P.Object.Property.Literal((_, lit)) => AstHelper.e_literal(lit)
            | P.Object.Property.Identifier((_, name)) =>
              AstHelper.e_literal_str(name)
            | P.Object.Property.Computed((_, E.Identifier((_, name)))) =>
              AstHelper.e_identifier(name)
            | P.Object.Property.Computed((loc, _)) =>
              raise(
                Error.TranspilerError((
                  loc,
                  "Unexpected non-identifier Object.Property.Computed",
                )),
              )
            };

          omit_keys := [expr, ...omit_keys^];
        };

        let (properties, spread) =
          properties
          |> List.partition_map(
               fun
               | P.Object.Property((
                   _,
                   {pattern: (_, pattern), key, _} as prop,
                 )) => {
                   let key = compute_key(key);
                   let pattern =
                     strip_rest(pattern, get_object_property(obj, key));

                   omit(key);
                   switch (pattern) {
                   | Some(pattern) =>
                     `Left(
                       P.Object.Property((
                         Loc.none,
                         {...prop, key, pattern: (Loc.none, pattern)},
                       )),
                     )
                   | None => `Drop
                   };
                 }
               | P.Object.RestProperty((
                   _,
                   {argument: (_, P.Identifier({name: (_, name), _}))},
                 )) =>
                 `Right(name)
               | P.Object.RestProperty((_, {argument: (_, pattern)})) => {
                   let obj =
                     AstHelper.fpack_omit_props(
                       obj,
                       AstHelper.to_array(x => x, omit_keys^),
                     );

                   let () =
                     switch (strip_rest(pattern, obj)) {
                     | Some(self) => after := after^ @ [Assign((self, obj))]
                     | None => ()
                     };

                   `Drop;
                 },
             );

        (
          properties,
          switch (spread) {
          | [spread] => Some((spread, List.rev(omit_keys^)))
          | _ => None
          },
        );
      };

      let right = AstHelper.e_identifier(compute_before(right));
      let self =
        switch (strip_rest(left, right)) {
        | Some(self) => Some(Assign((self, right)))
        | None => None
        };

      {
        before: List.rev(before^),
        self,
        after: List.rev(after^),
        result: right,
      };
    };

    let to_variable_declaration =
      fun
      | Assign((left, right)) => (
          Loc.none,
          {
            S.VariableDeclaration.Declarator.id: (Loc.none, left),
            init: Some(right),
          },
        )
      | Omit((left, right, omit)) => (
          Loc.none,
          {
            S.VariableDeclaration.Declarator.id: (Loc.none, left),
            init:
              Some(
                AstHelper.fpack_omit_props(
                  right,
                  AstHelper.to_array(x => x, omit),
                ),
              ),
          },
        );

    let to_assignment =
      fun
      | Assign((left, right)) => (
          Loc.none,
          S.Expression({
            expression: (
              Loc.none,
              E.Assignment({
                operator: E.Assignment.Assign,
                left: (Loc.none, left),
                right,
              }),
            ),
            directive: None,
          }),
        )
      | Omit((left, right, omit)) => (
          Loc.none,
          S.Expression({
            expression: (
              Loc.none,
              E.Assignment({
                operator: E.Assignment.Assign,
                left: (Loc.none, left),
                right:
                  AstHelper.fpack_omit_props(
                    right,
                    AstHelper.to_array(x => x, omit),
                  ),
              }),
            ),
            directive: None,
          }),
        );
  };

  module Assignment = {
    let test = ({E.Assignment.left, _}) => Pattern.test(left);

    let transpile =
        (context, scope, {E.Assignment.left: (_, left), right, _}) => {
      let {Pattern.before, self, after, result} =
        Pattern.transpile(context, scope, left, right);

      let declarations = List.map(Pattern.to_variable_declaration, before);

      let variables =
        if (List.length(declarations) > 0) {
          [
            (
              Loc.none,
              S.VariableDeclaration({
                kind: S.VariableDeclaration.Let,
                declarations,
              }),
            ),
          ];
        } else {
          [];
        };

      let assignments =
        (
          switch (self) {
          | Some(item) => [item]
          | None => []
          }
        )
        @ after
        |> List.map(Pattern.to_assignment);

      let func = (
        Loc.none,
        E.ArrowFunction({
          id: None,
          params: (Loc.none, {params: [], rest: None}),
          async: false,
          generator: false,
          predicate: None,
          expression: false,
          typeParameters: None,
          returnType: None,
          body:
            F.BodyBlock((
              Loc.none,
              {
                body:
                  variables
                  @ assignments
                  @ [(Loc.none, S.Return({argument: Some(result)}))],
              },
            )),
        }),
      );

      AstHelper.call(func, []);
    };
  };

  module Function = {
    let test = ({F.params: (_, {params, rest}), _}) =>
      List.exists(Pattern.test, params)
      || (
        switch (rest) {
        | Some((_, {F.RestElement.argument})) => Pattern.test(argument)
        | None => false
        }
      );

    let transpile =
        (context, scope, {F.params: (_, {params, rest}), body, _} as func) => {
      let vars = ref([]);
      let gen_binding = pattern => {
        let binding = context.Context.gen_binding(scope);
        let () =
          vars :=
            [(snd(pattern), AstHelper.e_identifier(binding)), ...vars^];

        (Loc.none, AstHelper.p_identifier(binding));
      };

      let params =
        List.map(
          param =>
            if (Pattern.test(param)) {
              gen_binding(param);
            } else {
              param;
            },
          params,
        );

      let rest =
        switch (rest) {
        | None => None
        | Some((_, {argument})) as rest =>
          if (Pattern.test(argument)) {
            Some((
              Loc.none,
              {F.RestElement.argument: gen_binding(argument)},
            ));
          } else {
            rest;
          }
        };

      let declarations =
        vars^
        |> List.rev
        |> List.map(((left, right)) => {
             let {Pattern.before, self, after, _} =
               Pattern.transpile(context, scope, left, right);

             before
             @ (
               switch (self) {
               | Some(self) => [self]
               | None => []
               }
             )
             @ after;
           })
        |> List.flatten
        |> List.map(Pattern.to_variable_declaration);

      let decl = (
        Loc.none,
        S.VariableDeclaration({
          kind: S.VariableDeclaration.Let,
          declarations,
        }),
      );

      let body =
        switch (body) {
        | F.BodyBlock((_, {body})) =>
          F.BodyBlock((Loc.none, {body: [decl, ...body]}))
        | F.BodyExpression(expr) =>
          F.BodyBlock((
            Loc.none,
            {body: [decl, (Loc.none, S.Return({argument: Some(expr)}))]},
          ))
        };

      {...func, params: (Loc.none, {params, rest}), body};
    };
  };

  module VariableDeclaration = {
    let test =
        (~with_init=true, {declarations, _}: S.VariableDeclaration.t(Loc.t)) => {
      let test_declaration =
          ((_, {S.VariableDeclaration.Declarator.id, init})) =>
        switch (with_init, id, init) {
        | (false, id, None)
        | (true, id, Some(_)) => Pattern.test(id)
        | _ => false
        };

      List.exists(test_declaration, declarations);
    };

    let transpile_declaration =
        (
          context,
          scope,
          (
            loc,
            {S.VariableDeclaration.Declarator.id: (_, id), init} as decl,
          ),
        ) =>
      switch (init) {
      | None => [(loc, decl)]
      | Some(init) =>
        let {Pattern.before, self, after, _} =
          Pattern.transpile(context, scope, id, init);

        List.map(
          Pattern.to_variable_declaration,
          before
          @ (
            switch (self) {
            | Some(item) => [item]
            | None => []
            }
          )
          @ after,
        );
      };

    let transpile =
        (context, scope, {S.VariableDeclaration.declarations, _} as node) => {
      ...node,
      declarations:
        List.flatten @@
        List.map(transpile_declaration(context, scope), declarations),
    };
  };

  module ForIn = {
    let test = ({S.ForIn.left, _}) =>
      switch (left) {
      | S.ForIn.LeftDeclaration((_, decl)) =>
        VariableDeclaration.test(~with_init=false, decl)
      | S.ForIn.LeftPattern(pattern) => Pattern.test(pattern)
      };

    let transpile =
        (
          {Context.gen_binding, _} as ctx,
          scope,
          {S.ForIn.left, body: (body_loc, body), _} as for_,
        ) => {
      let binding = gen_binding(scope);
      let left_declaration = (loc, kind) =>
        S.ForIn.LeftDeclaration((
          loc,
          {
            kind,
            declarations: [
              (
                Loc.none,
                {
                  S.VariableDeclaration.Declarator.id: (
                    Loc.none,
                    Ast.Pattern.Identifier({
                      name: (Loc.none, binding),
                      typeAnnotation: None,
                      optional: false,
                    }),
                  ),
                  init: None,
                },
              ),
            ],
          },
        ));

      let prepend_stmt = stmt =>
        switch (body) {
        | S.Block({body}) => (body_loc, S.Block({body: [stmt, ...body]}))
        | prev => (body_loc, S.Block({body: [stmt, (Loc.none, prev)]}))
        };

      switch (left) {
      | S.ForIn.LeftDeclaration((loc, {kind, declarations: [(_, decl)]})) =>
        let stmt = (
          Loc.none,
          S.VariableDeclaration(
            VariableDeclaration.transpile(ctx, scope) @@
            {
              S.VariableDeclaration.kind: S.VariableDeclaration.Let,
              declarations: [
                (
                  Loc.none,
                  {...decl, init: Some(AstHelper.e_identifier(binding))},
                ),
              ],
            },
          ),
        );

        S.ForIn({
          ...for_,
          left: left_declaration(loc, kind),
          body: prepend_stmt(stmt),
        });
      | S.ForIn.LeftPattern(pattern) =>
        let stmt = (
          Loc.none,
          S.VariableDeclaration(
            VariableDeclaration.transpile(ctx, scope) @@
            {
              S.VariableDeclaration.kind: S.VariableDeclaration.Let,
              declarations: [
                (
                  Loc.none,
                  {
                    id: pattern,
                    init: Some(AstHelper.e_identifier(binding)),
                  },
                ),
              ],
            },
          ),
        );

        S.ForIn({
          ...for_,
          left: left_declaration(Loc.none, S.VariableDeclaration.Let),
          body: prepend_stmt(stmt),
        });
      | S.ForIn.LeftDeclaration((loc, _)) =>
        raise(
          Error.TranspilerError((
            loc,
            "Unexpected ForIn: more than one declaration",
          )),
        )
      };
    };
  };

  module Try = {
    let test = ((_, {param, _}): S.Try.CatchClause.t(Loc.t)) =>
      Pattern.test(param);

    let transpile =
        (
          context,
          scope,
          (loc, {S.Try.CatchClause.body: (body_loc, {body}), param}),
        ) => {
      let name = context.Context.gen_binding(scope);
      let new_param = (
        Loc.none,
        P.Identifier({
          name: (Loc.none, name),
          typeAnnotation: None,
          optional: false,
        }),
      );

      let body = [
        (
          Loc.none,
          S.VariableDeclaration(
            VariableDeclaration.transpile(
              context,
              scope,
              {
                S.VariableDeclaration.kind: S.VariableDeclaration.Let,
                declarations: [
                  (
                    Loc.none,
                    {
                      S.VariableDeclaration.Declarator.id: param,
                      init: Some(AstHelper.e_identifier(name)),
                    },
                  ),
                ],
              },
            ),
          ),
        ),
        ...body,
      ];

      (
        loc,
        {
          S.Try.CatchClause.param: new_param,
          body: (body_loc, {body: body}),
        },
      );
    };
  };

  module ForOf = {
    let test = ({S.ForOf.left, _}) =>
      switch (left) {
      | S.ForOf.LeftDeclaration((_, decl)) =>
        VariableDeclaration.test(~with_init=false, decl)
      | S.ForOf.LeftPattern(pattern) => Pattern.test(pattern)
      };

    let transpile =
        (
          {Context.gen_binding, _} as ctx,
          scope,
          {S.ForOf.left, body: (body_loc, body), _} as for_,
        ) => {
      let binding = gen_binding(scope);
      let left_declaration = (loc, kind) =>
        S.ForOf.LeftDeclaration((
          loc,
          {
            kind,
            declarations: [
              (
                Loc.none,
                {
                  S.VariableDeclaration.Declarator.id: (
                    Loc.none,
                    Ast.Pattern.Identifier({
                      name: (Loc.none, binding),
                      typeAnnotation: None,
                      optional: false,
                    }),
                  ),
                  init: None,
                },
              ),
            ],
          },
        ));

      let prepend_stmt = stmt =>
        switch (body) {
        | S.Block({body}) => (body_loc, S.Block({body: [stmt, ...body]}))
        | prev => (body_loc, S.Block({body: [stmt, (Loc.none, prev)]}))
        };

      switch (left) {
      | S.ForOf.LeftDeclaration((loc, {kind, declarations: [(_, decl)]})) =>
        let stmt = (
          Loc.none,
          S.VariableDeclaration(
            VariableDeclaration.transpile(ctx, scope) @@
            {
              S.VariableDeclaration.kind: S.VariableDeclaration.Let,
              declarations: [
                (
                  Loc.none,
                  {...decl, init: Some(AstHelper.e_identifier(binding))},
                ),
              ],
            },
          ),
        );

        S.ForOf({
          ...for_,
          left: left_declaration(loc, kind),
          body: prepend_stmt(stmt),
        });
      | S.ForOf.LeftPattern(pattern) =>
        let stmt = (
          Loc.none,
          S.VariableDeclaration(
            VariableDeclaration.transpile(ctx, scope) @@
            {
              S.VariableDeclaration.kind: S.VariableDeclaration.Let,
              declarations: [
                (
                  Loc.none,
                  {
                    id: pattern,
                    init: Some(AstHelper.e_identifier(binding)),
                  },
                ),
              ],
            },
          ),
        );

        S.ForOf({
          ...for_,
          left: left_declaration(Loc.none, S.VariableDeclaration.Let),
          body: prepend_stmt(stmt),
        });
      | S.ForOf.LeftDeclaration((loc, _)) =>
        raise(
          Error.TranspilerError((
            loc,
            "Unexpected ForOf: more than one declaration",
          )),
        )
      };
    };
  };
};

let transpile = ({Context.require_runtime, _} as context, program) => {
  let map_statement = ({AstMapper.scope, _}, (loc, node): S.t(Loc.t)) => {
    module T = TranspileObjectSpreadRest;
    let node =
      switch (node) {
      | S.VariableDeclaration(d) when T.VariableDeclaration.test(d) =>
        require_runtime();
        S.VariableDeclaration(
          T.VariableDeclaration.transpile(context, scope, d),
        );

      /* Only consider initdeclaration here
       * expression is handled in `map_expression`*/
      | S.For({init: Some(S.For.InitDeclaration((_, decl))), _} as node)
          when T.VariableDeclaration.test(decl) =>
        require_runtime();
        S.For({
          ...node,
          init:
            Some(
              S.For.InitDeclaration((
                Loc.none,
                T.VariableDeclaration.transpile(context, scope, decl),
              )),
            ),
        });

      | S.ForIn(for_) when T.ForIn.test(for_) =>
        require_runtime();
        T.ForIn.transpile(context, scope, for_);

      | S.ForOf(for_) when T.ForOf.test(for_) =>
        require_runtime();
        T.ForOf.transpile(context, scope, for_);

      | S.Try({handler: Some(handler), _} as stmt) when T.Try.test(handler) =>
        require_runtime();
        S.Try({
          ...stmt,
          handler: Some(T.Try.transpile(context, scope, handler)),
        });

      | _ => node
      };

    [(loc, node)];
  };

  let map_expression = ({AstMapper.scope, _}, (loc, node): E.t(Loc.t)) => {
    let node =
      switch (node) {
      | E.Object(obj) when TranspileObjectSpread.test(obj) =>
        require_runtime();
        snd(TranspileObjectSpread.transpile(obj));
      | E.Assignment({operator: E.Assignment.Assign, _} as obj)
          when TranspileObjectSpreadRest.Assignment.test(obj) =>
        require_runtime();
        snd(
          TranspileObjectSpreadRest.Assignment.transpile(context, scope, obj),
        );
      | node => node
      };

    (loc, node);
  };

  let map_function = ({AstMapper.scope, _}, (loc, func)) =>
    if (TranspileObjectSpreadRest.Function.test(func)) {
      require_runtime();
      (
        loc,
        TranspileObjectSpreadRest.Function.transpile(context, scope, func),
      );
    } else {
      (loc, func);
    };

  let mapper = {
    ...AstMapper.default_mapper,
    map_expression,
    map_statement,
    map_function,
  };

  AstMapper.map(mapper, program);
};
