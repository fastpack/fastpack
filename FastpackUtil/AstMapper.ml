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

type mapper = {
  map_statement : Scope.t -> Loc.t Statement.t -> Loc.t Statement.t;
  map_expression : Scope.t -> Loc.t Expression.t -> Loc.t Expression.t;
  map_function : Scope.t -> (Loc.t * Loc.t Function.t) -> (Loc.t * Loc.t Function.t);
  map_pattern : Scope.t -> Loc.t Pattern.t -> Loc.t Pattern.t;
}

let do_nothing _ node =
  node

let default_mapper =
  {
    map_statement = do_nothing;
    map_expression = do_nothing;
    map_function = do_nothing;
    map_pattern = do_nothing;
  }

let map_list scope (handler : mapper) map list =
  List.map (map scope handler) list

let map_if_some get_scope handler map_with = function
  | None -> None
  | Some item -> Some (map_with (get_scope item) handler item)

let rec map_statement scope handler (loc, statement) =
  let statement = match statement with
    | Statement.Block { body } ->
      Statement.Block {
        body = map_list (Scope.of_statement (loc, statement) scope) handler map_statement body
      }

    | Statement.Expression ({ expression; directive = _directive } as expr) ->
      Statement.Expression {
        expr with expression = map_expression scope handler expression;
      }

    | Statement.If { test; consequent; alternate }->
      Statement.If {
        test = map_expression scope handler test;
        consequent = map_statement scope handler consequent;
        alternate = map_if_some
            (fun _ -> scope)
            handler
            map_statement
            alternate;
      }

    | Statement.Labeled ({ body; _ } as n) ->
      Statement.Labeled { n with body = map_statement scope handler body }

    | Statement.With { _object; body } ->
      Statement.With {
        _object = map_expression scope handler _object;
        body = map_statement scope handler body
      }

    | Statement.Switch { discriminant; cases } ->
      Statement.Switch {
        discriminant = map_expression scope handler discriminant;
        cases = map_list scope handler
            (fun scope handler (loc, { Statement.Switch.Case. test; consequent }) ->
               (loc, {
                   Statement.Switch.Case.
                   test = map_if_some (fun _ -> scope) handler map_expression test;
                   consequent = map_list scope handler map_statement consequent;
                 })
            ) cases;
      }

    | Statement.Return { argument } ->
      Statement.Return {
        argument = map_if_some (fun _ -> scope) handler map_expression argument;
      }

    | Statement.Throw { argument } ->
      Statement.Throw {
        argument = map_expression scope handler argument
      }

    | Statement.Try { block; handler = _handler; finalizer } ->
      Statement.Try {
        block = map_block scope handler block;
        handler = map_if_some
            (fun _ -> scope)
            handler
            (fun scope handler (loc, { Statement.Try.CatchClause. param; body }) ->
               (loc, {
                   Statement.Try.CatchClause.
                   param = map_pattern scope handler param;
                   body = map_block scope handler body
                 })
          ) _handler;
        finalizer = map_if_some (fun _ -> scope) handler map_block finalizer
      }

    | Statement.While { test; body } ->
      Statement.While {
        test = map_expression scope handler test;
        body = map_statement scope handler body
      }

    | Statement.DoWhile { body; test } ->
      Statement.DoWhile {
        body = map_statement scope handler body;
        test = map_expression scope handler test;
      }

    | Statement.For { init; test; update; body } ->
      let scope = Scope.of_statement (loc, statement) scope in
      Statement.For {
        init = map_if_some (fun _ -> scope) handler
            (fun scope handler init -> match init with
               | Statement.For.InitDeclaration decl ->
                 let decl = map_variable_declaration scope handler decl in
                 Statement.For.InitDeclaration decl
               | Statement.For.InitExpression expression ->
                 let expression = map_expression scope handler expression in
                 Statement.For.InitExpression expression) init;
        test = map_if_some (fun _ -> scope) handler map_expression test;
        update = map_if_some (fun _ -> scope) handler map_expression update;
        body = map_statement scope handler body;
      }

    | Statement.ForIn ({ left; right; body; _ } as n) ->
      let scope = Scope.of_statement (loc, statement) scope in
      Statement.ForIn {
        n with
        left = (match left with
            | Statement.ForIn.LeftDeclaration decl ->
              let decl = map_variable_declaration scope handler decl in
              Statement.ForIn.LeftDeclaration decl
            | Statement.ForIn.LeftPattern pattern ->
              let pattern = map_pattern scope handler pattern in
              Statement.ForIn.LeftPattern pattern);
        right = map_expression scope handler right;
        body = map_statement scope handler body;
      }

    | Statement.ForOf ({ left; right; body; async = _async } as n) ->
      let scope = Scope.of_statement (loc, statement) scope in
      Statement.ForOf {
        n with
        left = (match left with
            | Statement.ForOf.LeftDeclaration decl ->
              let decl = map_variable_declaration scope handler decl in
              Statement.ForOf.LeftDeclaration decl
            | Statement.ForOf.LeftPattern pattern ->
              let pattern = map_pattern scope handler pattern in
              Statement.ForOf.LeftPattern pattern);
        right = map_expression scope handler right;
        body = map_statement scope handler body;
      }

    | Statement.FunctionDeclaration func ->
      let _, func = map_function scope handler (loc, func) in
      Statement.FunctionDeclaration func

    | Statement.VariableDeclaration decl ->
      let _, decl = map_variable_declaration scope handler (loc, decl) in
      Statement.VariableDeclaration decl

    | Statement.ClassDeclaration cls ->
      let cls = map_class scope handler cls in
      Statement.ClassDeclaration cls

    | node -> node
  in
  handler.map_statement scope (loc, statement)

