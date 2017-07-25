module Expression = Ast.Expression
module Pattern = Ast.Pattern
module Statement = Ast.Statement
module Literal = Ast.Literal
module Type = Ast.Type
module Variance = Ast.Variance
module Class = Ast.Class

(** Printer context *)
type printer_ctx = {

  (** Current indentation level *)
  indent : int;

  (** Mutable buffer *)
  buf : Buffer.t;
}

let emit str ctx =
  Buffer.add_string ctx.buf str;
  ctx

let emit_none ctx =
  ctx

let emit_newline ctx =
  let indent = if ctx.indent > 0 then String.make (ctx.indent * 2) ' ' else "" in
  Buffer.add_string ctx.buf "\n";
  Buffer.add_string ctx.buf indent;
  ctx

let indent ctx =
  let ctx = { ctx with indent = ctx.indent + 1 } in
  emit_newline ctx

let dedent ctx =
  let ctx = { ctx with indent = ctx.indent - 1 } in
  emit_newline ctx

let emit_comma ctx =
  ctx |> emit ","

let emit_semicolon ctx =
  ctx |> emit ";"

let emit_semicolon_and_newline ctx =
  ctx |> emit ";" |> emit_newline

let  emit_space ctx =
  ctx |> emit " "

let rec emit_list ?emit_sep emit_item list ctx =
  match emit_sep with
  | None -> List.fold_left (fun ctx item -> emit_item item ctx) ctx list
  | Some emit_sep ->
    (match list with
     | [] -> ctx
     | item::[] -> emit_item item ctx
     | item::xs -> ctx |> emit_item item |> emit_sep |> emit_list ~emit_sep emit_item xs)

let emit_if cond emit ctx =
  if cond then emit ctx else ctx

let emit_if_some emit option ctx =
  match option with
  | Some item -> emit item ctx
  | None -> ctx

let  emit_if_none emit option ctx =
  match option with
  | Some _ -> ctx
  | None -> emit ctx

