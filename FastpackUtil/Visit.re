module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;
module E = Ast.Expression;
module P = Ast.Pattern;
module S = Ast.Statement;
module Class = Ast.Class;
module F = Ast.Function;
module APS = AstParentStack;

type visit_action =
  | Continue(ctx)
  | Break
and visit_handler = {
  visit_statement: (ctx, S.t(Loc.t, Loc.t)) => visit_action,
  enter_statement: (ctx, S.t(Loc.t, Loc.t)) => unit,
  leave_statement: (ctx, S.t(Loc.t, Loc.t)) => unit,
  visit_expression: (ctx, E.t(Loc.t, Loc.t)) => visit_action,
  visit_function: (ctx, (Loc.t, F.t(Loc.t, Loc.t))) => visit_action,
  enter_function: (ctx, (Loc.t, F.t(Loc.t, Loc.t))) => unit,
  leave_function: (ctx, (Loc.t, F.t(Loc.t, Loc.t))) => unit,
  visit_block: (ctx, (Loc.t, S.Block.t(Loc.t, Loc.t))) => visit_action,
  enter_block: (ctx, (Loc.t, S.Block.t(Loc.t, Loc.t))) => unit,
  leave_block: (ctx, (Loc.t, S.Block.t(Loc.t, Loc.t))) => unit,
  visit_pattern: (ctx, P.t(Loc.t, Loc.t)) => visit_action,
}
and ctx = {
  handler: visit_handler,
  parents: list(APS.parent),
};

let do_nothing = (ctx, _) => Continue(ctx);
let wrap_nothing = (_, _) => ();

let default_visit_handler = {
  enter_statement: wrap_nothing,
  leave_statement: wrap_nothing,
  enter_function: wrap_nothing,
  leave_function: wrap_nothing,
  enter_block: wrap_nothing,
  leave_block: wrap_nothing,
  visit_statement: do_nothing,
  visit_expression: do_nothing,
  visit_function: do_nothing,
  visit_block: do_nothing,
  visit_pattern: do_nothing,
};

let visit_list = (ctx, visit, list) => List.iter(visit(ctx), list);

let visit_if_some = (ctx, visit) =>
  fun
  | None => ()
  | Some(item) => visit(ctx, item);