and map_class scope
    handler
    ({Class. body = (body_loc, { body }); superClass; _} as n) =
  (** TODO: handle `classDecorators` *)
  {
    n with
    superClass = map_if_some (fun _ -> scope) handler map_expression superClass;
    body = (body_loc, {
        Class.Body.
        body = map_list scope handler (fun scope handler item ->
            match item with
            | Class.Body.Method (loc, ({ value; _ } as n)) ->
              let value = map_function scope handler value in
              Class.Body.Method (loc, { n with value; })
            | Class.Body.Property (loc, ({ key; value; _ } as n)) ->
              let key = map_object_property_key scope handler key in
              let value =
                map_if_some (fun _ -> scope) handler map_expression value
              in
              Class.Body.Property (loc, { n with key; value })
            | Class.Body.PrivateField (loc, ({ value; _ } as n)) ->
              let value =
                map_if_some (fun _ -> scope) handler map_expression value
              in
              Class.Body.PrivateField (loc, { n with value })
          ) body
      })
  }

and map_expression scope handler (loc, expression) =
  let expression = match expression with
    | Expression.Array { elements } ->
      Expression.Array {
        elements = map_list scope handler
            (fun scope handler -> function
               | None ->
                 None
               | Some element ->
                 Some (map_expression_or_spread scope handler element))
            elements
      }
    | Expression.Object { properties } ->
      Expression.Object {
        properties = map_list
            scope
            handler
            (fun scope handler prop -> match prop with
               | Expression.Object.Property property ->
                 let property = map_object_property scope handler property in
                 Expression.Object.Property property
               | Expression.Object.SpreadProperty (loc, { argument }) ->
                 let argument = map_expression scope handler argument in
                 Expression.Object.SpreadProperty (loc, { argument })
            )
            properties
      }

    | Expression.Function func ->
      let _, func = map_function scope handler (loc, func) in
      Expression.Function func

    | Expression.ArrowFunction func ->
      let _, func = map_function scope handler (loc, func) in
      Expression.ArrowFunction func

    | Expression.Sequence { expressions } ->
      let expressions = map_list scope handler map_expression expressions in
      Expression.Sequence { expressions }

    | Expression.Unary ({ argument; _ } as n) ->
      let argument = map_expression scope handler argument in
      Expression.Unary { n with argument; }

    | Expression.Binary ({ left; right; _ } as n) ->
      let left = map_expression scope handler left in
      let right = map_expression scope handler right in
      Expression.Binary { n with left; right }

    | Expression.Assignment ({ left; right; _ } as n) ->
      let left = map_pattern scope handler left in
      let right = map_expression scope handler right in
      Expression.Assignment { n with left; right }

    | Expression.Update ({ argument; _ } as n) ->
      let argument = map_expression scope handler argument in
      Expression.Update { n with argument }

    | Expression.Logical ({ left; right; _ } as n) ->
      let left = map_expression scope handler left in
      let right = map_expression scope handler right in
      Expression.Logical { n with left; right }

    | Expression.Conditional { test; consequent; alternate } ->
      let test = map_expression scope handler test in
      let consequent = map_expression scope handler consequent in
      let alternate = map_expression scope handler alternate in
      Expression.Conditional { test; consequent; alternate }

    | Expression.New { callee; arguments } ->
      let callee = map_expression scope handler callee in
      let arguments = map_list scope handler map_expression_or_spread arguments in
      Expression.New { callee; arguments }

    | Expression.Call { callee; arguments } ->
      let callee = map_expression scope handler callee in
      let arguments = map_list scope handler map_expression_or_spread arguments in
      Expression.Call { callee; arguments }

    | Expression.Member ({ _object; property; _ } as n) ->
      let _object = map_expression scope handler _object in
      let property = match property with
        | Expression.Member.PropertyPrivateName _
        | Expression.Member.PropertyIdentifier _ -> property
        | Expression.Member.PropertyExpression expr ->
          let expr = map_expression scope handler expr in
          Expression.Member.PropertyExpression expr
      in
      Expression.Member { n with _object; property }

    | Expression.Yield ({ argument; _ } as n) ->
      let argument = map_if_some (fun _ -> scope) handler map_expression argument in
      Expression.Yield { n with argument; }

    | Expression.Class cls ->
      let cls = map_class scope handler cls in
      Expression.Class cls

    | node -> node
  in
  handler.map_expression scope (loc, expression)