let print program =

  let rec emit_statement ((loc, statement) : Statement.t) ctx =
    match statement with
    | Statement.Empty -> ctx

    | Statement.Block { body } ->
      ctx
      |> emit "{"
      |> indent
      |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement body
      |> dedent
      |> emit "}"

    | Statement.Expression { expression; directive = _directive } ->
      emit_expression expression ctx

    | Statement.If { test; consequent; alternate } ->
      ctx
      |> emit "if (" |> emit_expression test |> emit ") "
      |> emit_statement consequent
      |> emit_if_some (fun alternate ctx ->
          ctx
          |> emit " else "
          |> emit_statement alternate) alternate

    | Statement.Labeled { label = (_loc, label); body } ->
      ctx
      |> emit label
      |> emit ":"
      |> indent
      |> emit_statement body
      |> dedent

    | Statement.Break { label } ->
      ctx
      |> emit "break"
      |> emit_if_some (fun (_loc, name) ctx -> ctx |> emit_space |> emit name) label

    | Statement.Continue { label } ->
      ctx
      |> emit "continue"
      |> emit_if_some (fun (_loc, name) ctx -> ctx |> emit_space |> emit name) label

    | Statement.With { _object; body } ->
      ctx
      |> emit "with (" |> emit_expression _object |> emit ") "
      |> emit_statement body

    | Statement.TypeAlias { id = (_, id); typeParameters; right } ->
      ctx
      |> emit "type "
      |> emit id
      |> emit_if_some emit_type_parameter_declaration typeParameters
      |> emit " = "
      |> emit_type right

    | Statement.Switch { discriminant; cases } ->
      ctx
      |> emit "swicth (" |> emit_expression discriminant |> emit ") {"
      |> indent
      |> emit_list ~emit_sep:emit_newline (fun (_loc, { Statement.Switch.Case. test; consequent }) ctx ->
          ctx
          |> (match test with
              | None -> emit "default:"
              | Some test -> fun ctx -> ctx |> emit "case " |> emit_expression test |> emit ":")
          |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement consequent
        ) cases
      |> dedent
      |> emit "}"

    | Statement.Return { argument } ->
      ctx |> emit "return " |> emit_if_some emit_expression argument

    | Statement.Throw { argument } ->
      ctx |> emit "throw " |> emit_expression argument

    | Statement.Try { block; handler; finalizer } ->
      ctx
      |> emit "try "
      |> emit_block block
      |> emit_if_some (fun (_loc, { Statement.Try.CatchClause. param; body }) ctx ->
          ctx
          |> emit " catch (" |> emit_pattern param |> emit ") "
          |> emit_block body
        ) handler
      |> emit_if_some (fun finalizer ctx ->
          ctx
          |> emit " finally "
          |> emit_block finalizer
        ) finalizer

    | Statement.While { test; body } ->
      ctx
      |> emit "while ("
      |> emit_expression test
      |> emit ") "
      |> emit_statement body

    | Statement.DoWhile { body; test } ->
      ctx
      |> emit "do "
      |> emit_statement body
      |> emit "while ("
      |> emit_expression test
      |> emit "("

    | Statement.For { init; test; update; body } ->
      ctx
      |> emit "for ("
      |> emit_if_some (fun init -> match init with
          | Statement.For.InitDeclaration decl -> emit_variable_declaration decl
          | Statement.For.InitExpression expression -> emit_expression expression) init
      |> emit_semicolon
      |> emit_if_some emit_expression test
      |> emit_semicolon
      |> emit_if_some emit_expression update
      |> emit ")"
      |> indent
      |> emit_statement body
      |> dedent

    | Statement.ForIn { left; right; body; each = _each } ->
      (* TODO: handle `each` *)
      ctx
      |> emit "for ("
      |> (match left with
          | Statement.ForIn.LeftDeclaration decl -> emit_variable_declaration decl
          | Statement.ForIn.LeftExpression expression -> emit_expression expression)
      |> emit " in "
      |> emit_expression right
      |> emit ")"
      |> indent
      |> emit_statement body
      |> dedent

    | Statement.ForOf { left; right; body; async = _async } ->
      (* TODO: handle `async` *)
      ctx
      |> emit "for ("
      |> (match left with
          | Statement.ForOf.LeftDeclaration decl -> emit_variable_declaration decl
          | Statement.ForOf.LeftExpression expression -> emit_expression expression)
      |> emit " of "
      |> emit_expression right
      |> emit ")"
      |> indent
      |> emit_statement body
      |> dedent

    | Statement.Debugger ->
      ctx
      |> emit "debugger"

    | Statement.FunctionDeclaration func ->
      emit_function (loc, func) ctx

    | Statement.VariableDeclaration decl ->
      ctx
      |> emit_variable_declaration (loc, decl)

    | Statement.ClassDeclaration { id;
                                   body = (_, { body });
                                   superClass;
                                   typeParameters;
                                   superTypeParameters;
                                   implements = _implements;
                                   classDecorators = _classDecorators;
                                 } ->
      (** TODO: handle `classDecorators` *)
      (** TODO: handle `implements` *)
      ctx
      |> emit "class "
      |> emit_if_some emit_identifier id
      |> emit_if_some emit_type_parameter_declaration typeParameters
      |> emit_if_some
        (fun superClass ctx -> ctx |> emit " extends " |> emit_expression superClass)
        superClass
      |> emit_if_some emit_type_parameter_instantiation superTypeParameters
      |> emit " {"
      |> indent
      |> emit_list ~emit_sep:emit_newline (fun item ctx -> match item with

          | Class.Body.Method (_loc, {
              kind;
              key;
              value;
              static;
              decorators = _decorators
            }) ->
            (** TODO: handle `decorators` *)
            ctx
            |> (if static then emit "static " else emit_none)
            |> (match kind with
                | Class.Method.Constructor -> emit_none
                | Class.Method.Method -> emit_none
                | Class.Method.Get -> emit "get "
                | Class.Method.Set -> emit "set ")
            |> emit_function ~as_method:true ~emit_id:(emit_object_property_key key) value

          | Class.Body.Property (_loc, { key; value; typeAnnotation; static; variance }) ->
            ctx
            |> (if static then emit "static " else emit_none)
            |> emit_if_some emit_variance variance
            |> emit_object_property_key key
            |> emit_if_some emit_type_annotation typeAnnotation
            |> emit " = "
            |> emit_if_some emit_expression value
            |> emit_semicolon

        ) body
      |> dedent
      |> emit "}"

    | Statement.InterfaceDeclaration { id; typeParameters; body; extends; mixins = _mixins} ->
      (** TODO: handle `mixins` *)
      ctx
      |> emit "interface "
      |> emit_identifier id
      |> emit_if (List.length extends > 0) (emit " extends ")
      |> emit_list ~emit_sep:emit_comma emit_generic_type extends
      |> emit_if_some emit_type_parameter_declaration typeParameters
      |> emit_object_type body

    | Statement.ExportNamedDeclaration _ -> ctx
    | Statement.ExportDefaultDeclaration _ -> ctx
    | Statement.ImportDeclaration _ -> ctx

    (** TODO: implement cases below *)
    | Statement.DeclareVariable _ -> ctx
    | Statement.DeclareFunction _ -> ctx
    | Statement.DeclareClass _ -> ctx
    | Statement.DeclareModule _ -> ctx
    | Statement.DeclareModuleExports _ -> ctx
    | Statement.DeclareExportDeclaration _ -> ctx

  and emit_expression ((loc, expression) : Expression.t) ctx =
    match expression with
    | Expression.Import _ ->
      (** TODO: handle import() *)
      ctx
    | Expression.This -> ctx |> emit "this"
    | Expression.Super -> ctx |> emit "super"
    | Expression.Array { elements } ->
      ctx
      |> emit "["
      |> emit_list ~emit_sep:emit_comma
        (function
          | None -> emit_none
          | Some element -> emit_expression_or_spread element)
        elements
      |> emit "]"
    | Expression.Object { properties } ->
      ctx
      |> emit "{"
      |> emit_list ~emit_sep:emit_comma
        (fun prop ctx -> match prop with
           | Expression.Object.Property (_, { key; value; _method; shorthand = _shorthand }) ->
             (match value with
              | Expression.Object.Property.Init expr ->
                ctx |> emit_object_property_key key |> emit ": " |> emit_expression expr
              | Expression.Object.Property.Get func ->
                ctx |> emit "get " |> emit_function func
              | Expression.Object.Property.Set func ->
                ctx |> emit "set " |> emit_function func)
           | Expression.Object.SpreadProperty (_, { argument }) ->
             ctx |> emit "..." |> emit_expression argument
        )
        properties
      |> emit "}"
    | Expression.Function func ->
      ctx |> emit_function (loc, func)
    | Expression.ArrowFunction _ -> ctx
    | Expression.Sequence { expressions } ->
      ctx
      |> emit "("
      |> emit_list ~emit_sep:emit_comma emit_expression expressions
      |> emit ")"
    | Expression.Unary { operator; prefix = _prefix; argument } ->
      (* TODO: handle prefix *)
      ctx
      |> (match operator with
          | Expression.Unary.Minus -> emit "-"
          | Expression.Unary.Plus -> emit "+"
          | Expression.Unary.Not -> emit "!"
          | Expression.Unary.BitNot -> emit "~"
          | Expression.Unary.Typeof -> emit "typeof "
          | Expression.Unary.Void -> emit "void "
          | Expression.Unary.Delete -> emit "delete "
          | Expression.Unary.Await -> emit "await ")
      |> emit_expression argument
    | Expression.Binary { operator; left; right } ->
      ctx
      |> emit_expression left
      |> (match operator with
          | Expression.Binary.Equal -> emit " == "
          | Expression.Binary.NotEqual -> emit " != "
          | Expression.Binary.StrictEqual -> emit " === "
          | Expression.Binary.StrictNotEqual -> emit " !== "
          | Expression.Binary.LessThan -> emit " < "
          | Expression.Binary.LessThanEqual -> emit " <= "
          | Expression.Binary.GreaterThan -> emit " > "
          | Expression.Binary.GreaterThanEqual -> emit " >= "
          | Expression.Binary.LShift -> emit " << "
          | Expression.Binary.RShift -> emit " >> "
          | Expression.Binary.RShift3 -> emit " >>> "
          | Expression.Binary.Plus -> emit " + "
          | Expression.Binary.Minus -> emit " - "
          | Expression.Binary.Mult -> emit " * "
          | Expression.Binary.Exp -> emit " ** "
          | Expression.Binary.Div -> emit " / "
          | Expression.Binary.Mod -> emit " % "
          | Expression.Binary.BitOr -> emit " | "
          | Expression.Binary.Xor -> emit " ^ "
          | Expression.Binary.BitAnd -> emit " & "
          | Expression.Binary.In -> emit " in "
          | Expression.Binary.Instanceof -> emit " instanceof ")
      |> emit_expression right
    | Expression.Assignment { operator; left; right } ->
      ctx
      |> emit_pattern left
      |> (match operator with
          | Expression.Assignment.Assign -> emit " = "
          | Expression.Assignment.PlusAssign -> emit " += "
          | Expression.Assignment.MinusAssign -> emit " -= "
          | Expression.Assignment.MultAssign -> emit " *= "
          | Expression.Assignment.ExpAssign -> emit " **= "
          | Expression.Assignment.DivAssign -> emit " /= "
          | Expression.Assignment.ModAssign -> emit " %= "
          | Expression.Assignment.LShiftAssign -> emit " <<= "
          | Expression.Assignment.RShiftAssign -> emit " >>= "
          | Expression.Assignment.RShift3Assign -> emit " >>>= "
          | Expression.Assignment.BitOrAssign -> emit " |= "
          | Expression.Assignment.BitXorAssign -> emit " ^= "
          | Expression.Assignment.BitAndAssign -> emit " &= ")
      |> emit_expression right
    | Expression.Update { operator; argument; prefix } ->
      let emit_operator ctx =
        ctx |> (match operator with
            | Expression.Update.Increment -> emit "++"
            | Expression.Update.Decrement -> emit "--") in
      if prefix
      then ctx |> emit_operator |> emit_expression argument
      else ctx |> emit_expression argument |> emit_operator
    | Expression.Logical { operator; left; right } ->
      ctx
      |> emit_expression left
      |> (match operator with
          | Expression.Logical.Or -> emit " || "
          | Expression.Logical.And -> emit " && ")
      |> emit_expression right
    | Expression.Conditional { test; consequent; alternate } ->
      ctx
      |> emit_expression test
      |> emit " ? "
      |> emit_expression consequent
      |> emit " : "
      |> emit_expression alternate
    | Expression.New { callee; arguments } ->
      ctx
      |> emit "new "
      |> emit_expression callee
      |> emit "("
      |> emit_list ~emit_sep:emit_comma emit_expression_or_spread arguments
      |> emit ")"
    | Expression.Call { callee; arguments } ->
      ctx
      |> emit_expression callee
      |> emit "("
      |> emit_list ~emit_sep:emit_comma emit_expression_or_spread arguments
      |> emit ")"
    | Expression.Member { _object; property; computed } ->
      ctx |> emit_expression _object |> (fun ctx ->
          if computed
          then (ctx |> emit "[" |> emit_property property |> emit "]")
          else (ctx |> emit "." |> emit_property property))
    | Expression.Yield { argument; delegate } ->
      ctx
      |> (if delegate then emit "yield* " else emit "yield ")
      |> emit_if_some emit_expression argument
    | Expression.Comprehension _ -> ctx
    | Expression.Generator _ -> ctx
    | Expression.Identifier (_, name) ->
      ctx |> emit name
    | Expression.Literal lit ->
      ctx |> emit_literal (loc, lit)
    | Expression.TemplateLiteral _ -> ctx
    | Expression.TaggedTemplate _ -> ctx
    | Expression.JSXElement _ -> ctx
    | Expression.Class _ -> ctx
    | Expression.TypeCast _ -> ctx
    | Expression.MetaProperty _ -> ctx

  and emit_pattern ((_loc, pattern) : Pattern.t) ctx =
    match pattern with
    | Pattern.Object { properties; typeAnnotation } ->
      ctx
      |> emit "{"
      |> emit_list ~emit_sep:emit_comma
        (fun prop ctx -> match prop with
           | Pattern.Object.Property (_,{ key; pattern; shorthand = _shorthand }) ->
             (** TODO: what to do with `shorthand`? *)
             ctx |> emit_pattern pattern |> emit ": " |> emit_object_pattern_property_key key
           | Pattern.Object.RestProperty (_,{ argument }) ->
             ctx |> emit "..." |> emit_pattern argument
        ) properties
      |> emit "}"
      |> emit_if_some emit_type_annotation typeAnnotation
    | Pattern.Array { elements; typeAnnotation } ->
      ctx
      |> emit "["
      |> emit_list ~emit_sep:emit_comma
        (fun element ctx -> match element with
           | None -> ctx
           | Some (Pattern.Array.Element pattern) ->
             emit_pattern pattern ctx
           | Some (Pattern.Array.RestElement (_,{ argument })) ->
             ctx |> emit "..." |> emit_pattern argument)
        elements
      |> emit "]"
      |> emit_if_some emit_type_annotation typeAnnotation
    | Pattern.Assignment { left; right } ->
      ctx |> emit_pattern left |> emit " = " |> emit_expression right
    | Pattern.Identifier { name; typeAnnotation; optional } ->
      ctx
      |> emit_identifier name
      |> (if optional then emit "?" else emit_none)
      |> emit_if_some emit_type_annotation typeAnnotation
    | Pattern.Expression expr -> emit_expression expr ctx

  and emit_object_pattern_property_key key ctx =
    match key with
    | Pattern.Object.Property.Literal lit -> emit_literal lit ctx
    | Pattern.Object.Property.Identifier id -> emit_identifier id ctx
    | Pattern.Object.Property.Computed expr -> ctx |> emit "[" |> emit_expression expr |> emit "]"

  and emit_object_property_key key ctx =
    match key with
    | Expression.Object.Property.Literal lit ->
      ctx |> emit_literal lit
    | Expression.Object.Property.Identifier id ->
      ctx |> emit_identifier id
    | Expression.Object.Property.Computed expr ->
      ctx |> emit "[" |> emit_expression expr |> emit "]"

  and emit_function ?(as_method=false) ?emit_id (_loc, {
      Ast.Function.
      id;
      params;
      body;
      async;
      generator;
      predicate = _predicate;
      expression = _expression;
      returnType;
      typeParameters
    }) ctx =
    (** TODO: handle `predicate` *)
    ctx
    |> (if async then emit "async " else emit_none)
    |> (if not as_method then emit "function " else emit_none)
    |> (if generator then emit "*" else emit_none)
    |> (match emit_id with
        | None -> emit_if_some emit_identifier id
        | Some emit_id -> emit_id)
    |> emit_if_some emit_type_parameter_declaration typeParameters
    |> emit "("
    |> (
      let (params, rest) = params in fun ctx ->
        ctx
        |> emit_list ~emit_sep:emit_comma emit_pattern params
        |> emit_if_some (fun (_loc, { Ast.Function.RestElement.  argument }) ctx ->
            ctx |> emit " ..." |> emit_pattern argument) rest
    )
    |> emit ")"
    |> emit_if_some emit_type_annotation returnType
    |> emit_space
    |> (match body with
        | Ast.Function.BodyBlock block -> emit_block block
        | Ast.Function.BodyExpression expr -> emit_expression expr)

  and emit_type_annotation (_loc, typeAnnotation) ctx =
    ctx |> emit ": " |> emit_type typeAnnotation

  and emit_variance (_loc, variance) =
    match variance with
    | Variance.Plus -> emit "+"
    | Variance.Minus -> emit "-"

  and emit_block ((_loc, block) : (Loc.t * Statement.Block.t)) ctx =
    ctx
    |> emit "{"
    |> indent
    |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement block.body
    |> dedent
    |> emit "}"

  and emit_identifier ((_loc, identifier) : Ast.Identifier.t) =
    emit identifier

  and emit_variable_declaration _value ctx =
    ctx

  and emit_expression_or_spread item ctx = match item with
    | Expression.Expression expression -> ctx |> emit_expression expression
    | Expression.Spread (_, { argument }) -> ctx |> emit "..." |> emit_expression argument

  and emit_property property ctx =
    match property with
    | Expression.Member.PropertyIdentifier (_, name) -> emit name ctx
    | Expression.Member.PropertyExpression expression -> emit_expression expression ctx

  and emit_type (loc, value) ctx = match value with
    | Type.Any -> emit "any" ctx
    | Type.Mixed -> emit "mixed" ctx
    | Type.Empty ->
      (* TODO: hm... *)
      ctx
    | Type.Void -> emit "void" ctx
    | Type.Null -> emit "null" ctx
    | Type.Number -> emit "number" ctx
    | Type.String -> emit "string" ctx
    | Type.Boolean -> emit "boolean" ctx
    | Type.Nullable typ -> ctx |> emit "?" |> emit_type typ
    | Type.Function { params = _params; returnType = _returnType; typeParameters = _typeParameters} -> ctx
    | Type.Object typ -> emit_object_type (loc, typ) ctx
    | Type.Array _ -> ctx
    | Type.Generic typ -> emit_generic_type (loc, typ) ctx
    | Type.Union (_,_,_) -> ctx
    | Type.Intersection (_,_,_) -> ctx
    | Type.Typeof _ -> ctx
    | Type.Tuple _ -> ctx
    | Type.StringLiteral _ -> ctx
    | Type.NumberLiteral _ -> ctx
    | Type.BooleanLiteral _ -> ctx
    | Type.Exists -> ctx

  and emit_object_type (_loc, _value) ctx =
    ctx

  and emit_generic_type (_loc, _value) ctx =
    ctx

  and emit_type_parameter (_loc, value) ctx =
    let { Type.ParameterDeclaration.TypeParam. name; bound; variance; default } = value in
    ctx
    |> emit_if_some emit_variance variance
    |> emit name
    |> emit_if_some (fun (_, bound) ctx -> ctx |> emit ": " |> emit_type bound) bound
    |> emit_if_some (fun default ctx -> ctx |> emit " = " |> emit_type default) default

  and emit_type_parameter_declaration (_loc, { params }) ctx =
    ctx |> emit "<" |> emit_list ~emit_sep:emit_comma emit_type_parameter params |> emit ">"

  and emit_type_parameter_instantiation _value ctx =
    ctx

  and emit_literal (_loc, { raw; value = _value }) ctx =
    emit raw ctx
  in

  let emit_program ((_, statements, _): Ast.program) ctx =
    emit_list ~emit_sep:emit_semicolon_and_newline emit_statement statements ctx
  in

  let ctx = { buf = Buffer.create 1024; indent = 0 } in
  Buffer.to_bytes (emit_program program ctx).buf
