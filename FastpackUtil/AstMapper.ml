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

module APS = AstParentStack

type ctx = {
  handler : mapper;
  scope : Scope.t;
  parents : APS.parent list;
}
and mapper = {
  map_statement : ctx -> Loc.t Statement.t -> Loc.t Statement.t list;
  map_expression : ctx -> Loc.t Expression.t -> Loc.t Expression.t;
  map_function : ctx -> (Loc.t * Loc.t Function.t) -> (Loc.t * Loc.t Function.t);
  map_pattern : ctx -> Loc.t Pattern.t -> Loc.t Pattern.t;
}


let do_nothing _ node =
  node

let default_mapper =
  {
    map_statement = (fun _ node -> [node]);
    map_expression = do_nothing;
    map_function = do_nothing;
    map_pattern = do_nothing;
  }

let map_list ctx map list =
  List.map (map ctx) list


let map_if_some ctx map_with = function
  | None -> None
  | Some item -> Some (map_with ctx item)

let rec map_statements ctx stmts =
  List.fold_left
    (fun acc stmt ->
       let stmts = map_statement ctx stmt in
       acc @ stmts
    )
    []
    stmts
and to_block_if_many stmts =
  match stmts with
  | [stmt] -> stmt
  | _ -> Loc.none, Statement.Block { body = stmts}
and map_statement ctx (loc, statement) =
  let statement =
    let ctx = { ctx with
      scope = Scope.of_statement ctx.parents (loc, statement) ctx.scope;
      parents = APS.push_statement (loc, statement) ctx.parents;
    }
    in
    match statement with
    | Statement.Block block ->
      let _, block = map_block ctx (loc, block) in
      Statement.Block block

    | Statement.Expression ({ expression; _ } as expr) ->
      Statement.Expression {
        expr with expression = map_expression ctx expression;
      }

    | Statement.If { test; consequent; alternate }->
      Statement.If {
        test = map_expression ctx test;
        consequent = map_statement ctx consequent |> to_block_if_many;
        alternate =
          map_if_some
            ctx
            (fun ctx stmt -> map_statement ctx stmt |> to_block_if_many)
            alternate;
      }

    | Statement.Labeled ({ body; _ } as n) ->
      Statement.Labeled {
        n with
        body = map_statement ctx body |> to_block_if_many
      }

    | Statement.With { _object; body } ->
      Statement.With {
        _object = map_expression ctx _object;
        body = map_statement ctx body |> to_block_if_many
      }

    | Statement.Switch { discriminant; cases } ->
      Statement.Switch {
        discriminant = map_expression ctx discriminant;
        cases = map_list ctx
            (fun ctx (loc, { Statement.Switch.Case. test; consequent }) ->
               (loc, {
                   Statement.Switch.Case.
                   test = map_if_some ctx map_expression test;
                   consequent = map_statements ctx consequent;
                 })
            ) cases;
      }

    | Statement.Return { argument } ->
      Statement.Return {
        argument = map_if_some ctx map_expression argument;
      }

    | Statement.Throw { argument } ->
      Statement.Throw {
        argument = map_expression ctx argument
      }

    | Statement.Try { block; handler = _handler; finalizer } ->
      Statement.Try {
        block = map_block ctx block;
        handler = map_if_some
            ctx
            (fun ctx (loc, { Statement.Try.CatchClause. param; body }) ->
               (loc, {
                   Statement.Try.CatchClause.
                   param = map_pattern ctx param;
                   body = map_block ctx body
                 })
          ) _handler;
        finalizer = map_if_some ctx map_block finalizer
      }

    | Statement.While { test; body } ->
      Statement.While {
        test = map_expression ctx test;
        body = map_statement ctx body |> to_block_if_many
      }

    | Statement.DoWhile { body; test } ->
      Statement.DoWhile {
        body = map_statement ctx body |> to_block_if_many;
        test = map_expression ctx test;
      }

    | Statement.For { init; test; update; body } ->
      Statement.For {
        init = map_if_some
            ctx
            (fun ctx init -> match init with
               | Statement.For.InitDeclaration decl ->
                 let decl = map_variable_declaration ctx decl in
                 Statement.For.InitDeclaration decl
               | Statement.For.InitExpression expression ->
                 let expression = map_expression ctx expression in
                 Statement.For.InitExpression expression) init;
        test = map_if_some ctx map_expression test;
        update = map_if_some ctx map_expression update;
        body = map_statement ctx body |> to_block_if_many;
      }

    | Statement.ForIn ({ left; right; body; _ } as n) ->
      Statement.ForIn {
        n with
        left = (match left with
            | Statement.ForIn.LeftDeclaration decl ->
              let decl = map_variable_declaration ctx decl in
              Statement.ForIn.LeftDeclaration decl
            | Statement.ForIn.LeftPattern pattern ->
              let pattern = map_pattern ctx pattern in
              Statement.ForIn.LeftPattern pattern);
        right = map_expression ctx right;
        body = map_statement ctx body |> to_block_if_many;
      }

    | Statement.ForOf ({ left; right; body; async = _async } as n) ->
      Statement.ForOf {
        n with
        left = (match left with
            | Statement.ForOf.LeftDeclaration decl ->
              let decl = map_variable_declaration ctx decl in
              Statement.ForOf.LeftDeclaration decl
            | Statement.ForOf.LeftPattern pattern ->
              let pattern = map_pattern ctx pattern in
              Statement.ForOf.LeftPattern pattern);
        right = map_expression ctx right;
        body = map_statement ctx body |> to_block_if_many;
      }

    | Statement.FunctionDeclaration func ->
      let _, func = map_function ctx (loc, func) in
      Statement.FunctionDeclaration func

    | Statement.VariableDeclaration decl ->
      let _, decl = map_variable_declaration ctx (loc, decl) in
      Statement.VariableDeclaration decl

    | Statement.ClassDeclaration cls ->
      let cls = map_class ctx cls in
      Statement.ClassDeclaration cls

    | Statement.ExportNamedDeclaration ({declaration = Some stmt; _} as e) ->
      begin
        match map_statement ctx stmt with
        | [stmt] ->
          Statement.ExportNamedDeclaration { e with declaration = Some stmt }
        | _ ->
          Error.ie "Cannot have multiple statements in the named export"
      end

    | Statement.ExportDefaultDeclaration ({
        declaration = Statement.ExportDefaultDeclaration.Declaration stmt;
        _
      } as e) ->
      begin
        match map_statement ctx stmt with
        | [stmt] ->
          Statement.ExportDefaultDeclaration {
            e with
            declaration = Statement.ExportDefaultDeclaration.Declaration stmt
          }
        | _ ->
          Error.ie "Cannot have multiple statements in the default export"
      end

    | Statement.ExportDefaultDeclaration ({
        declaration = Statement.ExportDefaultDeclaration.Expression expr;
        _
      } as e) ->
      let expr = map_expression ctx expr in
      Statement.ExportDefaultDeclaration {
        e with
        declaration = Statement.ExportDefaultDeclaration.Expression expr
      }

    | node -> node
  in
  ctx.handler.map_statement ctx (loc, statement)

