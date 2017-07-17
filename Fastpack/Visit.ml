module Expression = Spider_monkey_ast.Expression
module Pattern = Spider_monkey_ast.Pattern
module Statement = Spider_monkey_ast.Statement
module Literal = Spider_monkey_ast.Literal
module Type = Spider_monkey_ast.Type
module Variance = Spider_monkey_ast.Variance
module Class = Spider_monkey_ast.Class

type visit_action = Continue | Break

type visit_handler = {
  visit_statement : Statement.t -> visit_action;
  visit_expression : Expression.t -> visit_action;
}


let default_visit_handler =
  let do_nothing _ = Continue in
  {
    visit_statement = do_nothing;
    visit_expression = do_nothing
  }

let visit_list (handler : visit_handler) visit list =
  List.iter (visit handler) list

let visit_if_some handler visit = function
  | None -> ()
  | Some item -> visit handler item

let rec visit_statement handler ((loc, statement) : Statement.t) =
  let action = handler.visit_statement (loc, statement) in
  match action with
  | Break -> ()
  | Continue ->
    match statement with
    | Statement.Empty ->
      ()

    | Statement.Block { body } ->
      visit_list handler visit_statement body

    | Statement.Expression { expression; directive = _directive } ->
      visit_expression handler expression

    | Statement.If { test; consequent; alternate } ->
      visit_expression handler test;
      visit_statement handler consequent;
      visit_if_some handler visit_statement alternate

    | Statement.Labeled { label = (_loc, _label); body } ->
      visit_statement handler body

    | Statement.Break { label = _label } ->
      ()

    | Statement.Continue { label = _label } ->
      ()

    | Statement.With { _object; body } ->
      visit_statement handler body

    | Statement.TypeAlias {
        id = _id;
        typeParameters = _typeParameters;
        right = _right
      } ->
      ()

    | Statement.Switch { discriminant; cases } ->
      visit_expression handler discriminant;
      visit_list handler (fun handler (_loc, { Statement.Switch.Case. test; consequent }) ->
          visit_if_some handler visit_expression test;
          visit_list handler visit_statement consequent
        ) cases

    | Statement.Return { argument } ->
      visit_if_some handler visit_expression argument

    | Statement.Throw { argument } ->
      visit_expression handler argument

    | Statement.Try { block; handler = _handler; finalizer } ->
      visit_block handler block;
      visit_if_some handler (fun handler (_loc, { Statement.Try.CatchClause. param; body }) ->
          visit_pattern handler param;
          visit_block handler body
        ) _handler;
      visit_if_some handler visit_block finalizer

    | Statement.While { test; body } ->
      visit_expression handler test;
      visit_statement handler body

    | Statement.DoWhile { body; test } ->
      visit_statement handler body;
      visit_expression handler test;

    | Statement.For { init; test; update; body } ->
      visit_if_some handler(fun handler init -> match init with
          | Statement.For.InitDeclaration decl -> visit_variable_declaration handler decl
          | Statement.For.InitExpression expression -> visit_expression handler expression) init;
      visit_if_some handler visit_expression test;
      visit_if_some handler visit_expression update;
      visit_statement handler body;

    | Statement.ForIn { left; right; body; each = _each } ->
      (match left with
       | Statement.ForIn.LeftDeclaration decl -> visit_variable_declaration handler decl
       | Statement.ForIn.LeftExpression expression -> visit_expression handler expression);
      visit_expression handler right;
      visit_statement handler body

    | Statement.ForOf { left; right; body; async = _async } ->
      (match left with
       | Statement.ForOf.LeftDeclaration decl -> visit_variable_declaration handler decl
       | Statement.ForOf.LeftExpression expression -> visit_expression handler expression);
      visit_expression handler right;
      visit_statement handler body

    | Statement.FunctionDeclaration func ->
      visit_function handler (loc, func)

    | Statement.VariableDeclaration decl ->
      visit_variable_declaration handler (loc, decl)

    | Statement.ClassDeclaration {
        id = _id;
        body = (_, { body });
        superClass;
        typeParameters = _typeParameters;
        superTypeParameters = _superTypeParameters;
        implements = _implements;
        classDecorators = _classDecorators;
      } ->
      (** TODO: handle `classDecorators` *)
      (** TODO: handle `implements` *)
      visit_if_some handler visit_expression superClass;
      visit_list handler (fun handler item -> match item with
          | Class.Body.Method (_loc, {
              kind = _kind;
              key = _key;
              value;
              static = _static;
              decorators = _decorators
            }) ->
            visit_function handler value
          | Class.Body.Property (_loc, {
              key;
              value;
              typeAnnotation = _typeAnnotation;
              static = _static;
              variance = _variance;
            }) ->
            visit_object_property_key handler key;
            visit_if_some handler visit_expression value
        ) body

    | Statement.Debugger -> ()
    | Statement.InterfaceDeclaration _ -> ()
    | Statement.ExportNamedDeclaration _ -> ()
    | Statement.ExportDefaultDeclaration _ -> ()
    | Statement.ImportDeclaration _ -> ()
    | Statement.DeclareVariable _ -> ()
    | Statement.DeclareFunction _ -> ()
    | Statement.DeclareClass _ -> ()
    | Statement.DeclareModule _ -> ()
    | Statement.DeclareModuleExports _ -> ()
    | Statement.DeclareExportDeclaration _ -> ()

