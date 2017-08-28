module Expression = Ast.Expression
module Pattern = Ast.Pattern
module Statement = Ast.Statement
module Literal = Ast.Literal
module Type = Ast.Type
module Variance = Ast.Variance
module Class = Ast.Class
module Function = Ast.Function

type mapper = {
  map_statement : Statement.t -> Statement.t;
  map_expression : Expression.t -> Expression.t;
  map_function : (Loc.t * Function.t) -> (Loc.t * Function.t);
  map_pattern : Pattern.t -> Pattern.t;
}

let do_nothing node =
  node

let default_mapper =
  {
    map_statement = do_nothing;
    map_expression = do_nothing;
    map_function = do_nothing;
    map_pattern = do_nothing;
  }

let map_list (handler : mapper) map list =
  List.map (map handler) list

let map_if_some handler map_with = function
  | None -> None
  | Some item -> Some (map_with handler item)

let rec map_statement handler ((loc, statement) : Statement.t) =
  let statement = match statement with
    | Statement.Block { body } ->
      Statement.Block { body = map_list handler map_statement body }

    | Statement.Expression ({ expression; directive = _directive } as n) ->
      Statement.Expression { n with expression = map_expression handler expression; }

    | Statement.If { test; consequent; alternate }->
      Statement.If {
        test = map_expression handler test;
        consequent = map_statement handler consequent;
        alternate = map_if_some handler map_statement alternate;
      }

    | Statement.Labeled ({ body; _ } as n) ->
      Statement.Labeled { n with body = map_statement handler body }

    | Statement.With { _object; body } ->
      Statement.With {
        _object = map_expression handler _object; 
        body = map_statement handler body
      }

    | Statement.Switch { discriminant; cases } ->
      Statement.Switch {
        discriminant = map_expression handler discriminant;
        cases = map_list handler
            (fun handler (loc, { Statement.Switch.Case. test; consequent }) ->
               (loc, {
                   Statement.Switch.Case.
                   test = map_if_some handler map_expression test;
                   consequent = map_list handler map_statement consequent;
                 })
            ) cases;
      }

    | Statement.Return { argument } ->
      Statement.Return {
        argument = map_if_some handler map_expression argument;
      }

    | Statement.Throw { argument } ->
      Statement.Throw {
        argument = map_expression handler argument
      }

    | Statement.Try { block; handler = _handler; finalizer } ->
      Statement.Try {
        block = map_block handler block;
        handler = map_if_some handler (fun handler (loc, { Statement.Try.CatchClause. param; body }) ->
            (loc, {
                Statement.Try.CatchClause.
                param = map_pattern handler param;
                body = map_block handler body
              })
          ) _handler;
        finalizer = map_if_some handler map_block finalizer
      }

    | Statement.While { test; body } ->
      Statement.While {
        test = map_expression handler test;
        body = map_statement handler body
      }

    | Statement.DoWhile { body; test } ->
      Statement.DoWhile {
        body = map_statement handler body;
        test = map_expression handler test;
      }

    | Statement.For { init; test; update; body } ->
      Statement.For {
        init = map_if_some handler
            (fun handler init -> match init with
               | Statement.For.InitDeclaration decl ->
                 let decl = map_variable_declaration handler decl in
                 Statement.For.InitDeclaration decl
               | Statement.For.InitExpression expression -> 
                 let expression = map_expression handler expression in
                 Statement.For.InitExpression expression) init;
        test = map_if_some handler map_expression test;
        update = map_if_some handler map_expression update;
        body = map_statement handler body;
      }

    | Statement.ForIn ({ left; right; body; _ } as n) ->
      Statement.ForIn {
        n with
        left = (match left with
            | Statement.ForIn.LeftDeclaration decl ->
              let decl = map_variable_declaration handler decl in
              Statement.ForIn.LeftDeclaration decl
            | Statement.ForIn.LeftExpression expression ->
              let expression = map_expression handler expression in
              Statement.ForIn.LeftExpression expression);
        right = map_expression handler right;
        body = map_statement handler body;
      }

    | Statement.ForOf ({ left; right; body; async = _async } as n) ->
      Statement.ForOf {
        n with
        left = (match left with
            | Statement.ForOf.LeftDeclaration decl ->
              let decl = map_variable_declaration handler decl in
              Statement.ForOf.LeftDeclaration decl
            | Statement.ForOf.LeftExpression expression ->
              let expression = map_expression handler expression in
              Statement.ForOf.LeftExpression expression);
        right = map_expression handler right;
        body = map_statement handler body;
      }

    | Statement.FunctionDeclaration func ->
      let _, func = map_function handler (loc, func) in
      Statement.FunctionDeclaration func

    | Statement.VariableDeclaration decl ->
      let _, decl = map_variable_declaration handler (loc, decl) in
      Statement.VariableDeclaration decl

    | Statement.ClassDeclaration cls ->
      let cls = map_class handler cls in
      Statement.ClassDeclaration cls

    | node -> node
  in
  handler.map_statement (loc, statement)