and map_class ctx ({Class. body = (body_loc, { body }); superClass; _} as n) =
  (** TODO: handle `classDecorators` *)
  {
    n with
    superClass = map_if_some ctx map_expression superClass;
    body = (body_loc, {
        Class.Body.
        body = map_list ctx (fun ctx item ->
            match item with
            | Class.Body.Method (loc, ({ value; _ } as n)) ->
              let value = map_function ctx value in
              Class.Body.Method (loc, { n with value; })
            | Class.Body.Property (loc, ({ key; value; _ } as n)) ->
              let key = map_object_property_key ctx key in
              let value = map_if_some ctx map_expression value in
              Class.Body.Property (loc, { n with key; value })
            | Class.Body.PrivateField (loc, ({ value; _ } as n)) ->
              let value = map_if_some ctx map_expression value in
              Class.Body.PrivateField (loc, { n with value })
          ) body
      })
  }

and map_expression ctx (loc, expression) =
  let expression =
    let ctx = {
      ctx with
      parents = APS.push_expression (loc, expression) ctx.parents
    }
    in
    match expression with
    | Expression.TypeCast { expression; typeAnnotation } ->
      Expression.TypeCast {
        expression = map_expression ctx expression;
        typeAnnotation
      }
    | Expression.Array { elements } ->
      Expression.Array {
        elements = map_list ctx
            (fun ctx -> function
               | None ->
                 None
               | Some element ->
                 Some (map_expression_or_spread ctx element))
            elements
      }
    | Expression.Object { properties } ->
      Expression.Object {
        properties = map_list
            ctx
            (fun ctx prop -> match prop with
               | Expression.Object.Property property ->
                 let property = map_object_property ctx property in
                 Expression.Object.Property property
               | Expression.Object.SpreadProperty (loc, { argument }) ->
                 let argument = map_expression ctx argument in
                 Expression.Object.SpreadProperty (loc, { argument })
            )
            properties
      }

    | Expression.Function func ->
      let _, func = map_function ctx (loc, func) in
      Expression.Function func

    | Expression.ArrowFunction func ->
      let _, func = map_function ctx (loc, func) in
      Expression.ArrowFunction func

    | Expression.Sequence { expressions } ->
      let expressions = map_list ctx map_expression expressions in
      Expression.Sequence { expressions }

    | Expression.Unary ({ argument; _ } as n) ->
      let argument = map_expression ctx argument in
      Expression.Unary { n with argument; }

    | Expression.Binary ({ left; right; _ } as n) ->
      let left = map_expression ctx left in
      let right = map_expression ctx right in
      Expression.Binary { n with left; right }

    | Expression.Assignment ({ left; right; _ } as n) ->
      let left = map_pattern ctx left in
      let right = map_expression ctx right in
      Expression.Assignment { n with left; right }

    | Expression.Update ({ argument; _ } as n) ->
      let argument = map_expression ctx argument in
      Expression.Update { n with argument }

    | Expression.Logical ({ left; right; _ } as n) ->
      let left = map_expression ctx left in
      let right = map_expression ctx right in
      Expression.Logical { n with left; right }

    | Expression.Conditional { test; consequent; alternate } ->
      let test = map_expression ctx test in
      let consequent = map_expression ctx consequent in
      let alternate = map_expression ctx alternate in
      Expression.Conditional { test; consequent; alternate }

    | Expression.New { callee; arguments } ->
      let callee = map_expression ctx callee in
      let arguments = map_list ctx map_expression_or_spread arguments in
      Expression.New { callee; arguments }

    | Expression.Call { callee; arguments } ->
      let callee = map_expression ctx callee in
      let arguments = map_list ctx map_expression_or_spread arguments in
      Expression.Call { callee; arguments }

    | Expression.Member ({ _object; property; _ } as n) ->
      let _object = map_expression ctx _object in
      let property = match property with
        | Expression.Member.PropertyPrivateName _
        | Expression.Member.PropertyIdentifier _ -> property
        | Expression.Member.PropertyExpression expr ->
          let expr = map_expression ctx expr in
          Expression.Member.PropertyExpression expr
      in
      Expression.Member { n with _object; property }

    | Expression.Yield ({ argument; _ } as n) ->
      let argument = map_if_some ctx map_expression argument in
      Expression.Yield { n with argument; }

    | Expression.Class cls ->
      let cls = map_class ctx cls in
      Expression.Class cls

    | Expression.TemplateLiteral ({ expressions; _ } as template) ->
      Expression.TemplateLiteral {
        template with
        expressions = map_list ctx map_expression expressions
      }

    | Expression.TaggedTemplate {
        tag;
        quasi = (quasi_loc, ({ expressions; _} as quasi))
      } ->
      Expression.TaggedTemplate {
        tag = map_expression ctx tag;
        quasi = (quasi_loc, {
            quasi with
            expressions = map_list ctx map_expression expressions
        })
      }

    | node -> node
  in
  ctx.handler.map_expression ctx (loc, expression)