and map_pattern scope (handler : mapper) (loc, pattern) =
  let pattern = match pattern with
    | Pattern.Object ({ properties; _ } as n) ->
      let properties = map_list
          scope
          handler
          (fun scope handler prop -> match prop with
             | Pattern.Object.RestProperty (loc, { argument }) ->
               let argument = map_pattern scope handler argument in
               Pattern.Object.RestProperty (loc, { argument })
             | Pattern.Object.Property (loc, ({ key; pattern; _ } as n)) ->
               let key = map_pattern_property_key scope handler key in
               let pattern  = map_pattern scope handler pattern in
               Pattern.Object.Property (loc, { n with key; pattern })
          ) properties in
      Pattern.Object { n with properties; }

    | Pattern.Array ({ elements; _ } as n) ->
      let elements = map_list
          scope
          handler
          (fun scope handler element -> match element with
             | None -> None
             | Some (Pattern.Array.Element pattern) ->
               let pattern = map_pattern scope handler pattern in
               Some (Pattern.Array.Element pattern)
             | Some (Pattern.Array.RestElement (loc, { argument })) ->
               let argument = map_pattern scope handler argument in
               Some (Pattern.Array.RestElement (loc, { argument })))
          elements
      in
      Pattern.Array { n with elements }

    | Pattern.Assignment { left; right } ->
      let left = map_pattern scope handler left in
      let right = map_expression scope handler right in
      Pattern.Assignment { left; right }

    | Pattern.Expression expr ->
      let expr = map_expression scope handler expr in
      Pattern.Expression expr
    | node -> node

  in handler.map_pattern scope (loc, pattern)

