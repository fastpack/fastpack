module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module Expression = Ast.Expression
module Pattern = Ast.Pattern
module Statement = Ast.Statement
module Literal = Ast.Literal
module Type = Ast.Type
module Variance = Ast.Variance
module Class = Ast.Class
module Function = Ast.Function


type visit_action = Continue | Break

type visit_handler = {
  visit_statement : Loc.t Statement.t -> visit_action;
  enter_statement : Loc.t Statement.t -> unit;
  leave_statement : Loc.t Statement.t -> unit;

  visit_expression : Loc.t Expression.t -> visit_action;

  visit_function : (Loc.t * Loc.t Function.t) -> visit_action;
  enter_function : (Loc.t * Loc.t Function.t) -> unit;
  leave_function : (Loc.t * Loc.t Function.t) -> unit;

  visit_block : (Loc.t * Loc.t Statement.Block.t) -> visit_action;
  enter_block : (Loc.t * Loc.t Statement.Block.t) -> unit;
  leave_block : (Loc.t * Loc.t Statement.Block.t) -> unit;

  visit_pattern : Loc.t Pattern.t -> visit_action;
}

let do_nothing _ = Continue
let wrap_nothing _ = ()

let default_visit_handler =
  {
    enter_statement = wrap_nothing;
    leave_statement = wrap_nothing;
    enter_function = wrap_nothing;
    leave_function = wrap_nothing;
    enter_block = wrap_nothing;
    leave_block = wrap_nothing;
    visit_statement = do_nothing;
    visit_expression = do_nothing;
    visit_function = do_nothing;
    visit_block = do_nothing;
    visit_pattern = do_nothing;
  }

let visit_list (handler : visit_handler) visit list =
  List.iter (visit handler) list

let visit_if_some handler visit = function
  | None -> ()
  | Some item -> visit handler item

let rec visit_statement handler ((loc, statement) : Loc.t Statement.t) =
  let () = handler.enter_statement (loc, statement) in
  let action = handler.visit_statement (loc, statement) in
  let () =
    match action with
    | Break -> ()
    | Continue ->
      match statement with
      | Statement.Empty ->
        ()

      | Statement.Block block ->
        visit_block handler (loc, block)

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
         | Statement.ForIn.LeftPattern pattern -> visit_pattern handler pattern);
        visit_expression handler right;
        visit_statement handler body

      | Statement.ForOf { left; right; body; async = _async } ->
        (match left with
         | Statement.ForOf.LeftDeclaration decl -> visit_variable_declaration handler decl
         | Statement.ForOf.LeftPattern pattern -> visit_pattern handler pattern);
        visit_expression handler right;
        visit_statement handler body

      | Statement.FunctionDeclaration func ->
        visit_function handler (loc, func)

      | Statement.VariableDeclaration decl ->
        visit_variable_declaration handler (loc, decl)

      | Statement.ClassDeclaration cls ->
        visit_class handler cls

      | Statement.ExportDefaultDeclaration { declaration; _ } ->
        (match declaration with
         | Statement.ExportDefaultDeclaration.Declaration stmt ->
           visit_statement handler stmt
         | Statement.ExportDefaultDeclaration.Expression expr ->
           visit_expression handler expr
        )

      | Statement.ExportNamedDeclaration { declaration; _ } ->
        visit_if_some handler visit_statement declaration;

      | Statement.Debugger -> ()
      | Statement.InterfaceDeclaration _ -> ()
      | Statement.ImportDeclaration _ -> ()
      | Statement.DeclareVariable _ -> ()
      | Statement.DeclareFunction _ -> ()
      | Statement.DeclareClass _ -> ()
      | Statement.DeclareModule _ -> ()
      | Statement.DeclareModuleExports _ -> ()
      | Statement.DeclareExportDeclaration _ -> ()
      | Statement.DeclareInterface _ -> ()
      | Statement.DeclareTypeAlias _ -> ()
      | Statement.DeclareOpaqueType _ -> ()
      | Statement.OpaqueType _ -> ()
  in
  handler.leave_statement (loc, statement)

