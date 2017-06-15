module Expression = Spider_monkey_ast.Expression
module Pattern = Spider_monkey_ast.Pattern
module Statement = Spider_monkey_ast.Statement
module Literal = Spider_monkey_ast.Literal
module Type = Spider_monkey_ast.Type
module Variance = Spider_monkey_ast.Variance
module Class = Spider_monkey_ast.Class

type visit_handler = {
  visit_statement : Statement.t -> unit;
  visit_expression : Expression.t -> unit;
}

let default_visit_handler =
  let do_nothing _ = () in
  {
    visit_statement = do_nothing;
    visit_expression = do_nothing
  }

let visit_list visit list =
  List.iter visit list

let visit_if_some visit = function
  | None -> ()
  | Some item -> visit item

let visit visiter program =

  let rec visit_statement ((loc, statement) : Statement.t) =
    visiter.visit_statement (loc, statement);
    match statement with
    | Statement.Empty ->
      ()

    | Statement.Block { body } ->
      visit_list visit_statement body

    | Statement.Expression { expression } ->
      visit_expression expression

    | Statement.If { test; consequent; alternate } ->
      visit_expression test;
      visit_statement consequent;
      visit_if_some visit_statement alternate

    | Statement.Labeled { label = (loc, label); body } ->
      visit_statement body

    | Statement.Break { label } ->
      ()

    | Statement.Continue { label } ->
      ()

    | Statement.With { _object; body } ->
      visit_statement body

    | Statement.TypeAlias { id = (_, id); typeParameters; right } ->
      ()

    | Statement.Switch { discriminant; cases } ->
      visit_expression discriminant;
      visit_list (fun (_loc, { Statement.Switch.Case. test; consequent }) ->
          visit_if_some visit_expression test;
          visit_list visit_statement consequent
        ) cases

    | Statement.Return { argument } ->
      visit_if_some visit_expression argument

    | Statement.Throw { argument } ->
      visit_expression argument

    | Statement.Try { block; handler; finalizer } ->
      visit_block block;
      visit_if_some (fun (_loc, { Statement.Try.CatchClause. param; body }) ->
          visit_pattern param;
          visit_block body
        ) handler;
      visit_if_some visit_block finalizer

    | Statement.While { test; body } ->
      visit_expression test;
      visit_statement body

    | Statement.DoWhile { body; test } ->
      visit_statement body;
      visit_expression test;

    | Statement.For { init; test; update; body } ->
      visit_if_some (fun init -> match init with
          | Statement.For.InitDeclaration decl -> visit_variable_declaration decl
          | Statement.For.InitExpression expression -> visit_expression
                                                         expression) init;
      visit_if_some visit_expression test;
      visit_if_some visit_expression update;
      visit_statement body;

    | Statement.ForIn { left; right; body; each } ->
      (match left with
       | Statement.ForIn.LeftDeclaration decl -> visit_variable_declaration decl
       | Statement.ForIn.LeftExpression expression -> visit_expression expression);
      visit_expression right;
      visit_statement body

    | Statement.ForOf { left; right; body; async } ->
      (match left with
       | Statement.ForOf.LeftDeclaration decl -> visit_variable_declaration decl
       | Statement.ForOf.LeftExpression expression -> visit_expression expression);
      visit_expression right;
      visit_statement body

    | Statement.FunctionDeclaration func ->
      visit_function (loc, func)

    | Statement.VariableDeclaration decl ->
      visit_variable_declaration (loc, decl)

    | Statement.ClassDeclaration { id; body = (_, { body }); superClass; typeParameters; superTypeParameters; implements;
                                   classDecorators } ->
      (** TODO: handle `classDecorators` *)
      (** TODO: handle `implements` *)
      visit_if_some visit_expression superClass;
      visit_list (fun item -> match item with
          | Class.Body.Method (_loc, { kind; key; value; static; decorators }) ->
            visit_function value
          | Class.Body.Property (loc, { key; value; typeAnnotation; static; variance }) ->
            visit_object_property_key key;
            visit_if_some visit_expression value
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

  and visit_expression ((loc, expression) : Expression.t) =
    visiter.visit_expression (loc, expression);
    match expression with
    | Expression.This -> ()
    | Expression.Super -> ()
    | Expression.Array { elements } ->
      visit_list
        (function
          | None -> ()
          | Some element -> visit_expression_or_spread element)
        elements
    | Expression.Object { properties } ->
      visit_list
        (fun prop -> match prop with
           | Expression.Object.Property (_, { key; value; _method; shorthand }) ->
             (match value with
              | Expression.Object.Property.Init expr ->
                visit_object_property_key key; visit_expression expr
              | Expression.Object.Property.Get func -> visit_function func
              | Expression.Object.Property.Set func -> visit_function func)
           | Expression.Object.SpreadProperty (_, { argument }) ->
             visit_expression argument
        )
        properties

    | Expression.Function func ->
      visit_function (loc, func)

    | Expression.ArrowFunction func ->
      visit_function (loc, func)

    | Expression.Sequence { expressions } ->
      visit_list visit_expression expressions

    | Expression.Unary { operator; prefix; argument } ->
      visit_expression argument

    | Expression.Binary { operator; left; right } ->
      visit_expression left;
      visit_expression right

    | Expression.Assignment { operator; left; right } ->
      visit_pattern left;
      visit_expression right

    | Expression.Update { operator; argument; prefix } ->
      visit_expression argument

    | Expression.Logical { operator; left; right } ->
      visit_expression left;
      visit_expression right

    | Expression.Conditional { test; consequent; alternate } ->
      visit_expression test;
      visit_expression consequent;
      visit_expression alternate

    | Expression.New { callee; arguments } ->
      visit_expression callee;
      visit_list visit_expression_or_spread arguments

    | Expression.Call { callee; arguments } ->
      visit_expression callee;
      visit_list visit_expression_or_spread arguments

    | Expression.Member { _object; property; computed } ->
      visit_expression _object

    | Expression.Yield { argument; delegate } ->
      visit_if_some visit_expression argument

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

  and visit_pattern ((loc, pattern) : Pattern.t) =
    match pattern with

    | Pattern.Object { properties; typeAnnotation } ->
      visit_list
        (fun prop -> match prop with
           | Pattern.Object.Property (_,{ key; pattern; shorthand }) ->
             visit_pattern pattern
           | Pattern.Object.RestProperty (_,{ argument }) ->
             visit_pattern argument
        ) properties

    | Pattern.Array { elements; typeAnnotation } ->
      visit_list
        (fun element -> match element with
           | None -> ()
           | Some (Pattern.Array.Element pattern) ->
             visit_pattern pattern
           | Some (Pattern.Array.RestElement (_,{ argument })) ->
             visit_pattern argument)
        elements

    | Pattern.Assignment { left; right } ->
      visit_pattern left;
      visit_expression right

    | Pattern.Identifier { name; typeAnnotation; optional } -> ()

    | Pattern.Expression expr -> visit_expression expr

  and visit_object_property_key key =
    match key with
    | Expression.Object.Property.Literal lit ->
      ()
    | Expression.Object.Property.Identifier id ->
      ()
    | Expression.Object.Property.Computed expr ->
      visit_expression expr

  and visit_function (loc, { Spider_monkey_ast.Function. id; params; body; async; generator; predicate;
                             expression; returnType; typeParameters }) =
    (** TODO: handle `predicate` *)
    (
      let (params, rest) = params in
      visit_list visit_pattern params;
      visit_if_some (fun (_loc, { Spider_monkey_ast.Function.RestElement. argument }) ->
          visit_pattern argument) rest
    );
    (match body with
     | Spider_monkey_ast.Function.BodyBlock block -> visit_block block
     | Spider_monkey_ast.Function.BodyExpression expr -> visit_expression expr)

  and visit_block ((loc, block) : (Loc.t * Statement.Block.t)) =
    visit_list visit_statement block.body

  and visit_variable_declaration value =
    (* TODO: *)
    ()

  and visit_expression_or_spread item = match item with
    | Expression.Expression expression -> visit_expression expression
    | Expression.Spread (_, { argument }) -> visit_expression argument

  in

  let visit_program ((_, statements, _): Spider_monkey_ast.program) =
    visit_list visit_statement statements
  in

  visit_program program