let rec visit_statement = (ctx, (loc, statement): S.t(Loc.t, Loc.t)) => {
  let () = ctx.handler.enter_statement(ctx, (loc, statement));
  let action = ctx.handler.visit_statement(ctx, (loc, statement));
  let () =
    switch (action) {
    | Break => ()
    | Continue(ctx) =>
      let ctx = {
        ...ctx,
        parents: APS.push_statement((loc, statement), ctx.parents),
      };

      switch (statement) {
      | S.Empty => ()

      | S.Block(block) => visit_block(ctx, (loc, block))

      | S.Expression({expression, directive: _directive}) =>
        visit_expression(ctx, expression)

      | S.If({test, consequent, alternate}) =>
        visit_expression(ctx, test);
        visit_statement(ctx, consequent);
        visit_if_some(ctx, visit_statement, alternate);

      | S.Labeled({label: (_loc, _label), body}) =>
        visit_statement(ctx, body)

      | S.Break({label: _label}) => ()

      | S.Continue({label: _label}) => ()

      | S.With({_object, body}) => visit_statement(ctx, body)

      | S.TypeAlias(_) => ()

      | S.Switch({discriminant, cases}) =>
        visit_expression(ctx, discriminant);
        visit_list(
          ctx,
          (ctx, (_loc, {S.Switch.Case.test, consequent})) => {
            visit_if_some(ctx, visit_expression, test);
            visit_list(ctx, visit_statement, consequent);
          },
          cases,
        );

      | S.Return({argument}) =>
        visit_if_some(ctx, visit_expression, argument)

      | S.Throw({argument}) => visit_expression(ctx, argument)

      | S.Try({block, handler: try_handler, finalizer}) =>
        visit_block(ctx, block);
        visit_if_some(
          ctx,
          (ctx, (_loc, {S.Try.CatchClause.param, body})) => {
            visit_if_some(ctx, visit_pattern, param);
            visit_block(ctx, body);
          },
          try_handler,
        );
        visit_if_some(ctx, visit_block, finalizer);

      | S.While({test, body}) =>
        visit_expression(ctx, test);
        visit_statement(ctx, body);

      | S.DoWhile({body, test}) =>
        visit_statement(ctx, body);
        visit_expression(ctx, test);

      | S.For({init, test, update, body}) =>
        visit_if_some(
          ctx,
          (ctx, init) =>
            switch (init) {
            | S.For.InitDeclaration(decl) =>
              visit_variable_declaration(ctx, decl)
            | S.For.InitExpression(expression) =>
              visit_expression(ctx, expression)
            },
          init,
        );
        visit_if_some(ctx, visit_expression, test);
        visit_if_some(ctx, visit_expression, update);
        visit_statement(ctx, body);

      | S.ForIn({left, right, body, each: _each}) =>
        switch (left) {
        | S.ForIn.LeftDeclaration(decl) =>
          visit_variable_declaration(ctx, decl)
        | S.ForIn.LeftPattern(pattern) => visit_pattern(ctx, pattern)
        };
        visit_expression(ctx, right);
        visit_statement(ctx, body);

      | S.ForOf({left, right, body, async: _async}) =>
        switch (left) {
        | S.ForOf.LeftDeclaration(decl) =>
          visit_variable_declaration(ctx, decl)
        | S.ForOf.LeftPattern(pattern) => visit_pattern(ctx, pattern)
        };
        visit_expression(ctx, right);
        visit_statement(ctx, body);

      | S.FunctionDeclaration(func) => visit_function(ctx, (loc, func))

      | S.VariableDeclaration(decl) =>
        visit_variable_declaration(ctx, (loc, decl))

      | S.ClassDeclaration(cls) => visit_class(ctx, cls)

      | S.ExportDefaultDeclaration({declaration, _}) =>
        switch (declaration) {
        | S.ExportDefaultDeclaration.Declaration(stmt) =>
          visit_statement(ctx, stmt)
        | S.ExportDefaultDeclaration.Expression(expr) =>
          visit_expression(ctx, expr)
        }

      | S.ExportNamedDeclaration({declaration, _}) =>
        visit_if_some(ctx, visit_statement, declaration)

      | S.Debugger => ()
      | S.InterfaceDeclaration(_) => ()
      | S.ImportDeclaration(_) => ()
      | S.DeclareVariable(_) => ()
      | S.DeclareFunction(_) => ()
      | S.DeclareClass(_) => ()
      | S.DeclareModule(_) => ()
      | S.DeclareModuleExports(_) => ()
      | S.DeclareExportDeclaration(_) => ()
      | S.DeclareInterface(_) => ()
      | S.DeclareTypeAlias(_) => ()
      | S.DeclareOpaqueType(_) => ()
      | S.OpaqueType(_) => ()
      };
    };

  ctx.handler.leave_statement(ctx, (loc, statement));
}
and visit_class = (ctx, {Class.body: (_, {body}), extends, _}) => {
  visit_if_some(
    ctx,
    (ctx, (_, {Class.Extends.expr, _})) => visit_expression(ctx, expr),
    extends,
  );
  visit_list(
    ctx,
    (ctx, item) =>
      switch (item) {
      | Class.Body.Method((
          _loc,
          {
            kind: _kind,
            key: _key,
            value,
            static: _static,
            decorators: _decorators,
          },
        )) =>
        visit_function(ctx, value)
      | Class.Body.Property((_loc, {key, value, _})) =>
        visit_object_property_key(ctx, key);
        visit_if_some(ctx, visit_expression, value);
      | Class.Body.PrivateField((_loc, {value, _})) =>
        visit_if_some(ctx, visit_expression, value)
      },
    body,
  );
}
and visit_expression = (ctx, (loc, expression) as expr) => {
  let action = ctx.handler.visit_expression(ctx, (loc, expression));
  switch (action) {
  | Break => ()
  | Continue(ctx) =>
    let ctx = {...ctx, parents: APS.push_expression(expr, ctx.parents)};
    switch (expression) {
    | E.Import(_) => ()
    | E.This => ()
    | E.Super => ()
    | E.Array({elements}) =>
      visit_list(
        ctx,
        ctx =>
          fun
          | None => ()
          | Some(element) => visit_expression_or_spread(ctx, element),
        elements,
      )
    | E.Object({properties}) =>
      visit_list(
        ctx,
        (ctx, prop) =>
          switch (prop) {
          | E.Object.Property(property) =>
            visit_object_property(ctx, property)
          | E.Object.SpreadProperty((_, {argument})) =>
            visit_expression(ctx, argument)
          },
        properties,
      )

    | E.Function(func) => visit_function(ctx, (loc, func))

    | E.ArrowFunction(func) => visit_function(ctx, (loc, func))

    | E.Sequence({expressions}) =>
      visit_list(ctx, visit_expression, expressions)

    | E.Unary({operator: _operator, prefix: _prefix, argument}) =>
      visit_expression(ctx, argument)

    | E.Binary({operator: _operator, left, right}) =>
      visit_expression(ctx, left);
      visit_expression(ctx, right);

    | E.Assignment({operator: _operator, left, right}) =>
      visit_pattern(ctx, left);
      visit_expression(ctx, right);

    | E.Update({operator: _operator, argument, prefix: _prefix}) =>
      visit_expression(ctx, argument)

    | E.Logical({operator: _operator, left, right}) =>
      visit_expression(ctx, left);
      visit_expression(ctx, right);

    | E.Conditional({test, consequent, alternate}) =>
      visit_expression(ctx, test);
      visit_expression(ctx, consequent);
      visit_expression(ctx, alternate);

    | E.New({callee, arguments, _}) =>
      visit_expression(ctx, callee);
      visit_list(ctx, visit_expression_or_spread, arguments);

    | E.OptionalCall({call: {callee, arguments, _}, _})
    | E.Call({callee, arguments, _}) =>
      visit_expression(ctx, callee);
      visit_list(ctx, visit_expression_or_spread, arguments);

    | E.OptionalMember({member: {_object, property, _}, _})
    | E.Member({_object, property, _}) =>
      visit_expression(ctx, _object);
      switch (property) {
      | E.Member.PropertyExpression(expr) => visit_expression(ctx, expr)
      | E.Member.PropertyIdentifier(_) => ()
      | E.Member.PropertyPrivateName(_) => ()
      };

    | E.Yield({argument, delegate: _delegate}) =>
      visit_if_some(ctx, visit_expression, argument)

    | E.Class(cls) => visit_class(ctx, cls)

    | E.TemplateLiteral({expressions, _}) =>
      visit_list(ctx, visit_expression, expressions)

    | E.TaggedTemplate({tag, quasi: (_, {expressions, _})}) =>
      visit_expression(ctx, tag);
      visit_list(ctx, visit_expression, expressions);

    | E.Comprehension(_) => ()
    | E.Generator(_) => ()
    | E.Identifier(_) => ()
    | E.Literal(_) => ()
    | E.JSXElement(_) => ()
    | E.JSXFragment(_) => ()
    | E.TypeCast(_) => ()
    | E.MetaProperty(_) => ()
    };
  };
}
and visit_pattern = (ctx, (_loc, pattern) as p: P.t(Loc.t, Loc.t)) =>
  switch (ctx.handler.visit_pattern(ctx, p)) {
  | Break => ()
  | Continue(ctx) =>
    switch (pattern) {
    | P.Object({properties, _}) =>
      visit_list(
        ctx,
        (ctx, prop) =>
          switch (prop) {
          | P.Object.Property((
              _,
              {key: _key, pattern, shorthand: _shorthand},
            )) =>
            visit_pattern(ctx, pattern)
          | P.Object.RestProperty((_, {argument})) =>
            visit_pattern(ctx, argument)
          },
        properties,
      )

    | P.Array({elements, _}) =>
      visit_list(
        ctx,
        (ctx, element) =>
          switch (element) {
          | None => ()
          | Some(P.Array.Element(pattern)) => visit_pattern(ctx, pattern)
          | Some(P.Array.RestElement((_, {argument}))) =>
            visit_pattern(ctx, argument)
          },
        elements,
      )

    | P.Assignment({left, right}) =>
      visit_pattern(ctx, left);
      visit_expression(ctx, right);

    | P.Identifier(_) => ()

    | P.Expression(expr) => visit_expression(ctx, expr)
    }
  }