and map_class handler ({Class. body = (body_loc, { body }); superClass; _} as n) =
  (** TODO: handle `classDecorators` *)
  (** TODO: handle `implements` *)
  {
    n with
    superClass = map_if_some handler map_expression superClass;
    body = (body_loc, {
        Class.Body.
        body = map_list handler (fun handler item ->
            match item with
            | Class.Body.Method (loc, ({ value; _ } as n)) ->
              let value = map_function handler value in
              Class.Body.Method (loc, { n with value; })
            | Class.Body.Property (loc, ({ key; value; _ } as n)) ->
              let key = map_object_property_key handler key in
              let value = map_if_some handler map_expression value in
              Class.Body.Property (loc, { n with key; value })
          ) body
      })
  }

and map_expression handler ((loc, expression) : Expression.t) =
  let expression = match expression with
    | Expression.Array { elements } ->
      Expression.Array { 
        elements = map_list handler
            (fun handler -> function
               | None -> None
               | Some element -> Some (map_expression_or_spread handler element))
            elements
      }
    | Expression.Object { properties } ->
      Expression.Object {
        properties = map_list
            handler
            (fun handler prop -> match prop with
               | Expression.Object.Property property ->
                 let property = map_object_property handler property in
                 Expression.Object.Property property
               | Expression.Object.SpreadProperty (loc, { argument }) ->
                 let argument = map_expression handler argument in
                 Expression.Object.SpreadProperty (loc, { argument })
            )
            properties
      }

    | Expression.Function func ->
      let _, func = map_function handler (loc, func) in
      Expression.Function func

    | Expression.ArrowFunction func ->
      let _, func = map_function handler (loc, func) in
      Expression.ArrowFunction func

    | Expression.Sequence { expressions } ->
      let expressions = map_list handler map_expression expressions in
      Expression.Sequence { expressions }

    | Expression.Unary ({ argument; _ } as n) ->
      let argument = map_expression handler argument in
      Expression.Unary { n with argument; }

    | Expression.Binary ({ left; right; _ } as n) ->
      let left = map_expression handler left in
      let right = map_expression handler right in
      Expression.Binary { n with left; right }

    | Expression.Assignment ({ left; right; _ } as n) ->
      let left = map_pattern handler left in
      let right = map_expression handler right in
      Expression.Assignment { n with left; right }

    | Expression.Update ({ argument; _ } as n) ->
      let argument = map_expression handler argument in
      Expression.Update { n with argument }

    | Expression.Logical ({ left; right; _ } as n) ->
      let left = map_expression handler left in
      let right = map_expression handler right in
      Expression.Logical { n with left; right }

    | Expression.Conditional { test; consequent; alternate } ->
      let test = map_expression handler test in
      let consequent = map_expression handler consequent in
      let alternate = map_expression handler alternate in
      Expression.Conditional { test; consequent; alternate }

    | Expression.New { callee; arguments } ->
      let callee = map_expression handler callee in
      let arguments = map_list handler map_expression_or_spread arguments in
      Expression.New { callee; arguments }

    | Expression.Call { callee; arguments } ->
      let callee = map_expression handler callee in
      let arguments = map_list handler map_expression_or_spread arguments in
      Expression.Call { callee; arguments }

    | Expression.Member ({ _object; property; _ } as n) ->
      let _object = map_expression handler _object in
      let property = match property with
        | Expression.Member.PropertyIdentifier _ -> property
        | Expression.Member.PropertyExpression expr -> 
          let expr = map_expression handler expr in
          Expression.Member.PropertyExpression expr
      in
      Expression.Member { n with _object; property }

    | Expression.Yield ({ argument; _ } as n) ->
      let argument = map_if_some handler map_expression argument in
      Expression.Yield { n with argument; }

    | Expression.Class cls ->
      let cls = map_class handler cls in
      Expression.Class cls

    | node -> node
  in
  handler.map_expression (loc, expression)