and map_pattern ctx (loc, pattern) =
  let pattern = match pattern with
    | Pattern.Object ({ properties; _ } as n) ->
      let properties = map_list
          ctx
          (fun ctx prop -> match prop with
             | Pattern.Object.RestProperty (loc, { argument }) ->
               let argument = map_pattern ctx argument in
               Pattern.Object.RestProperty (loc, { argument })
             | Pattern.Object.Property (loc, ({ key; pattern; _ } as n)) ->
               let key = map_pattern_property_key ctx key in
               let pattern  = map_pattern ctx pattern in
               Pattern.Object.Property (loc, { n with key; pattern })
          ) properties in
      Pattern.Object { n with properties; }

    | Pattern.Array ({ elements; _ } as n) ->
      let elements = map_list
          ctx
          (fun ctx element -> match element with
             | None -> None
             | Some (Pattern.Array.Element pattern) ->
               let pattern = map_pattern ctx pattern in
               Some (Pattern.Array.Element pattern)
             | Some (Pattern.Array.RestElement (loc, { argument })) ->
               let argument = map_pattern ctx argument in
               Some (Pattern.Array.RestElement (loc, { argument })))
          elements
      in
      Pattern.Array { n with elements }

    | Pattern.Assignment { left; right } ->
      let left = map_pattern ctx left in
      let right = map_expression ctx right in
      Pattern.Assignment { left; right }

    | Pattern.Expression expr ->
      let expr = map_expression ctx expr in
      Pattern.Expression expr
    | node -> node

  in ctx.handler.map_pattern ctx (loc, pattern)

