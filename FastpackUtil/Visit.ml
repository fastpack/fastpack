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

and visit_handler = {
  visit_statement : ctx -> Loc.t S.t -> visit_action;
  enter_statement : ctx -> Loc.t S.t -> unit;
  leave_statement : ctx -> Loc.t S.t -> unit;

  visit_expression : ctx -> Loc.t E.t -> visit_action;

  visit_function : ctx -> (Loc.t * Loc.t F.t) -> visit_action;
  enter_function : ctx -> (Loc.t * Loc.t F.t) -> unit;
  leave_function : ctx -> (Loc.t * Loc.t F.t) -> unit;

  visit_block : ctx -> (Loc.t * Loc.t S.Block.t) -> visit_action;
  enter_block : ctx -> (Loc.t * Loc.t S.Block.t) -> unit;
  leave_block : ctx -> (Loc.t * Loc.t S.Block.t) -> unit;

  visit_pattern : ctx -> Loc.t P.t -> visit_action;
}

and ctx = {
  handler : visit_handler;
  parents : parent list;
}

let do_nothing _ _ = Continue
let wrap_nothing _ _ = ()

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

let visit_list ctx visit list =
  List.iter (visit ctx) list

let visit_if_some ctx visit = function
  | None -> ()
  | Some item -> visit ctx item

let rec visit_statement ctx ((loc, statement) : Loc.t S.t) =
  let () = ctx.handler.enter_statement ctx (loc, statement) in
  let action = ctx.handler.visit_statement ctx (loc, statement) in
  let () =
    match action with
    | Break -> ()
    | Continue ->
      match statement with
      | S.Empty ->
        ()

      | S.Block block ->
        visit_block ctx (loc, block)

      | S.Expression { expression; directive = _directive } ->
        visit_expression ctx expression

      | S.If { test; consequent; alternate } ->
        visit_expression ctx test;
        visit_statement ctx consequent;
        visit_if_some ctx visit_statement alternate

      | S.Labeled { label = (_loc, _label); body } ->
        visit_statement ctx body

      | S.Break { label = _label } ->
        ()

      | S.Continue { label = _label } ->
        ()

      | S.With { _object; body } ->
        visit_statement ctx body

      | S.TypeAlias {
          id = _id;
          typeParameters = _typeParameters;
          right = _right
        } ->
        ()

      | S.Switch { discriminant; cases } ->
        visit_expression ctx discriminant;
        visit_list ctx (fun ctx (_loc, { S.Switch.Case. test; consequent }) ->
            visit_if_some ctx visit_expression test;
            visit_list ctx visit_statement consequent
          ) cases

      | S.Return { argument } ->
        visit_if_some ctx visit_expression argument

      | S.Throw { argument } ->
        visit_expression ctx argument

      | S.Try { block; handler = try_handler; finalizer } ->
        visit_block ctx block;
        visit_if_some ctx (fun ctx (_loc, { S.Try.CatchClause. param; body }) ->
            visit_pattern ctx param;
            visit_block ctx body
          ) try_handler;
        visit_if_some ctx visit_block finalizer

      | S.While { test; body } ->
        visit_expression ctx test;
        visit_statement ctx body

      | S.DoWhile { body; test } ->
        visit_statement ctx body;
        visit_expression ctx test;

      | S.For { init; test; update; body } ->
        visit_if_some ctx(fun ctx init -> match init with
            | S.For.InitDeclaration decl -> visit_variable_declaration ctx decl
            | S.For.InitExpression expression -> visit_expression ctx expression) init;
        visit_if_some ctx visit_expression test;
        visit_if_some ctx visit_expression update;
        visit_statement ctx body;

      | S.ForIn { left; right; body; each = _each } ->
        (match left with
         | S.ForIn.LeftDeclaration decl -> visit_variable_declaration ctx decl
         | S.ForIn.LeftPattern pattern -> visit_pattern ctx pattern);
        visit_expression ctx right;
        visit_statement ctx body

      | S.ForOf { left; right; body; async = _async } ->
        (match left with
         | S.ForOf.LeftDeclaration decl -> visit_variable_declaration ctx decl
         | S.ForOf.LeftPattern pattern -> visit_pattern ctx pattern);
        visit_expression ctx right;
        visit_statement ctx body

      | S.FunctionDeclaration func ->
        visit_function ctx (loc, func)

      | S.VariableDeclaration decl ->
        visit_variable_declaration ctx (loc, decl)

      | S.ClassDeclaration cls ->
        visit_class ctx cls

      | S.ExportDefaultDeclaration { declaration; _ } ->
        (match declaration with
         | S.ExportDefaultDeclaration.Declaration stmt ->
           visit_statement ctx stmt
         | S.ExportDefaultDeclaration.Expression expr ->
           visit_expression ctx expr
        )

      | S.ExportNamedDeclaration { declaration; _ } ->
        visit_if_some ctx visit_statement declaration;

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
  ctx.handler.leave_statement ctx (loc, statement)