and map_pattern (handler : mapper) ((loc, pattern) : Pattern.t) =
  let pattern = match pattern with
    | Pattern.Object ({ properties; _ } as n) ->
      let properties = map_list
          handler
          (fun handler prop -> match prop with
             | Pattern.Object.RestProperty (loc, { argument }) ->
               let argument = map_pattern handler argument in
               Pattern.Object.RestProperty (loc, { argument })
             | Pattern.Object.Property (loc, ({ key; pattern; _ } as n)) ->
               let key = map_pattern_property_key handler key in
               let pattern  = map_pattern handler pattern in
               Pattern.Object.Property (loc, { n with key; pattern })
          ) properties in
      Pattern.Object { n with properties; }

    | Pattern.Array ({ elements; _ } as n) ->
      let elements = map_list
          handler
          (fun handler element -> match element with
             | None -> None
             | Some (Pattern.Array.Element pattern) ->
               let pattern = map_pattern handler pattern in
               Some (Pattern.Array.Element pattern)
             | Some (Pattern.Array.RestElement (loc, { argument })) ->
               let argument = map_pattern handler argument in
               Some (Pattern.Array.RestElement (loc, { argument })))
          elements
      in
      Pattern.Array { n with elements }

    | Pattern.Assignment { left; right } ->
      let left = map_pattern handler left in
      let right = map_expression handler right in
      Pattern.Assignment { left; right }

    | Pattern.Expression expr ->
      let expr = map_expression handler expr in
      Pattern.Expression expr
    | node -> node

  in handler.map_pattern (loc, pattern)

and map_pattern_property_key handler (key : Pattern.Object.Property.key) =
  match key with
  | Pattern.Object.Property.Literal _ -> key
  | Pattern.Object.Property.Identifier _ -> key
  | Pattern.Object.Property.Computed expr ->
    let expr = map_expression handler expr in
    Pattern.Object.Property.Computed expr

and map_object_property handler (loc, ({ key; value; _ } as n)) =
  let key = map_object_property_key handler key in
  let value = match value with
    | Expression.Object.Property.Init expr ->
      let expr = map_expression handler expr in
      Expression.Object.Property.Init expr
    | Expression.Object.Property.Get func ->
      let func = map_function handler func in
      Expression.Object.Property.Get func
    | Expression.Object.Property.Set func ->
      let func = map_function handler func in
      Expression.Object.Property.Set func
  in (loc, Expression.Object.Property.({ n with key; value; }))

and map_object_property_key handler key =
  match key with
  | Expression.Object.Property.Computed expr ->
    let expr = map_expression handler expr in
    Expression.Object.Property.Computed expr
  | node -> node

and map_function handler (loc, ({ Function. params = (params, rest); body; _ } as n)) =
  let params =
    map_list handler map_pattern params
  in
  let rest =
    map_if_some handler
      (fun handler (loc, { Function.RestElement. argument })
        -> (loc, { Function.RestElement. argument = map_pattern handler argument}))
      rest
  in
  let body = map_function_body handler body in
  let n = Function.({ n with params = (params, rest); body = body }) in
  handler.map_function (loc, n)

and map_function_body handler body =
  match body with
  | Function.BodyBlock block ->
    let block = map_block handler block in
    Function.BodyBlock block
  | Function.BodyExpression expr ->
    let expr = map_expression handler expr in
    Function.BodyExpression expr

and map_block handler ((loc, block) : (Loc.t * Statement.Block.t)) =
  (loc, { body = map_list handler map_statement block.body })

and map_variable_declaration handler (loc, ({ declarations; _ } as n)) =
  let declarations = map_list handler map_variable_declarator declarations in
  (loc, { n with declarations; })

and map_variable_declarator handler (loc, { init; id }) =
  let id = map_pattern handler id in
  let init = match init with
    | None  -> None
    | Some expr -> Some (map_expression handler expr)
  in (loc, { Statement.VariableDeclaration.Declarator. init; id })

and map_expression_or_spread handler item = match item with
  | Expression.Expression expr ->
    let expr = map_expression handler expr in
    Expression.Expression expr
  | Expression.Spread (loc, { argument }) ->
    let argument = map_expression handler argument in
    Expression.Spread (loc, { argument })

let map handler program =

  let map_program ((loc, statements, comments): Ast.program) =
    let statements = map_list handler map_statement statements in
    (loc, statements, comments)
  in

  map_program program