and map_pattern_property_key ctx key =
  match key with
  | Pattern.Object.Property.Literal _ -> key
  | Pattern.Object.Property.Identifier _ -> key
  | Pattern.Object.Property.Computed expr ->
    let expr = map_expression ctx expr in
    Pattern.Object.Property.Computed expr

and map_object_property ctx (loc, prop) =
  let prop =
    match prop with
    | Expression.Object.Property.Init ({ key; value; _ } as n) ->
      Expression.Object.Property.Init {
        n with
        key = map_object_property_key ctx key;
        value = map_expression ctx value
      }
    | Expression.Object.Property.Method { key; value } ->
      Expression.Object.Property.Method {
        key = map_object_property_key ctx key;
        value = map_function ctx value
      }
    | Expression.Object.Property.Get { key; value } ->
      Expression.Object.Property.Get {
        key = map_object_property_key ctx key;
        value = map_function ctx value
      }
    | Expression.Object.Property.Set { key; value } ->
      Expression.Object.Property.Set {
        key = map_object_property_key ctx key;
        value = map_function ctx value
      }
  in
  (loc, prop)

and map_object_property_key ctx key =
  match key with
  | Expression.Object.Property.Computed expr ->
    let expr = map_expression ctx expr in
    Expression.Object.Property.Computed expr
  | node -> node

and map_function
    ctx
    (loc, ({ Function. params=(params_loc, { params; rest }); body; _ } as f)) =
  let f =
    let ctx = {
      ctx with
      scope = Scope.of_function ctx.parents (loc, f) ctx.scope;
      parents = APS.push_function (loc, f) ctx.parents
    }
    in
    let params =
      map_list ctx map_pattern params
    in
    let rest =
      map_if_some ctx
        (fun ctx (loc, { Function.RestElement. argument })
          -> (loc, {
              Function.RestElement. argument = map_pattern ctx argument
            }))
        rest
    in
    let body = map_function_body ctx body in
    Function.({
        f with
        params = (params_loc, { params; rest });
        body = body
      })
  in
  ctx.handler.map_function ctx (loc, f)

and map_function_body ctx body =
  match body with
  | Function.BodyBlock block ->
    let block = map_block ctx block in
    Function.BodyBlock block
  | Function.BodyExpression expr ->
    let expr = map_expression ctx expr in
    Function.BodyExpression expr

and map_block ctx (loc, block) =
  let ctx = {
    ctx with
    scope = Scope.of_block ctx.parents (loc, block) ctx.scope;
    parents = APS.push_block (loc, block) ctx.parents
  }
  in
  (loc, { body = map_statements ctx block.body })

and map_variable_declaration ctx (loc, ({ declarations; _ } as n)) =
  let declarations = map_list ctx map_variable_declarator declarations in
  (loc, { n with declarations; })

and map_variable_declarator ctx (loc, { init; id }) =
  let id = map_pattern ctx id in
  let init = match init with
    | None  -> None
    | Some expr -> Some (map_expression ctx expr)
  in (loc, { Statement.VariableDeclaration.Declarator. init; id })

and map_expression_or_spread ctx item = match item with
  | Expression.Expression expr ->
    let expr = map_expression ctx expr in
    Expression.Expression expr
  | Expression.Spread (loc, { argument }) ->
    let argument = map_expression ctx argument in
    Expression.Spread (loc, { argument })

let map handler (loc, statements, comments) =
  let ctx = {
    scope = fst @@ Scope.of_program statements;
    parents = [];
    handler
  }
  in
  let statements = map_statements ctx statements in
  (loc, statements, comments)