and map_pattern_property_key scope handler key =
  match key with
  | Pattern.Object.Property.Literal _ -> key
  | Pattern.Object.Property.Identifier _ -> key
  | Pattern.Object.Property.Computed expr ->
    let expr = map_expression scope handler expr in
    Pattern.Object.Property.Computed expr

and map_object_property scope handler (loc, prop) =
  let prop =
    match prop with
    | Expression.Object.Property.Init ({ key; value; _ } as n) ->
      Expression.Object.Property.Init {
        n with
        key = map_object_property_key scope handler key;
        value = map_expression scope handler value
      }
    | Expression.Object.Property.Method { key; value } ->
      Expression.Object.Property.Method {
        key = map_object_property_key scope handler key;
        value = map_function scope handler value
      }
    | Expression.Object.Property.Get { key; value } ->
      Expression.Object.Property.Get {
        key = map_object_property_key scope handler key;
        value = map_function scope handler value
      }
    | Expression.Object.Property.Set { key; value } ->
      Expression.Object.Property.Set {
        key = map_object_property_key scope handler key;
        value = map_function scope handler value
      }
  in
  (loc, prop)
  (* let key = map_object_property_key scope handler key in *)
  (* let value = match value with *)
  (*   | Expression.Object.Property.Init expr -> *)
  (*     let expr = map_expression scope handler expr in *)
  (*     Expression.Object.Property.Init expr *)
  (*   | Expression.Object.Property.Get func -> *)
  (*     let func = map_function scope handler func in *)
  (*     Expression.Object.Property.Get func *)
  (*   | Expression.Object.Property.Set func -> *)
  (*     let func = map_function scope handler func in *)
  (*     Expression.Object.Property.Set func *)
  (* in (loc, Expression.Object.Property.({ n with key; value; })) *)

and map_object_property_key scope handler key =
  match key with
  | Expression.Object.Property.Computed expr ->
    let expr = map_expression scope handler expr in
    Expression.Object.Property.Computed expr
  | node -> node

and map_function
    scope
    handler
    (loc, ({ Function. params=(params_loc, { params; rest }); body; _ } as n)) =
  let scope = Scope.of_function (loc, n) scope in
  let params =
    map_list scope handler map_pattern params
  in
  let rest =
    map_if_some (fun _ -> scope) handler
      (fun scope handler (loc, { Function.RestElement. argument })
        -> (loc, {
            Function.RestElement. argument = map_pattern scope handler argument
          }))
      rest
  in
  let body = map_function_body scope handler body in
  let n = Function.({
      n with
      params = (params_loc, { params; rest });
      body = body
    })
  in
  handler.map_function scope (loc, n)

and map_function_body scope handler body =
  match body with
  | Function.BodyBlock block ->
    let block = map_block scope handler block in
    Function.BodyBlock block
  | Function.BodyExpression expr ->
    let expr = map_expression scope handler expr in
    Function.BodyExpression expr

and map_block scope handler (loc, block) =
  (loc, { body = map_list scope handler map_statement block.body })

and map_variable_declaration scope handler (loc, ({ declarations; _ } as n)) =
  let declarations = map_list scope handler map_variable_declarator declarations in
  (loc, { n with declarations; })

and map_variable_declarator scope handler (loc, { init; id }) =
  let id = map_pattern scope handler id in
  let init = match init with
    | None  -> None
    | Some expr -> Some (map_expression scope handler expr)
  in (loc, { Statement.VariableDeclaration.Declarator. init; id })

and map_expression_or_spread scope handler item = match item with
  | Expression.Expression expr ->
    let expr = map_expression scope handler expr in
    Expression.Expression expr
  | Expression.Spread (loc, { argument }) ->
    let argument = map_expression scope handler argument in
    Expression.Spread (loc, { argument })

let map handler program =

  let map_program ((loc, statements, comments): Loc.t Ast.program) =
    let scope = Scope.of_program statements Scope.empty in
    let statements = map_list scope handler map_statement statements in
    (loc, statements, comments)
  in

  map_program program
