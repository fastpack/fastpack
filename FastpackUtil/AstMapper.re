module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;
module Expression = Ast.Expression;
module Pattern = Ast.Pattern;
module Statement = Ast.Statement;
module Literal = Ast.Literal;
module Type = Ast.Type;
module Variance = Ast.Variance;
module Class = Ast.Class;
module Function = Ast.Function;

module APS = AstParentStack;

type ctx = {
  handler: mapper,
  scope: Scope.t,
  parents: list(APS.parent),
}
and mapper = {
  map_statement:
    (ctx, Statement.t(Loc.t, Loc.t)) => list(Statement.t(Loc.t, Loc.t)),
  map_expression:
    (ctx, Expression.t(Loc.t, Loc.t)) => Expression.t(Loc.t, Loc.t),
  map_function:
    (ctx, (Loc.t, Function.t(Loc.t, Loc.t))) =>
    (Loc.t, Function.t(Loc.t, Loc.t)),
  map_pattern: (ctx, Pattern.t(Loc.t, Loc.t)) => Pattern.t(Loc.t, Loc.t),
};

let do_nothing = (_, node) => node;

let default_mapper = {
  map_statement: (_, node) => [node],
  map_expression: do_nothing,
  map_function: do_nothing,
  map_pattern: do_nothing,
};

let map_list = (ctx, map, list) => List.map(map(ctx), list);

let map_if_some = (ctx, map_with) =>
  fun
  | None => None
  | Some(item) => Some(map_with(ctx, item));

let rec map_statements = (ctx, stmts) =>
  List.fold_left(
    (acc, stmt) => {
      let stmts = map_statement(ctx, stmt);
      acc @ stmts;
    },
    [],
    stmts,
  )
and to_block_if_many = stmts =>
  switch (stmts) {
  | [stmt] => stmt
  | _ => (Loc.none, Statement.Block({body: stmts}))
  }
