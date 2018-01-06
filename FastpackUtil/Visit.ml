module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module E = Ast.Expression
module P = Ast.Pattern
module S= Ast.Statement
module Class = Ast.Class
module F = Ast.Function


type visit_action = Continue | Break

type parent = Program
            | Statement of Loc.t S.t
            | Function of Loc.t F.t

type visit_handler = {
  visit_statement : Loc.t S.t -> visit_action;
  enter_statement : Loc.t S.t -> unit;
  leave_statement : Loc.t S.t -> unit;

  visit_expression : Loc.t E.t -> visit_action;

  visit_function : (Loc.t * Loc.t F.t) -> visit_action;
  enter_function : (Loc.t * Loc.t F.t) -> unit;
  leave_function : (Loc.t * Loc.t F.t) -> unit;

  visit_block : (Loc.t * Loc.t S.Block.t) -> visit_action;
  enter_block : (Loc.t * Loc.t S.Block.t) -> unit;
  leave_block : (Loc.t * Loc.t S.Block.t) -> unit;

  visit_pattern : Loc.t P.t -> visit_action;
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

let rec visit_statement handler ((loc, statement) : Loc.t S.t) =
  let () = handler.enter_statement (loc, statement) in
  let action = handler.visit_statement (loc, statement) in
  let () =
    match action with
    | Break -> ()
    | Continue ->
      match statement with
      | S.Empty ->
        ()

      | S.Block block ->
        visit_block handler (loc, block)

      | S.Expression { expression; directive = _directive } ->
        visit_expression handler expression

      | S.If { test; consequent; alternate } ->
        visit_expression handler test;
        visit_statement handler consequent;
        visit_if_some handler visit_statement alternate

      | S.Labeled { label = (_loc, _label); body } ->
        visit_statement handler body

      | S.Break { label = _label } ->
        ()

      | S.Continue { label = _label } ->
        ()

      | S.With { _object; body } ->
        visit_statement handler body

      | S.TypeAlias {
          id = _id;
          typeParameters = _typeParameters;
          right = _right
        } ->
        ()

      | S.Switch { discriminant; cases } ->
        visit_expression handler discriminant;
        visit_list handler (fun handler (_loc, { S.Switch.Case. test; consequent }) ->
            visit_if_some handler visit_expression test;
            visit_list handler visit_statement consequent
          ) cases

      | S.Return { argument } ->
        visit_if_some handler visit_expression argument

      | S.Throw { argument } ->
        visit_expression handler argument

      | S.Try { block; handler = _handler; finalizer } ->
        visit_block handler block;
        visit_if_some handler (fun handler (_loc, { S.Try.CatchClause. param; body }) ->
            visit_pattern handler param;
            visit_block handler body
          ) _handler;
        visit_if_some handler visit_block finalizer

      | S.While { test; body } ->
        visit_expression handler test;
        visit_statement handler body

      | S.DoWhile { body; test } ->
        visit_statement handler body;
        visit_expression handler test;

      | S.For { init; test; update; body } ->
        visit_if_some handler(fun handler init -> match init with
            | S.For.InitDeclaration decl -> visit_variable_declaration handler decl
            | S.For.InitExpression expression -> visit_expression handler expression) init;
        visit_if_some handler visit_expression test;
        visit_if_some handler visit_expression update;
        visit_statement handler body;

      | S.ForIn { left; right; body; each = _each } ->
        (match left with
         | S.ForIn.LeftDeclaration decl -> visit_variable_declaration handler decl
         | S.ForIn.LeftPattern pattern -> visit_pattern handler pattern);
        visit_expression handler right;
        visit_statement handler body

      | S.ForOf { left; right; body; async = _async } ->
        (match left with
         | S.ForOf.LeftDeclaration decl -> visit_variable_declaration handler decl
         | S.ForOf.LeftPattern pattern -> visit_pattern handler pattern);
        visit_expression handler right;
        visit_statement handler body

      | S.FunctionDeclaration func ->
        visit_function handler (loc, func)

      | S.VariableDeclaration decl ->
        visit_variable_declaration handler (loc, decl)

      | S.ClassDeclaration cls ->
        visit_class handler cls

      | S.ExportDefaultDeclaration { declaration; _ } ->
        (match declaration with
         | S.ExportDefaultDeclaration.Declaration stmt ->
           visit_statement handler stmt
         | S.ExportDefaultDeclaration.Expression expr ->
           visit_expression handler expr
        )

      | S.ExportNamedDeclaration { declaration; _ } ->
        visit_if_some handler visit_statement declaration;

      | S.Debugger -> ()
      | S.InterfaceDeclaration _ -> ()
      | S.ImportDeclaration _ -> ()
      | S.DeclareVariable _ -> ()
      | S.DeclareFunction _ -> ()
      | S.DeclareClass _ -> ()
      | S.DeclareModule _ -> ()
      | S.DeclareModuleExports _ -> ()
      | S.DeclareExportDeclaration _ -> ()
      | S.DeclareInterface _ -> ()
      | S.DeclareTypeAlias _ -> ()
      | S.DeclareOpaqueType _ -> ()
      | S.OpaqueType _ -> ()
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

and visit_expression handler ((loc, expression) : Loc.t E.t) =
  let action = handler.visit_expression (loc, expression) in
  match action with
  | Break -> ()
  | Continue ->
    match expression with
    | E.Import _ -> ()
    | E.This -> ()
    | E.Super -> ()
    | E.Array { elements } ->
      visit_list
        handler
        (fun handler -> function
           | None -> ()
           | Some element -> visit_expression_or_spread handler element)
        elements
    | E.Object { properties } ->
      visit_list
        handler
        (fun handler prop -> match prop with
           | E.Object.Property property ->
             visit_object_property handler property
           | E.Object.SpreadProperty (_, { argument }) ->
             visit_expression handler argument
        )
        properties

    | E.Function func ->
      visit_function handler (loc, func)

    | E.ArrowFunction func ->
      visit_function handler (loc, func)

    | E.Sequence { expressions } ->
      visit_list handler visit_expression expressions

    | E.Unary { operator = _operator; prefix = _prefix; argument } ->
      visit_expression handler argument

    | E.Binary { operator = _operator; left; right } ->
      visit_expression handler left;
      visit_expression handler right

    | E.Assignment { operator = _operator; left; right } ->
      visit_pattern handler left;
      visit_expression handler right

    | E.Update { operator = _operator; argument; prefix = _prefix } ->
      visit_expression handler argument

    | E.Logical { operator = _operator; left; right } ->
      visit_expression handler left;
      visit_expression handler right

    | E.Conditional { test; consequent; alternate } ->
      visit_expression handler test;
      visit_expression handler consequent;
      visit_expression handler alternate

    | E.New { callee; arguments } ->
      visit_expression handler callee;
      visit_list handler visit_expression_or_spread arguments

    | E.Call { callee; arguments } ->
      visit_expression handler callee;
      visit_list handler visit_expression_or_spread arguments

    | E.Member { _object; property; computed = _computed } ->
      visit_expression handler _object;
      begin
      match property with
      | E.Member.PropertyExpression expr ->
        visit_expression handler expr
      | E.Member.PropertyIdentifier _ -> ()
      | E.Member.PropertyPrivateName _ -> ()
      end;
    | E.Yield { argument; delegate = _delegate } ->
      visit_if_some handler visit_expression argument

    | E.Comprehension _ -> ()
    | E.Generator _ -> ()
    | E.Identifier _ -> ()
    | E.Literal _ -> ()
    | E.TemplateLiteral _ -> ()
    | E.TaggedTemplate _ -> ()
    | E.JSXElement _ -> ()
    | E.JSXFragment _ -> ()
    | E.Class cls ->
      visit_class handler cls
    | E.TypeCast _ -> ()
    | E.MetaProperty _ -> ()

and visit_pattern (handler : visit_handler) ((_loc, pattern) as p : Loc.t P.t) =
  match handler.visit_pattern p with
  | Break -> ()
  | Continue ->
    match pattern with

    | P.Object { properties; typeAnnotation = _typeAnnotation } ->
      visit_list
        handler
        (fun handler prop -> match prop with
           | P.Object.Property (_,{ key = _key; pattern; shorthand = _shorthand }) ->
             visit_pattern handler pattern
           | P.Object.RestProperty (_,{ argument }) ->
             visit_pattern handler argument
        ) properties

    | P.Array { elements; typeAnnotation = _typeAnnotation } ->
      visit_list
        handler
        (fun handler element -> match element with
           | None -> ()
           | Some (P.Array.Element pattern) ->
             visit_pattern handler pattern
           | Some (P.Array.RestElement (_,{ argument })) ->
             visit_pattern handler argument)
        elements

    | P.Assignment { left; right } ->
      visit_pattern handler left;
      visit_expression handler right

    | P.Identifier { name = _name; typeAnnotation = _typeAnnotation; optional = _optional } -> ()

    | P.Expression expr -> visit_expression handler expr

and visit_object_property handler (_, value) =
  match value with
  | E.Object.Property.Init {key; value; _} ->
    visit_object_property_key handler key;
    visit_expression handler value
  | E.Object.Property.Method {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value
  | E.Object.Property.Get {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value
  | E.Object.Property.Set {key; value} ->
    visit_object_property_key handler key;
    visit_function handler value


and visit_object_property_key handler key =
  match key with
  | E.Object.Property.Literal _lit ->
    ()
  | E.Object.Property.Identifier _id ->
    ()
  | E.Object.Property.Computed expr ->
    visit_expression handler expr
  | E.Object.Property.PrivateName _private_name ->
    ()

and visit_function handler (_, {
    F.
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
        let (_loc, {F.Params. params;rest}) = params in
        visit_list handler visit_pattern params;
        visit_if_some handler (fun handler (_loc, { F.RestElement. argument }) ->
            visit_pattern handler argument) rest
      );
      visit_function_body handler body
  in
  handler.leave_function func

and visit_function_body handler body =
  match body with
  | F.BodyBlock block -> visit_block handler block
  | F.BodyExpression expr -> visit_expression handler expr

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
  | E.Expression expression -> visit_expression handler expression
  | E.Spread (_, { argument }) -> visit_expression handler argument


let visit handler program =

  let visit_program ((_, statements, _): Loc.t Ast.program) =
    visit_list handler visit_statement statements
  in

  visit_program program