and visit_object_property = (ctx, (_, value)) =>
  switch (value) {
  | E.Object.Property.Init({key, value, _}) =>
    visit_object_property_key(ctx, key);
    visit_expression(ctx, value);
  | E.Object.Property.Method({key, value}) =>
    visit_object_property_key(ctx, key);
    visit_function(ctx, value);
  | E.Object.Property.Get({key, value}) =>
    visit_object_property_key(ctx, key);
    visit_function(ctx, value);
  | E.Object.Property.Set({key, value}) =>
    visit_object_property_key(ctx, key);
    visit_function(ctx, value);
  }
and visit_object_property_key = (ctx, key) =>
  switch (key) {
  | E.Object.Property.Literal(_lit) => ()
  | E.Object.Property.Identifier(_id) => ()
  | E.Object.Property.Computed(expr) => visit_expression(ctx, expr)
  | E.Object.Property.PrivateName(_private_name) => ()
  }
and visit_function = (ctx, (_, {F.params, body, _}) as func) => {
  let () = ctx.handler.enter_function(ctx, func);
  let action = ctx.handler.visit_function(ctx, func);
  let () =
    switch (action) {
    | Break => ()
    | Continue(ctx) =>
      let ctx = {...ctx, parents: APS.push_function(func, ctx.parents)};
      let (_, {F.Params.params, rest}) = params;
      visit_list(ctx, visit_pattern, params);
      visit_if_some(
        ctx,
        (ctx, (_, {F.RestElement.argument})) =>
          visit_pattern(ctx, argument),
        rest,
      );
      switch (body) {
      | F.BodyBlock(block) => visit_block(ctx, block)
      | F.BodyExpression(expr) => visit_expression(ctx, expr)
      };
    };

  ctx.handler.leave_function(ctx, func);
}
and visit_block = (ctx, (_, {body}) as block) => {
  let () = ctx.handler.enter_block(ctx, block);
  let visit_action = ctx.handler.visit_block(ctx, block);
  let () =
    switch (visit_action) {
    | Break => ()
    | Continue(ctx) =>
      visit_list(
        {...ctx, parents: APS.push_block(block, ctx.parents)},
        visit_statement,
        body,
      )
    };

  ctx.handler.leave_block(ctx, block);
}
and visit_variable_declaration = (ctx, (_, {declarations, kind: _kind})) =>
  visit_list(ctx, visit_variable_declarator, declarations)
and visit_variable_declarator = (ctx, (_, {init, id})) => {
  visit_pattern(ctx, id);
  switch (init) {
  | None => ()
  | Some(expr) => visit_expression(ctx, expr)
  };
}
and visit_expression_or_spread = (ctx, item) =>
  switch (item) {
  | E.Expression(expression) => visit_expression(ctx, expression)
  | E.Spread((_, {argument})) => visit_expression(ctx, argument)
  };

let visit = (handler, program) => {
  let ctx = {parents: [], handler};
  let (_, statements, _) = program;
  visit_list(ctx, visit_statement, statements);
};