and visit_class ctx {Class. body = (_, { body }); superClass; _} =
  (** TODO: handle `classDecorators` *)
  (** TODO: handle `implements` *)
  visit_if_some ctx visit_expression superClass;
  visit_list ctx (fun ctx item -> match item with
      | Class.Body.Method (_loc, {
          kind = _kind;
          key = _key;
          value;
          static = _static;
          decorators = _decorators
        }) ->
        visit_function ctx value
      | Class.Body.Property (_loc, {
          key;
          value;
          typeAnnotation = _typeAnnotation;
          static = _static;
          variance = _variance;
        }) ->
        visit_object_property_key ctx key;
        visit_if_some ctx visit_expression value
      | Class.Body.PrivateField (_loc, {
          key = _key;
          value;
          typeAnnotation = _typeAnnotation;
          static = _static;
          variance = _variance
        }) ->
        visit_if_some ctx visit_expression value
    ) body

and visit_expression ctx ((loc, expression) : Loc.t E.t) =
  let action = ctx.handler.visit_expression ctx (loc, expression) in
  match action with
  | Break -> ()
  | Continue ->
    match expression with
    | E.Import _ -> ()
    | E.This -> ()
    | E.Super -> ()
    | E.Array { elements } ->
      visit_list
        ctx
        (fun ctx -> function
           | None -> ()
           | Some element -> visit_expression_or_spread ctx element)
        elements
    | E.Object { properties } ->
      visit_list
        ctx
        (fun ctx prop -> match prop with
           | E.Object.Property property ->
             visit_object_property ctx property
           | E.Object.SpreadProperty (_, { argument }) ->
             visit_expression ctx argument
        )
        properties

    | E.Function func ->
      visit_function ctx (loc, func)

    | E.ArrowFunction func ->
      visit_function ctx (loc, func)

    | E.Sequence { expressions } ->
      visit_list ctx visit_expression expressions

    | E.Unary { operator = _operator; prefix = _prefix; argument } ->
      visit_expression ctx argument

    | E.Binary { operator = _operator; left; right } ->
      visit_expression ctx left;
      visit_expression ctx right

    | E.Assignment { operator = _operator; left; right } ->
      visit_pattern ctx left;
      visit_expression ctx right

    | E.Update { operator = _operator; argument; prefix = _prefix } ->
      visit_expression ctx argument

    | E.Logical { operator = _operator; left; right } ->
      visit_expression ctx left;
      visit_expression ctx right

    | E.Conditional { test; consequent; alternate } ->
      visit_expression ctx test;
      visit_expression ctx consequent;
      visit_expression ctx alternate

    | E.New { callee; arguments } ->
      visit_expression ctx callee;
      visit_list ctx visit_expression_or_spread arguments

    | E.Call { callee; arguments } ->
      visit_expression ctx callee;
      visit_list ctx visit_expression_or_spread arguments

    | E.Member { _object; property; computed = _computed } ->
      visit_expression ctx _object;
      begin
      match property with
      | E.Member.PropertyExpression expr ->
        visit_expression ctx expr
      | E.Member.PropertyIdentifier _ -> ()
      | E.Member.PropertyPrivateName _ -> ()
      end;
    | E.Yield { argument; delegate = _delegate } ->
      visit_if_some ctx visit_expression argument

    | E.Comprehension _ -> ()
    | E.Generator _ -> ()
    | E.Identifier _ -> ()
    | E.Literal _ -> ()
    | E.TemplateLiteral _ -> ()
    | E.TaggedTemplate _ -> ()
    | E.JSXElement _ -> ()
    | E.JSXFragment _ -> ()
    | E.Class cls ->
      visit_class ctx cls
    | E.TypeCast _ -> ()
    | E.MetaProperty _ -> ()