and visit_expression handler ((loc, expression) : Expression.t) =
  let action = handler.visit_expression (loc, expression) in
  match action with
  | Break -> ()
  | Continue ->
    match expression with
    | Expression.This -> ()
    | Expression.Super -> ()
    | Expression.Array { elements } ->
      visit_list
        handler
        (fun handler -> function
           | None -> ()
           | Some element -> visit_expression_or_spread handler element)
        elements
    | Expression.Object { properties } ->
      visit_list
        handler
        (fun handler prop -> match prop with
           | Expression.Object.Property property ->
             visit_object_property handler property
           | Expression.Object.SpreadProperty (_, { argument }) ->
             visit_expression handler argument
        )
        properties

    | Expression.Function func ->
      visit_function handler (loc, func)

    | Expression.ArrowFunction func ->
      visit_function handler (loc, func)

    | Expression.Sequence { expressions } ->
      visit_list handler visit_expression expressions

    | Expression.Unary { operator = _operator; prefix = _prefix; argument } ->
      visit_expression handler argument

    | Expression.Binary { operator = _operator; left; right } ->
      visit_expression handler left;
      visit_expression handler right

    | Expression.Assignment { operator = _operator; left; right } ->
      visit_pattern handler left;
      visit_expression handler right

    | Expression.Update { operator = _operator; argument; prefix = _prefix } ->
      visit_expression handler argument

    | Expression.Logical { operator = _operator; left; right } ->
      visit_expression handler left;
      visit_expression handler right

    | Expression.Conditional { test; consequent; alternate } ->
      visit_expression handler test;
      visit_expression handler consequent;
      visit_expression handler alternate

    | Expression.New { callee; arguments } ->
      visit_expression handler callee;
      visit_list handler visit_expression_or_spread arguments

    | Expression.Call { callee; arguments } ->
      visit_expression handler callee;
      visit_list handler visit_expression_or_spread arguments

    | Expression.Member { _object; property = _property; computed = _computed } ->
      visit_expression handler _object

    | Expression.Yield { argument; delegate = _delegate } ->
      visit_if_some handler visit_expression argument

    | Expression.Comprehension _ -> ()
    | Expression.Generator _ -> ()
    | Expression.Identifier _ -> ()
    | Expression.Literal _ -> ()
    | Expression.TemplateLiteral _ -> ()
    | Expression.TaggedTemplate _ -> ()
    | Expression.JSXElement _ -> ()
    | Expression.Class _ -> ()
    | Expression.TypeCast _ -> ()
    | Expression.MetaProperty _ -> ()

and visit_pattern (handler : visit_handler) ((_loc, pattern) : Pattern.t) =
  match pattern with

  | Pattern.Object { properties; typeAnnotation = _typeAnnotation } ->
    visit_list
      handler
      (fun handler prop -> match prop with
         | Pattern.Object.Property (_,{ key = _key; pattern; shorthand = _shorthand }) ->
           visit_pattern handler pattern
         | Pattern.Object.RestProperty (_,{ argument }) ->
           visit_pattern handler argument
      ) properties

  | Pattern.Array { elements; typeAnnotation = _typeAnnotation } ->
    visit_list
      handler
      (fun handler element -> match element with
         | None -> ()
         | Some (Pattern.Array.Element pattern) ->
           visit_pattern handler pattern
         | Some (Pattern.Array.RestElement (_,{ argument })) ->
           visit_pattern handler argument)
      elements

  | Pattern.Assignment { left; right } ->
    visit_pattern handler left;
    visit_expression handler right

  | Pattern.Identifier { name = _name; typeAnnotation = _typeAnnotation; optional = _optional } -> ()

  | Pattern.Expression expr -> visit_expression handler expr

and visit_object_property handler (_, {
               key;
               value;
               _method;
               shorthand = _shorthand;
             }) =
  match value with
  | Expression.Object.Property.Init expr ->
    visit_object_property_key handler key;
    visit_expression handler expr
  | Expression.Object.Property.Get func -> visit_function handler func
  | Expression.Object.Property.Set func -> visit_function handler func


and visit_object_property_key handler key =
  match key with
  | Expression.Object.Property.Literal _lit ->
    ()
  | Expression.Object.Property.Identifier _id ->
    ()
  | Expression.Object.Property.Computed expr ->
    visit_expression handler expr

and visit_function handler (_loc, {
    Spider_monkey_ast.Function.
    id = _id;
    params;
    body;
    async = _async;
    generator = _generator;
    predicate = _predicate;
    expression = _expression;
    returnType = _returnType;
    typeParameters = _typeParameters;
  }) =
  (** TODO: handle `predicate` *)
  (
    let (params, rest) = params in
    visit_list handler visit_pattern params;
    visit_if_some handler (fun handler (_loc, { Spider_monkey_ast.Function.RestElement. argument }) ->
        visit_pattern handler argument) rest
  );
  (match body with
   | Spider_monkey_ast.Function.BodyBlock block -> visit_block handler block
   | Spider_monkey_ast.Function.BodyExpression expr -> visit_expression handler expr)

and visit_block handler ((_loc, block) : (Loc.t * Statement.Block.t)) =
  visit_list handler visit_statement block.body

and visit_variable_declaration handler (_, { declarations; kind = _kind }) =
  visit_list handler
    (fun handler (_, { Statement.VariableDeclaration.Declarator. init; id = _id }) ->
       (match init with
        | None  -> ();
        | Some expr -> visit_expression handler expr);
       ()
    )
    declarations;

and visit_expression_or_spread handler item = match item with
  | Expression.Expression expression -> visit_expression handler expression
  | Expression.Spread (_, { argument }) -> visit_expression handler argument


let visit handler program =

  let visit_program ((_, statements, _): Spider_monkey_ast.program) =
    visit_list handler visit_statement statements
  in

  visit_program program