and map_statement = (ctx, (loc, statement)) => {
  let statement = {
    let ctx = {
      ...ctx,
      scope: Scope.of_statement(ctx.parents, (loc, statement), ctx.scope),
      parents: APS.push_statement((loc, statement), ctx.parents),
    };

    switch (statement) {
    | Statement.Block(block) =>
      let (_, block) = map_block(ctx, (loc, block));
      Statement.Block(block);

    | Statement.Expression({expression, _} as expr) =>
      Statement.Expression({
        ...expr,
        expression: map_expression(ctx, expression),
      })

    | Statement.If({test, consequent, alternate}) =>
      Statement.If({
        test: map_expression(ctx, test),
        consequent: map_statement(ctx, consequent) |> to_block_if_many,
        alternate:
          map_if_some(
            ctx,
            (ctx, stmt) => map_statement(ctx, stmt) |> to_block_if_many,
            alternate,
          ),
      })

    | Statement.Labeled({body, _} as n) =>
      Statement.Labeled({
        ...n,
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.With({_object, body}) =>
      Statement.With({
        _object: map_expression(ctx, _object),
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.Switch({discriminant, cases}) =>
      Statement.Switch({
        discriminant: map_expression(ctx, discriminant),
        cases:
          map_list(
            ctx,
            (ctx, (loc, {Statement.Switch.Case.test, consequent})) => (
              loc,
              {
                Statement.Switch.Case.test:
                  map_if_some(ctx, map_expression, test),
                consequent: map_statements(ctx, consequent),
              },
            ),
            cases,
          ),
      })

    | Statement.Return({argument}) =>
      Statement.Return({
        argument: map_if_some(ctx, map_expression, argument),
      })

    | Statement.Throw({argument}) =>
      Statement.Throw({argument: map_expression(ctx, argument)})

    | Statement.Try({block, handler: _handler, finalizer}) =>
      Statement.Try({
        block: map_block(ctx, block),
        handler:
          map_if_some(
            ctx,
            (ctx, (loc, {Statement.Try.CatchClause.param, body})) => (
              loc,
              {
                Statement.Try.CatchClause.param:
                  map_if_some(ctx, map_pattern, param),
                body: map_block(ctx, body),
              },
            ),
            _handler,
          ),
        finalizer: map_if_some(ctx, map_block, finalizer),
      })

    | Statement.While({test, body}) =>
      Statement.While({
        test: map_expression(ctx, test),
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.DoWhile({body, test}) =>
      Statement.DoWhile({
        body: map_statement(ctx, body) |> to_block_if_many,
        test: map_expression(ctx, test),
      })

    | Statement.For({init, test, update, body}) =>
      Statement.For({
        init:
          map_if_some(
            ctx,
            (ctx, init) =>
              switch (init) {
              | Statement.For.InitDeclaration(decl) =>
                let decl = map_variable_declaration(ctx, decl);
                Statement.For.InitDeclaration(decl);
              | Statement.For.InitExpression(expression) =>
                let expression = map_expression(ctx, expression);
                Statement.For.InitExpression(expression);
              },
            init,
          ),
        test: map_if_some(ctx, map_expression, test),
        update: map_if_some(ctx, map_expression, update),
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.ForIn({left, right, body, _} as n) =>
      Statement.ForIn({
        ...n,
        left:
          switch (left) {
          | Statement.ForIn.LeftDeclaration(decl) =>
            let decl = map_variable_declaration(ctx, decl);
            Statement.ForIn.LeftDeclaration(decl);
          | Statement.ForIn.LeftPattern(pattern) =>
            let pattern = map_pattern(ctx, pattern);
            Statement.ForIn.LeftPattern(pattern);
          },
        right: map_expression(ctx, right),
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.ForOf({left, right, body, async: _async} as n) =>
      Statement.ForOf({
        ...n,
        left:
          switch (left) {
          | Statement.ForOf.LeftDeclaration(decl) =>
            let decl = map_variable_declaration(ctx, decl);
            Statement.ForOf.LeftDeclaration(decl);
          | Statement.ForOf.LeftPattern(pattern) =>
            let pattern = map_pattern(ctx, pattern);
            Statement.ForOf.LeftPattern(pattern);
          },
        right: map_expression(ctx, right),
        body: map_statement(ctx, body) |> to_block_if_many,
      })

    | Statement.FunctionDeclaration(func) =>
      let (_, func) = map_function(ctx, (loc, func));
      Statement.FunctionDeclaration(func);

    | Statement.VariableDeclaration(decl) =>
      let (_, decl) = map_variable_declaration(ctx, (loc, decl));
      Statement.VariableDeclaration(decl);

    | Statement.ClassDeclaration(cls) =>
      let cls = map_class(ctx, cls);
      Statement.ClassDeclaration(cls);

    | Statement.ExportNamedDeclaration({declaration: Some(stmt), _} as e) =>
      switch (map_statement(ctx, stmt)) {
      | [stmt] =>
        Statement.ExportNamedDeclaration({...e, declaration: Some(stmt)})
      | _ => Error.ie("Cannot have multiple statements in the named export")
      }

    | Statement.ExportDefaultDeclaration(
        {
          declaration: Statement.ExportDefaultDeclaration.Declaration(stmt),
          _,
        } as e,
      ) =>
      switch (map_statement(ctx, stmt)) {
      | [stmt] =>
        Statement.ExportDefaultDeclaration({
          ...e,
          declaration: Statement.ExportDefaultDeclaration.Declaration(stmt),
        })
      | _ => Error.ie("Cannot have multiple statements in the default export")
      }

    | Statement.ExportDefaultDeclaration(
        {declaration: Statement.ExportDefaultDeclaration.Expression(expr), _} as e,
      ) =>
      let expr = map_expression(ctx, expr);
      Statement.ExportDefaultDeclaration({
        ...e,
        declaration: Statement.ExportDefaultDeclaration.Expression(expr),
      });

    | node => node
    };
  };

  ctx.handler.map_statement(ctx, (loc, statement));
}
and map_class = (ctx, {Class.body: (body_loc, {body}), extends, _} as n) =>
  /*** TODO: handle `classDecorators` */
  {
    ...n,
    extends:
      map_if_some(
        ctx,
        (ctx, (loc, {Class.Extends.expr, targs})) => (
          loc,
          {Class.Extends.expr: map_expression(ctx, expr), targs},
        ),
        extends,
      ),
    body: (
      body_loc,
      {
        Class.Body.body:
          map_list(
            ctx,
            (ctx, item) =>
              switch (item) {
              | Class.Body.Method((loc, {value, _} as n)) =>
                let value = map_function(ctx, value);
                Class.Body.Method((loc, {...n, value}));
              | Class.Body.Property((loc, {key, value, _} as n)) =>
                let key = map_object_property_key(ctx, key);
                let value = map_if_some(ctx, map_expression, value);
                Class.Body.Property((loc, {...n, key, value}));
              | Class.Body.PrivateField((loc, {value, _} as n)) =>
                let value = map_if_some(ctx, map_expression, value);
                Class.Body.PrivateField((loc, {...n, value}));
              },
            body,
          ),
      },
    ),
  }
and map_expression = (ctx, (loc, expression)) => {
  let expression = {
    let ctx = {
      ...ctx,
      parents: APS.push_expression((loc, expression), ctx.parents),
    };

    switch (expression) {
    | Expression.TypeCast({expression, annot}) =>
      Expression.TypeCast({
        expression: map_expression(ctx, expression),
        annot,
      })
    | Expression.Array({elements}) =>
      Expression.Array({
        elements:
          map_list(
            ctx,
            ctx =>
              fun
              | None => None
              | Some(element) =>
                Some(map_expression_or_spread(ctx, element)),
            elements,
          ),
      })
    | Expression.Object({properties}) =>
      Expression.Object({
        properties:
          map_list(
            ctx,
            (ctx, prop) =>
              switch (prop) {
              | Expression.Object.Property(property) =>
                let property = map_object_property(ctx, property);
                Expression.Object.Property(property);
              | Expression.Object.SpreadProperty((loc, {argument})) =>
                let argument = map_expression(ctx, argument);
                Expression.Object.SpreadProperty((
                  loc,
                  {argument: argument},
                ));
              },
            properties,
          ),
      })

    | Expression.Function(func) =>
      let (_, func) = map_function(ctx, (loc, func));
      Expression.Function(func);

    | Expression.ArrowFunction(func) =>
      let (_, func) = map_function(ctx, (loc, func));
      Expression.ArrowFunction(func);

    | Expression.Sequence({expressions}) =>
      let expressions = map_list(ctx, map_expression, expressions);
      Expression.Sequence({expressions: expressions});

    | Expression.Unary({argument, _} as n) =>
      let argument = map_expression(ctx, argument);
      Expression.Unary({...n, argument});

    | Expression.Binary({left, right, _} as n) =>
      let left = map_expression(ctx, left);
      let right = map_expression(ctx, right);
      Expression.Binary({...n, left, right});

    | Expression.Assignment({left, right, _} as n) =>
      let left = map_pattern(ctx, left);
      let right = map_expression(ctx, right);
      Expression.Assignment({...n, left, right});

    | Expression.Update({argument, _} as n) =>
      let argument = map_expression(ctx, argument);
      Expression.Update({...n, argument});

    | Expression.Logical({left, right, _} as n) =>
      let left = map_expression(ctx, left);
      let right = map_expression(ctx, right);
      Expression.Logical({...n, left, right});

    | Expression.Conditional({test, consequent, alternate}) =>
      let test = map_expression(ctx, test);
      let consequent = map_expression(ctx, consequent);
      let alternate = map_expression(ctx, alternate);
      Expression.Conditional({test, consequent, alternate});

    | Expression.New({callee, arguments, targs}) =>
      let callee = map_expression(ctx, callee);
      let arguments = map_list(ctx, map_expression_or_spread, arguments);
      Expression.New({callee, arguments, targs});

    | Expression.OptionalCall({call: {callee, arguments, targs}, optional}) =>
      let callee = map_expression(ctx, callee);
      let arguments = map_list(ctx, map_expression_or_spread, arguments);
      Expression.OptionalCall({
        call: {
          callee,
          arguments,
          targs,
        },
        optional,
      });

    | Expression.Call({callee, arguments, targs}) =>
      let callee = map_expression(ctx, callee);
      let arguments = map_list(ctx, map_expression_or_spread, arguments);
      Expression.Call({callee, arguments, targs});

    | Expression.OptionalMember({member, optional}) =>
      let _object = map_expression(ctx, member._object);
      let property =
        switch (member.property) {
        | Expression.Member.PropertyPrivateName(_)
        | Expression.Member.PropertyIdentifier(_) => member.property
        | Expression.Member.PropertyExpression(expr) =>
          let expr = map_expression(ctx, expr);
          Expression.Member.PropertyExpression(expr);
        };
      Expression.OptionalMember({
        member: {
          ...member,
          _object,
          property,
        },
        optional,
      });

    | Expression.Member({_object, property, _} as n) =>
      let _object = map_expression(ctx, _object);
      let property =
        switch (property) {
        | Expression.Member.PropertyPrivateName(_)
        | Expression.Member.PropertyIdentifier(_) => property
        | Expression.Member.PropertyExpression(expr) =>
          let expr = map_expression(ctx, expr);
          Expression.Member.PropertyExpression(expr);
        };
      Expression.Member({...n, _object, property});

    | Expression.Yield({argument, _} as n) =>
      let argument = map_if_some(ctx, map_expression, argument);
      Expression.Yield({...n, argument});

    | Expression.Class(cls) =>
      let cls = map_class(ctx, cls);
      Expression.Class(cls);

    | Expression.TemplateLiteral({expressions, _} as template) =>
      Expression.TemplateLiteral({
        ...template,
        expressions: map_list(ctx, map_expression, expressions),
      })

    | Expression.TaggedTemplate({
        tag,
        quasi: (quasi_loc, {expressions, _} as quasi),
      }) =>
      Expression.TaggedTemplate({
        tag: map_expression(ctx, tag),
        quasi: (
          quasi_loc,
          {
            ...quasi,
            expressions: map_list(ctx, map_expression, expressions),
          },
        ),
      })

    | node => node
    };
  };

  ctx.handler.map_expression(ctx, (loc, expression));
}
and map_pattern = (ctx, (loc, pattern)) => {
  let pattern =
    switch (pattern) {
    | Pattern.Object({properties, _} as n) =>
      let properties =
        map_list(
          ctx,
          (ctx, prop) =>
            switch (prop) {
            | Pattern.Object.RestProperty((loc, {argument})) =>
              let argument = map_pattern(ctx, argument);
              Pattern.Object.RestProperty((loc, {argument: argument}));
            | Pattern.Object.Property((loc, {key, pattern, _} as n)) =>
              let key = map_pattern_property_key(ctx, key);
              let pattern = map_pattern(ctx, pattern);
              Pattern.Object.Property((loc, {...n, key, pattern}));
            },
          properties,
        );
      Pattern.Object({...n, properties});

    | Pattern.Array({elements, _} as n) =>
      let elements =
        map_list(
          ctx,
          (ctx, element) =>
            switch (element) {
            | None => None
            | Some(Pattern.Array.Element(pattern)) =>
              let pattern = map_pattern(ctx, pattern);
              Some(Pattern.Array.Element(pattern));
            | Some(Pattern.Array.RestElement((loc, {argument}))) =>
              let argument = map_pattern(ctx, argument);
              Some(Pattern.Array.RestElement((loc, {argument: argument})));
            },
          elements,
        );

      Pattern.Array({...n, elements});

    | Pattern.Assignment({left, right}) =>
      let left = map_pattern(ctx, left);
      let right = map_expression(ctx, right);
      Pattern.Assignment({left, right});

    | Pattern.Expression(expr) =>
      let expr = map_expression(ctx, expr);
      Pattern.Expression(expr);
    | node => node
    };

  ctx.handler.map_pattern(ctx, (loc, pattern));
}
and map_pattern_property_key = (ctx, key) =>
  switch (key) {
  | Pattern.Object.Property.Literal(_) => key
  | Pattern.Object.Property.Identifier(_) => key
  | Pattern.Object.Property.Computed(expr) =>
    let expr = map_expression(ctx, expr);
    Pattern.Object.Property.Computed(expr);
  }
and map_object_property = (ctx, (loc, prop)) => {
  let prop =
    switch (prop) {
    | Expression.Object.Property.Init({key, value, _} as n) =>
      Expression.Object.Property.Init({
        ...n,
        key: map_object_property_key(ctx, key),
        value: map_expression(ctx, value),
      })
    | Expression.Object.Property.Method({key, value}) =>
      Expression.Object.Property.Method({
        key: map_object_property_key(ctx, key),
        value: map_function(ctx, value),
      })
    | Expression.Object.Property.Get({key, value}) =>
      Expression.Object.Property.Get({
        key: map_object_property_key(ctx, key),
        value: map_function(ctx, value),
      })
    | Expression.Object.Property.Set({key, value}) =>
      Expression.Object.Property.Set({
        key: map_object_property_key(ctx, key),
        value: map_function(ctx, value),
      })
    };

  (loc, prop);
}
and map_object_property_key = (ctx, key) =>
  switch (key) {
  | Expression.Object.Property.Computed(expr) =>
    let expr = map_expression(ctx, expr);
    Expression.Object.Property.Computed(expr);
  | node => node
  }
and map_function =
    (
      ctx,
      (loc, {Function.params: (params_loc, {params, rest}), body, _} as f),
    ) => {
  let f = {
    let ctx = {
      ...ctx,
      scope: Scope.of_function(ctx.parents, (loc, f), ctx.scope),
      parents: APS.push_function((loc, f), ctx.parents),
    };

    let params = map_list(ctx, map_pattern, params);

    let rest =
      map_if_some(
        ctx,
        (ctx, (loc, {Function.RestElement.argument})) => (
          loc,
          {Function.RestElement.argument: map_pattern(ctx, argument)},
        ),
        rest,
      );

    let body = map_function_body(ctx, body);
    Function.{...f, params: (params_loc, {params, rest}), body};
  };

  ctx.handler.map_function(ctx, (loc, f));
}
and map_function_body = (ctx, body) =>
  switch (body) {
  | Function.BodyBlock(block) =>
    let block = map_block(ctx, block);
    Function.BodyBlock(block);
  | Function.BodyExpression(expr) =>
    let expr = map_expression(ctx, expr);
    Function.BodyExpression(expr);
  }
and map_block = (ctx, (loc, block)) => {
  let ctx = {
    ...ctx,
    scope: Scope.of_block(ctx.parents, (loc, block), ctx.scope),
    parents: APS.push_block((loc, block), ctx.parents),
  };

  (loc, {body: map_statements(ctx, block.body)});
}
and map_variable_declaration = (ctx, (loc, {declarations, _} as n)) => {
  let declarations = map_list(ctx, map_variable_declarator, declarations);
  (loc, {...n, declarations});
}
and map_variable_declarator = (ctx, (loc, {init, id})) => {
  let id = map_pattern(ctx, id);
  let init =
    switch (init) {
    | None => None
    | Some(expr) => Some(map_expression(ctx, expr))
    };
  (loc, {Statement.VariableDeclaration.Declarator.init, id});
}
and map_expression_or_spread = (ctx, item) =>
  switch (item) {
  | Expression.Expression(expr) =>
    let expr = map_expression(ctx, expr);
    Expression.Expression(expr);
  | Expression.Spread((loc, {argument})) =>
    let argument = map_expression(ctx, argument);
    Expression.Spread((loc, {argument: argument}));
  };

let map = (handler, (loc, statements, comments)) => {
  let ctx = {
    scope: fst @@ Scope.of_program(statements),
    parents: [],
    handler,
  };

  let statements = map_statements(ctx, statements);
  (loc, statements, comments);
};