and visit_class handler {Class. body = (_, { body }); superClass; _} =
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
      | Class.Body.PrivateField (_loc, {
          key = _key;
          value;
          typeAnnotation = _typeAnnotation;
          static = _static;
          variance = _variance
        }) ->
        visit_if_some handler visit_expression value
    ) body

and visit_expression handler ((loc, expression) : Loc.t Expression.t) =
  let action = handler.visit_expression (loc, expression) in
  match action with
  | Break -> ()
  | Continue ->
    match expression with
    | Expression.Import _ -> ()
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

    | Expression.Member { _object; property; computed = _computed } ->
      visit_expression handler _object;
      begin
      match property with
      | Expression.Member.PropertyExpression expr ->
        visit_expression handler expr
      | Expression.Member.PropertyIdentifier _ -> ()
      | Expression.Member.PropertyPrivateName _ -> ()
      end;
    | Expression.Yield { argument; delegate = _delegate } ->
      visit_if_some handler visit_expression argument

    | Expression.Comprehension _ -> ()
    | Expression.Generator _ -> ()
    | Expression.Identifier _ -> ()
    | Expression.Literal _ -> ()
    | Expression.TemplateLiteral _ -> ()
    | Expression.TaggedTemplate _ -> ()
    | Expression.JSXElement _ -> ()
    | Expression.JSXFragment _ -> ()
    | Expression.Class cls ->
      visit_class handler cls
    | Expression.TypeCast _ -> ()
    | Expression.MetaProperty _ -> ()

and visit_pattern (handler : visit_handler) ((_loc, pattern) as p : Loc.t Pattern.t) =
  match handler.visit_pattern p with
  | Break -> ()
  | Continue ->
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

and visit_object_property handler (_, value) =
  match value with
  | Expression.Object.Property.Init {key; value; _} ->
    visit_object_property_key handler key;
    visit_expression handler value
  | Expression.Object.Property.Method {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value
  | Expression.Object.Property.Get {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value
  | Expression.Object.Property.Set {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value


and visit_object_property_key handler key =
  match key with
  | Expression.Object.Property.Literal _lit ->
    ()
  | Expression.Object.Property.Identifier _id ->
    ()
  | Expression.Object.Property.Computed expr ->
    visit_expression handler expr
  | Expression.Object.Property.PrivateName _private_name ->
    ()

and visit_function handler (_, {
    Function.
    id = _id;
    params;
    body;
    async = _async;
    generator = _generator;
    predicate = _predicate;
    expression = _expression;
    returnType = _returnType;
    typeParameters = _typeParameters;
  } as func) =
  let () = handler.enter_function func in
  let action = handler.visit_function func in
  let () =
    match action with
    | Break -> ()
    | Continue ->
      (** TODO: handle `predicate` *)
      (
        let (_loc, {Function.Params. params;rest}) = params in
        visit_list handler visit_pattern params;
        visit_if_some handler (fun handler (_loc, { Function.RestElement. argument }) ->
            visit_pattern handler argument) rest
      );
      visit_function_body handler body
  in
  handler.leave_function func

and visit_function_body handler body =
  match body with
  | Function.BodyBlock block -> visit_block handler block
  | Function.BodyExpression expr -> visit_expression handler expr

and visit_block handler ((_, { body }) as block) =
  let () = handler.enter_block block in
  let visit_action = handler.visit_block block in
  let () =
    match visit_action with
    | Break -> ()
    | Continue -> visit_list handler visit_statement body
  in
  handler.leave_block block

and visit_variable_declaration handler (_, { declarations; kind = _kind }) =
  visit_list handler
    visit_variable_declarator
    declarations;

and visit_variable_declarator handler (_, { init; id }) =
  visit_pattern handler id;
  (match init with
   | None  -> ();
   | Some expr -> visit_expression handler expr);

and visit_expression_or_spread handler item = match item with
  | Expression.Expression expression -> visit_expression handler expression
  | Expression.Spread (_, { argument }) -> visit_expression handler argument


let visit handler program =

  let visit_program ((_, statements, _): Loc.t Ast.program) =
    visit_list handler visit_statement statements
  in

  visit_program program