and visit_pattern ctx ((_loc, pattern) as p : Loc.t P.t) =
  match ctx.handler.visit_pattern ctx p with
  | Break -> ()
  | Continue ->
    match pattern with

    | P.Object { properties; typeAnnotation = _typeAnnotation } ->
      visit_list
        ctx
        (fun ctx prop -> match prop with
           | P.Object.Property (_,{ key = _key; pattern; shorthand = _shorthand }) ->
             visit_pattern ctx pattern
           | P.Object.RestProperty (_,{ argument }) ->
             visit_pattern ctx argument
        ) properties

    | P.Array { elements; typeAnnotation = _typeAnnotation } ->
      visit_list
        ctx
        (fun ctx element -> match element with
           | None -> ()
           | Some (P.Array.Element pattern) ->
             visit_pattern ctx pattern
           | Some (P.Array.RestElement (_,{ argument })) ->
             visit_pattern ctx argument)
        elements

    | P.Assignment { left; right } ->
      visit_pattern ctx left;
      visit_expression ctx right

    | P.Identifier _ -> ()

    | P.Expression expr -> visit_expression ctx expr

and visit_object_property ctx (_, value) =
  match value with
  | E.Object.Property.Init {key; value; _} ->
    visit_object_property_key ctx key;
    visit_expression ctx value
  | E.Object.Property.Method {key; value} ->
    visit_object_property_key ctx key;
    visit_function ctx value
  | E.Object.Property.Get {key; value} ->
    visit_object_property_key ctx key;
    visit_function ctx value
  | E.Object.Property.Set {key; value} ->
    visit_object_property_key ctx key;
    visit_function ctx value


and visit_object_property_key ctx key =
  match key with
  | E.Object.Property.Literal _lit ->
    ()
  | E.Object.Property.Identifier _id ->
    ()
  | E.Object.Property.Computed expr ->
    visit_expression ctx expr
  | E.Object.Property.PrivateName _private_name ->
    ()

and visit_function ctx (_, {
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
  let () = ctx.handler.enter_function ctx func in
  let action = ctx.handler.visit_function ctx func in
  let () =
    match action with
    | Break -> ()
    | Continue ->
      (** TODO: handle `predicate` *)
      (
        let (_loc, {F.Params. params;rest}) = params in
        visit_list ctx visit_pattern params;
        visit_if_some ctx (fun ctx (_loc, { F.RestElement. argument }) ->
            visit_pattern ctx argument) rest
      );
      visit_function_body ctx body
  in
  ctx.handler.leave_function ctx func

and visit_function_body ctx body =
  match body with
  | F.BodyBlock block -> visit_block ctx block
  | F.BodyExpression expr -> visit_expression ctx expr

and visit_block ctx ((_, { body }) as block) =
  let () = ctx.handler.enter_block ctx block in
  let visit_action = ctx.handler.visit_block ctx block in
  let () =
    match visit_action with
    | Break -> ()
    | Continue -> visit_list ctx visit_statement body
  in
  ctx.handler.leave_block ctx block

and visit_variable_declaration ctx (_, { declarations; kind = _kind }) =
  visit_list ctx
    visit_variable_declarator
    declarations;

and visit_variable_declarator ctx (_, { init; id }) =
  visit_pattern ctx id;
  (match init with
   | None  -> ();
   | Some expr -> visit_expression ctx expr);

and visit_expression_or_spread ctx item = match item with
  | E.Expression expression -> visit_expression ctx expression
  | E.Spread (_, { argument }) -> visit_expression ctx argument


let visit handler program =
  let ctx = {
    parents = [];
    handler;
  } in
  let _, statements, _ = program in
  visit_list ctx visit_statement statements
