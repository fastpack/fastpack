module E = Ast.Expression
module P = Ast.Pattern
module S = Ast.Statement
module L = Ast.Literal
module T = Ast.Type
module V = Ast.Variance
module C = Ast.Class
module F = Ast.Function
module J = Ast.JSX

(** Printer context *)
type printer_ctx = {

  (** Current indentation level *)
  indent : int;

  (** Mutable buffer *)
  buf : Buffer.t;

  (** List of comments *)
  comments : Ast.Comment.t list;

  (** Last expression *)
  parent_expr : E.t' option;

  (** Last statement *)
  parent_stmt : S.t';

  (** Current scope *)
  scope: Scope.t;
}

module Parens = struct

  (*
   * This function uses slighly modified table from here:
   * https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Operators/Operator_Precedence
   * Modifications:
   * - ArrowFunction precedence made to be lower than anything else
   * - Sequence is always wrapped with parens when printing
   * - Spread argument is never wrapped since it has the lowest precedence
   * - new w/o the argument list is never emitted by the printer
   *   (precedence 18 in the table). I.e. we emit new Date().getTime() instead
   *   of (new Date).getTime()
   * - Function precedence is made to be 18 since it needs to be lower than
   *   Call to allow IIF
   * *)
  let precedence (node : E.t') =
    match node with
    | E.ArrowFunction _ -> 1
    | E.Yield _ -> 2
    | E.Assignment _ -> 3
    | E.Conditional _ -> 4
    | E.Logical { operator = E.Logical.Or; _ } -> 5
    | E.Logical { operator = E.Logical.And; _ } -> 6
    | E.Binary { operator = E.Binary.BitOr; _ } -> 7
    | E.Binary { operator = E.Binary.Xor; _ } -> 8
    | E.Binary { operator = E.Binary.BitAnd; _ } -> 9

    | E.Binary { operator = E.Binary.Equal; _ }
    | E.Binary { operator = E.Binary.NotEqual; _ }
    | E.Binary { operator = E.Binary.StrictEqual; _ }
    | E.Binary { operator = E.Binary.StrictNotEqual; _ } -> 10

    | E.Binary { operator = E.Binary.LessThan; _ }
    | E.Binary { operator = E.Binary.LessThanEqual; _ }
    | E.Binary { operator = E.Binary.GreaterThan; _ }
    | E.Binary { operator = E.Binary.GreaterThanEqual; _ }
    | E.Binary { operator = E.Binary.In; _ }
    | E.Binary { operator = E.Binary.Instanceof; _ } -> 11

    | E.Binary { operator = E.Binary.LShift; _ }
    | E.Binary { operator = E.Binary.RShift; _ }
    | E.Binary { operator = E.Binary.RShift3; _ } -> 12

    | E.Binary { operator = E.Binary.Plus; _ }
    | E.Binary { operator = E.Binary.Minus; _ } -> 13

    | E.Binary { operator = E.Binary.Mult; _ }
    | E.Binary { operator = E.Binary.Div; _ }
    | E.Binary { operator = E.Binary.Mod; _ } -> 14

    | E.Binary { operator = E.Binary.Exp; _ } -> 15

    | E.Unary _
    | E.Update { prefix = true; _ } -> 16

    | E.Update { prefix = false; _ } -> 17

    | E.Function _ -> 18

    | E.Call _
    | E.Class _
    | E.Import _
    | E.JSXElement _
    | E.Member _
    | E.New _ -> 19

    | E.Array _
    | E.Identifier _
    | E.Literal _
    | E.Object _
    | E.Sequence _
    | E.Super
    | E.TaggedTemplate _
    | E.TemplateLiteral _
    | E.This -> 100

    | E.TypeCast _ -> failwith "Precedence: TypeCast is not supported"
    | E.Generator _ -> failwith "Precedence: Generator is not supported"
    | E.Comprehension _ -> failwith "Precedence: Comprehension is not supported"
    | E.MetaProperty _ -> failwith "Precedence: MetaProperty is not supported"

  let is_required ((loc, node) : E.t)
      { comments; parent_expr; parent_stmt;  _ } =
    let has_comments =
      List.exists
        (fun ((c_loc : Loc.t), _) -> c_loc._end.offset < loc.start.offset)
        comments
    in
    has_comments ||
      match parent_stmt, parent_expr, node with
      | S.Expression _, None, E.Class _
      | S.Expression _, None, E.Function _ ->
        true
      | S.For _, None, E.Sequence _ ->
        false
      | _, _, E.Sequence _ ->
        true
      | _, Some parent, node ->
        precedence node < precedence parent
      | _ ->
        false
end

let fail_if cond message =
  if cond then failwith message else ()

let fail_if_some option message =
  match option with
  | Some _ -> failwith message
  | None -> ()

let set_parent_expr some_expr ctx =
  { ctx with parent_expr = some_expr }

let set_parent_stmt stmt ctx =
  { ctx with parent_stmt = stmt }

let emit str ctx =
  Buffer.add_string ctx.buf str;
  ctx

let emit_none ctx =
  ctx

let emit_newline ctx =
  let indent =
    if ctx.indent > 0 then String.make (ctx.indent * 2) ' ' else ""
  in
  Buffer.add_string ctx.buf "\n";
  Buffer.add_string ctx.buf indent;
  ctx

let increase_indent ctx =
  { ctx with indent = ctx.indent + 1 }

let decrease_indent ctx =
  { ctx with indent = ctx.indent - 1 }

let indent ctx =
  let ctx = { ctx with indent = ctx.indent + 1 } in
  emit_newline ctx

let dedent ctx =
  let ctx = { ctx with indent = ctx.indent - 1 } in
  emit_newline ctx

let emit_comma ctx =
  ctx |> emit ", "

let emit_comma_and_newline ctx =
  ctx |> emit "," |> emit_newline

let emit_semicolon ctx =
  ctx |> emit ";"

let emit_semicolon_and_newline ctx =
  ctx |> emit ";" |> emit_newline

let emit_space ctx =
  ctx |> emit " "

let rec emit_list ?emit_sep emit_item list ctx =
  match emit_sep with
  | None -> List.fold_left (fun ctx item -> emit_item item ctx) ctx list
  | Some emit_sep ->
    (match list with
     | [] -> ctx
     | item::[] ->
       emit_item item ctx
     | item::xs ->
       ctx |> emit_item item |> emit_sep |> emit_list ~emit_sep emit_item xs)

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

let print ?(with_scope=false) (_, statements, comments) =

  let rec emit_scope ?(sep="\n") ?(emit_newline_after=true) get_scope ctx =
    if with_scope
    then
      let ctx = { ctx with scope = get_scope ctx.scope } in
      let scope_str = Scope.scope_to_str ~sep ctx.scope in
      let lines = String.lines scope_str in
      let emit_scope_str =
        if List.length lines > 1
        then
          fun ctx ->
            let ctx = emit_newline ctx in
            List.fold_left
              (fun ctx s -> ctx |> emit s |> emit_newline)
              ctx
              lines
        else
          emit scope_str
      in
      ctx
      |> emit "/* SCOPE: "
      |> emit_scope_str
      |> emit " */"
      |> emit_if emit_newline_after emit_newline
    else
      ctx

  and remove_scope ctx =
    if with_scope
    then
      match ctx.scope.parent with
      | Some scope -> { ctx with scope }
      | None -> failwith "Should not happen"
    else
      ctx

  and emit_comment (_, comment) ctx =
    match comment with
    | Ast.Comment.Line s ->
      ctx |> emit "//" |> emit s |> emit_newline
    | Ast.Comment.Block s ->
      ctx |> emit "/*" |> emit s |> emit "*/" |> emit_newline

  and emit_comments (loc: Loc.t) ctx =
    let (before, after) = List.partition
        (fun ((c_loc : Loc.t), _) -> c_loc._end.offset < loc.start.offset)
        ctx.comments
    in
    let ctx = emit_list emit_comment before ctx in
    {ctx with comments = after}

  and emit_statement ((loc, statement) : S.t) ctx =
    let prev_parent_stmt = ctx.parent_stmt in
    let ctx = ctx |> emit_comments loc |> set_parent_stmt statement in
    let ctx =
      match statement with
      | S.Empty -> ctx

      | S.Block { body } ->
        ctx
        |> emit "{"
        |> indent
        |> emit_scope (Scope.block_scope statement)
        |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement body
        |> remove_scope
        |> dedent
        |> emit "}"

      | S.Expression { expression; directive = _directive } ->
        ctx
        |> emit_expression expression

      | S.If { test; consequent; alternate } ->
        ctx
        |> emit "if (" |> emit_expression test |> emit ") "
        |> emit_statement consequent
        |> emit_if_some (fun alternate ctx ->
            ctx
            |> emit " else "
            |> emit_statement alternate) alternate

      | S.Labeled { label = (_loc, label); body } ->
        ctx
        |> emit label
        |> emit ":"
        |> indent
        |> emit_statement body
        |> dedent

      | S.Break { label } ->
        ctx
        |> emit "break"
        |> emit_if_some
            (fun (_loc, name) ctx -> ctx |> emit_space |> emit name)
            label

      | S.Continue { label } ->
        ctx
        |> emit "continue"
        |> emit_if_some
            (fun (_loc, name) ctx -> ctx |> emit_space |> emit name)
            label

      | S.With { _object; body } ->
        ctx
        |> emit "with (" |> emit_expression _object |> emit ") "
        |> emit_statement body

      | S.TypeAlias { id = (_, id); typeParameters; right } ->
        ctx
        |> emit "type "
        |> emit id
        |> emit_if_some emit_type_parameter_declaration typeParameters
        |> emit " = "
        |> emit_type right

      | S.Switch { discriminant; cases } ->
        ctx
        |> emit "swicth (" |> emit_expression discriminant |> emit ") {"
        |> indent
        |> emit_list
          ~emit_sep:emit_newline
          (fun (_loc, { S.Switch.Case. test; consequent }) ctx ->
            ctx
            |> (match test with
                | None ->
                  emit "default:"
                | Some test ->
                  fun ctx ->
                    ctx |> emit "case " |> emit_expression test |> emit ":")
            |> emit_list
                ~emit_sep:emit_semicolon_and_newline
                emit_statement
                consequent
          ) cases
        |> dedent
        |> emit "}"

      | S.Return { argument } ->
        ctx |> emit "return " |> emit_if_some emit_expression argument

      | S.Throw { argument } ->
        ctx |> emit "throw " |> emit_expression argument

      | S.Try { block; handler; finalizer } ->
        ctx
        |> emit "try "
        |> emit_block block
        |> emit_if_some (fun (_loc, { S.Try.CatchClause. param; body }) ctx ->
            ctx
            |> emit " catch (" |> emit_pattern param |> emit ") "
            |> emit_block body
          ) handler
        |> emit_if_some (fun finalizer ctx ->
            ctx
            |> emit " finally "
            |> emit_block finalizer
          ) finalizer

      | S.While { test; body } ->
        ctx
        |> emit "while ("
        |> emit_expression test
        |> emit ") "
        |> emit_statement body

      | S.DoWhile { body; test } ->
        ctx
        |> emit "do "
        |> emit_statement body
        |> emit "while ("
        |> emit_expression test
        |> emit "("

      | S.For { init; test; update; body } ->
        ctx
        |> emit "for ("
        |> emit_if_some (fun init -> match init with
            | S.For.InitDeclaration decl -> emit_variable_declaration decl
            | S.For.InitExpression expression -> emit_expression expression) init
        |> emit_semicolon
        |> emit " "
        |> emit_if_some emit_expression test
        |> emit_semicolon
        |> emit " "
        |> emit_if_some emit_expression update
        |> emit ")"
        |> emit_scope ~sep:", " ~emit_newline_after:false (Scope.block_scope statement)
        |> indent
        |> emit_statement body
        |> dedent
        |> remove_scope

      | S.ForIn { left; right; body; each } ->
        assert (not each);
        ctx
        |> emit "for ("
        |> (match left with
            | S.ForIn.LeftDeclaration decl -> emit_variable_declaration decl
            | S.ForIn.LeftExpression expression -> emit_expression expression)
        |> emit " in "
        |> emit_expression right
        |> emit ")"
        |> indent
        |> emit_statement body
        |> dedent

      | S.ForOf { left; right; body; async } ->
        ctx
        |> emit "for "
        |> emit_if async (emit "await ")
        |> emit "("
        |> (match left with
            | S.ForOf.LeftDeclaration decl -> emit_variable_declaration decl
            | S.ForOf.LeftExpression expression -> emit_expression expression)
        |> emit " of "
        |> emit_expression right
        |> emit ")"
        |> indent
        |> emit_statement body
        |> dedent

      | S.Debugger ->
        ctx
        |> emit "debugger"

      | S.FunctionDeclaration func ->
        emit_function (loc, func) ctx

      | S.VariableDeclaration decl ->
        ctx
        |> emit_variable_declaration (loc, decl)

      | S.ClassDeclaration cls ->
        ctx |> emit_class cls
      | S.InterfaceDeclaration { id; typeParameters; body; extends; mixins } ->
        fail_if
          (List.length mixins > 0)
          "InterfaceDeclaration: mixins are not supported";
        ctx
        |> emit "interface "
        |> emit_identifier id
        |> emit_if (List.length extends > 0) (emit " extends ")
        |> emit_list ~emit_sep:emit_comma emit_generic_type extends
        |> emit_if_some emit_type_parameter_declaration typeParameters
        |> emit_object_type body

      | S.ImportDeclaration { importKind; source; specifiers; } ->
        let emit_kind kind =
          match kind with
          | Some S.ImportDeclaration.ImportType -> emit " type "
          | Some S.ImportDeclaration.ImportTypeof -> emit " typeof "
          | _ -> emit_none
        in
        let namespace =
          List.head_opt
          @@ List.filter
            (fun spec ->
               match spec with
               | S.ImportDeclaration.ImportNamespaceSpecifier _ -> true
               | _ -> false
            )
            specifiers
        in
        let default =
          List.head_opt
          @@ List.filter
            (fun spec ->
               match spec with
               | S.ImportDeclaration.ImportDefaultSpecifier _ -> true
               | _ -> false
            )
            specifiers
        in
        let named =
          List.filter
            (fun spec ->
               match spec with
               | S.ImportDeclaration.ImportNamedSpecifier _ -> true
               | _ -> false
            )
            specifiers
        in
        let emit_specifier spec ctx =
          ctx
          |> (match spec with
              | S.ImportDeclaration.ImportDefaultSpecifier ident ->
                emit_identifier ident
              | S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, ident)) ->
                emit @@ "* as " ^ ident
              | S.ImportDeclaration.ImportNamedSpecifier
                  { kind; local; remote = (_, remote) } ->
                fun ctx ->
                  ctx
                  |> emit_kind kind
                  |> emit remote
                  |> emit_if_some (fun local -> emit @@ " as " ^ (snd local)) local
             )
        in
        ctx
        |> emit "import"
        |> emit_kind (Some importKind)
        |> emit_if (List.length specifiers > 0) (emit " ")
        |> emit_if_some emit_specifier default
        |> emit_if_some emit_specifier namespace
        |> emit_if
          ((default != None || namespace != None) && List.length named > 0)
          emit_comma
        |> emit_if
            (List.length named > 0)
            (fun ctx ->
               ctx
               |> emit "{"
               |> emit_list ~emit_sep:emit_comma emit_specifier named
               |> emit "}"
            )
        |> emit_if (List.length specifiers > 0) (emit " from")
        |> emit " "
        |> emit_literal source

      | S.ExportNamedDeclaration _ ->
        failwith "ExportNamedDeclaration is not supported"
      | S.ExportDefaultDeclaration _ ->
        failwith "ExportDefaultDeclaration is not supported"
      | S.DeclareVariable _ ->
        failwith "DeclareVariable is not supported"
      | S.DeclareFunction _ ->
        failwith "DeclareFunction is not supported"
      | S.DeclareClass _ ->
        failwith "DeclareClass is not supported"
      | S.DeclareModule _ ->
        failwith "DeclareModule is not supported"
      | S.DeclareModuleExports _ ->
        failwith "DeclareModuleExports is not supported"
      | S.DeclareExportDeclaration _ ->
        failwith "DeclareExportDeclaration is not supported"
    in
    ctx |> set_parent_stmt prev_parent_stmt

  and emit_expression ?(parens=true) ((loc, expression) : E.t) ctx =
    let parens = parens && Parens.is_required (loc, expression) ctx in
    let prev_parent_expr = ctx.parent_expr in
    let ctx =
      ctx
      |> emit_if parens (emit "(")
      |> emit_comments loc
      |> set_parent_expr (Some expression)
    in
    let ctx =
      match expression with
      | E.This -> ctx |> emit "this"
      | E.Super -> ctx |> emit "super"
      | E.Array { elements } ->
        ctx
        |> emit "["
        |> emit_list ~emit_sep:emit_comma
          (function
            | None -> emit_none
            | Some element -> emit_expression_or_spread element)
          elements
        |> emit "]"
      | E.Import expr ->
        ctx
        |> emit "import("
        |> emit_expression ~parens:false expr
        |> emit ")"
      | E.Object { properties } ->
        ctx
        |> emit "{"
        |> emit_list ~emit_sep:emit_comma
          (fun prop ctx -> match prop with
             | E.Object.Property (loc, { key; value; _method; shorthand }) ->
               let ctx = emit_comments loc ctx in
               begin
                 match value with
                  | E.Object.Property.Init expr ->
                    if shorthand then
                      ctx |> emit_object_property_key key
                    else
                      ctx
                      |> emit_object_property_key key
                      |> emit ": "
                      |> emit_expression ~parens:false expr
                  | E.Object.Property.Get func ->
                    ctx
                    |> emit "get "
                    |> emit_function
                      ~emit_id:(emit_object_property_key key)
                      ~as_method:true
                      func
                  | E.Object.Property.Set func ->
                    ctx
                    |> emit "set "
                    |> emit_function
                      ~emit_id:(emit_object_property_key key)
                      ~as_method:true
                      func
               end
             | E.Object.SpreadProperty (loc, { argument }) ->
               ctx
               |> emit_comments loc
               |> emit "..."
               |> emit_expression ~parens:false argument
          )
          properties
        |> emit "}"
      | E.Function func ->
        ctx |> emit_function (loc, func)
      | E.ArrowFunction func ->
        ctx |> emit_function (loc, func) ~as_arrow:true
      | E.Sequence { expressions } ->
        ctx
        |> emit_list
          ~emit_sep:emit_comma
          (emit_expression ~parens:false)
          expressions
      | E.Unary { operator; prefix=_prefix; argument } ->
        (* fail_if prefix "Unary: prefix is not supported"; *)
        ctx
        |> (match operator with
            | E.Unary.Minus -> emit "-"
            | E.Unary.Plus -> emit "+"
            | E.Unary.Not -> emit "!"
            | E.Unary.BitNot -> emit "~"
            | E.Unary.Typeof -> emit "typeof "
            | E.Unary.Void -> emit "void "
            | E.Unary.Delete -> emit "delete "
            | E.Unary.Await -> emit "await ")
        |> emit_expression argument
      | E.Binary { operator; left; right } ->
        ctx
        |> emit_expression left
        |> (match operator with
            | E.Binary.Equal -> emit " == "
            | E.Binary.NotEqual -> emit " != "
            | E.Binary.StrictEqual -> emit " === "
            | E.Binary.StrictNotEqual -> emit " !== "
            | E.Binary.LessThan -> emit " < "
            | E.Binary.LessThanEqual -> emit " <= "
            | E.Binary.GreaterThan -> emit " > "
            | E.Binary.GreaterThanEqual -> emit " >= "
            | E.Binary.LShift -> emit " << "
            | E.Binary.RShift -> emit " >> "
            | E.Binary.RShift3 -> emit " >>> "
            | E.Binary.Plus -> emit " + "
            | E.Binary.Minus -> emit " - "
            | E.Binary.Mult -> emit " * "
            | E.Binary.Exp -> emit " ** "
            | E.Binary.Div -> emit " / "
            | E.Binary.Mod -> emit " % "
            | E.Binary.BitOr -> emit " | "
            | E.Binary.Xor -> emit " ^ "
            | E.Binary.BitAnd -> emit " & "
            | E.Binary.In -> emit " in "
            | E.Binary.Instanceof -> emit " instanceof ")
        |> emit_expression right
      | E.Assignment { operator; left; right } ->
        ctx
        |> emit_pattern left
        |> (match operator with
            | E.Assignment.Assign -> emit " = "
            | E.Assignment.PlusAssign -> emit " += "
            | E.Assignment.MinusAssign -> emit " -= "
            | E.Assignment.MultAssign -> emit " *= "
            | E.Assignment.ExpAssign -> emit " **= "
            | E.Assignment.DivAssign -> emit " /= "
            | E.Assignment.ModAssign -> emit " %= "
            | E.Assignment.LShiftAssign -> emit " <<= "
            | E.Assignment.RShiftAssign -> emit " >>= "
            | E.Assignment.RShift3Assign -> emit " >>>= "
            | E.Assignment.BitOrAssign -> emit " |= "
            | E.Assignment.BitXorAssign -> emit " ^= "
            | E.Assignment.BitAndAssign -> emit " &= ")
        |> emit_expression right
      | E.Update { operator; argument; prefix } ->
        let emit_operator ctx =
          ctx |> (match operator with
              | E.Update.Increment -> emit "++"
              | E.Update.Decrement -> emit "--") in
        if prefix
        then ctx |> emit_operator |> emit_expression argument
        else ctx |> emit_expression argument |> emit_operator
      | E.Logical { operator; left; right } ->
        ctx
        |> emit_expression left
        |> (match operator with
            | E.Logical.Or -> emit " || "
            | E.Logical.And -> emit " && ")
        |> emit_expression right
      | E.Conditional { test; consequent; alternate } ->
        ctx
        |> emit_expression test
        |> emit " ? "
        |> emit_expression consequent
        |> emit " : "
        |> emit_expression alternate
      | E.New { callee; arguments } ->
        ctx
        |> emit "new "
        |> emit_expression callee
        |> emit "("
        |> emit_list ~emit_sep:emit_comma emit_expression_or_spread arguments
        |> emit ")"
      | E.Call { callee; arguments } ->
        ctx
        |> emit_expression callee
        |> emit "("
        |> emit_list ~emit_sep:emit_comma emit_expression_or_spread arguments
        |> emit ")"
      | E.Member { _object; property; computed } ->
        let emit_property property =
          match property with
          | E.Member.PropertyIdentifier (_, name) ->
            emit name
          | E.Member.PropertyExpression expression ->
            emit_expression ~parens:false expression
        in
        ctx
        |> emit_expression _object
        |> (fun ctx ->
            if computed
            then (ctx |> emit "[" |> emit_property property |> emit "]")
            else (ctx |> emit "." |> emit_property property))
      | E.Yield { argument; delegate } ->
        ctx
        |> (if delegate then emit "yield* " else emit "yield ")
        |> emit_if_some emit_expression argument
      | E.Comprehension _ ->
        failwith "Comprehension is not supported"
      | E.Generator _ ->
        failwith "Generator is not supported"
      | E.Identifier (_, name) ->
        ctx |> emit name
      | E.Literal lit ->
        ctx |> emit_literal (loc, lit)
      | E.TemplateLiteral tmpl_lit ->
        ctx |> emit_template_literal tmpl_lit
      | E.TaggedTemplate { tag; quasi=(_, tmpl_lit) } ->
        ctx
        |> emit_expression tag
        |> emit_template_literal tmpl_lit
      | E.JSXElement element ->
        ctx |> emit_jsx_element element
      | E.Class cls ->
        ctx |> emit_class cls
      | E.TypeCast _ ->
        failwith "TypeCast is not supported"
      | E.MetaProperty _ ->
        failwith "MetaProperty is not supported"
    in
    ctx
    |> emit_if parens (emit ")")
    |> set_parent_expr prev_parent_expr

  and emit_jsx_element {
      openingElement = (_, { J.Opening.  name; selfClosing; attributes; });
      children;
      closingElement;
      } ctx =
    let emit_identifier ((_, { name }) : J.Identifier.t) =
      emit name
    in
    let emit_namespaced_name
        ((_, { namespace; name }) : J.NamespacedName.t ) ctx =
      ctx
      |> emit_identifier namespace
      |> emit ":"
      |> emit_identifier name
    in
    let emit_name name =
      let rec emit_member_expression
          ((_, { _object; property }) : J.MemberExpression.t) ctx =
        ctx
        |> (match _object with
            | J.MemberExpression.MemberExpression expr ->
              emit_member_expression expr
            | J.MemberExpression.Identifier ident ->
              emit_identifier ident)
        |> emit "."
        |> emit_identifier property
      in
      match name with
      | J.Identifier ident ->
        emit_identifier ident
      | J.NamespacedName n_name ->
        emit_namespaced_name n_name
      | J.MemberExpression expr ->
        emit_member_expression expr
    in
    let emit_expression_container { J.ExpressionContainer. expression } ctx =
      ctx
      |> emit "{"
      |> (match expression with
          | J.ExpressionContainer.Expression expr ->
            emit_expression ~parens:false expr
          | J.ExpressionContainer.EmptyExpression _ ->
            emit_none
         )
      |> emit "}"
    in
    ctx
    |> emit "<"
    |> emit_name name
    |> emit_if (List.length attributes > 0) emit_newline
    |> emit_list ~emit_sep:emit_newline
      (fun attr ctx ->
         match attr with
         | J.Opening.Attribute (_, { name; value; }) ->
           ctx
           |> (match name with
               | J.Attribute.Identifier ident ->
                 emit_identifier ident
               | J.Attribute.NamespacedName n_name ->
                 emit_namespaced_name n_name
              )
           |> emit_if_some
             (fun value ctx ->
               ctx
               |> emit "="
               |> (match value with
                   | J.Attribute.Literal (loc, lit) ->
                     emit_literal (loc, lit)
                   | J.Attribute.ExpressionContainer (_, expr) ->
                     emit_expression_container expr
                  )
             )
             value
         | J.Opening.SpreadAttribute (_, { argument })->
           ctx
           |> emit "{..."
           |> emit_expression argument (* TODO: do we need parens here? *)
           |> emit "}"
      )
      attributes
    |> emit_if selfClosing (emit "/")
    |> emit ">"
    |> emit_list
      (fun (_, child) ->
         match child with
         | J.Text { raw; _ } -> emit raw
         | J.ExpressionContainer expr -> emit_expression_container expr
         | J.Element element -> emit_jsx_element element
      )
      children
    |> emit_if_some
      (fun _ ctx -> ctx |> emit "</" |> emit_name name |> emit ">")
      closingElement

  and emit_class { id;
                   body = (_, { body });
                   superClass; typeParameters;
                   superTypeParameters;
                   implements;
                   classDecorators; } ctx =
    let emit_class_element item ctx =
      match item with
      | C.Body.Method (loc, {
          kind;
          key;
          value;
          static;
          decorators
        }) ->
        ctx
        |> emit_comments loc
        |> emit_list emit_decorator decorators
        |> (if static then emit "static " else emit_none)
        |> (match kind with
            | C.Method.Constructor -> emit_none
            | C.Method.Method -> emit_none
            | C.Method.Get -> emit "get "
            | C.Method.Set -> emit "set ")
        |> emit_function
            ~as_method:true
            ~emit_id:(emit_object_property_key key)
            value
      | C.Body.Property (loc, {
          key;
          value;
          typeAnnotation;
          static;
          variance
        }) ->
        ctx
        |> emit_comments loc
        |> (if static then emit "static " else emit_none)
        |> emit_if_some emit_variance variance
        |> emit_object_property_key key
        |> emit_if_some emit_type_annotation typeAnnotation
        |> emit_if_some (fun _ -> emit " = ") value
        |> emit_if_some emit_expression value
        |> emit_semicolon
    in
    begin
      fail_if
        (List.length implements > 0)
        "ClassDeclaration: implements is not supported";
      ctx
      |> emit_list emit_decorator classDecorators
      |> emit "class "
      |> emit_if_some emit_identifier id
      |> emit_if_some emit_type_parameter_declaration typeParameters
      |> emit_if_some
        (fun superClass ctx ->
           ctx |> emit " extends " |> emit_expression superClass)
        superClass
      |> emit_if_some emit_type_parameter_instantiation superTypeParameters
      |> emit " {"
      |> indent
      |> emit_list ~emit_sep:emit_newline emit_class_element body
      |> dedent
      |> emit "}"
    end

  and emit_template_literal { quasis; expressions; } ctx =
    let emit_expressions =
      List.map
        (fun e -> fun ctx ->
           ctx
           |> emit "${"
           |> emit_expression ~parens:false e
           |> emit "}")
        expressions
      @ [emit_none]
    in
    let quasis =
      List.map
        (fun (_, {E.TemplateLiteral.Element. value={ raw; _ }; _ }) -> raw)
        quasis
    in
    ctx
    |> emit "`"
    |> emit_list
      (fun (text, emit_expression) ctx ->
         ctx
         |> emit text
         |> emit_expression)
      (List.combine quasis emit_expressions)
    |> emit "`"

  and emit_pattern ((loc, pattern) : P.t) ctx =
    let ctx = emit_comments loc ctx in
    match pattern with
    | P.Object { properties; typeAnnotation } ->
      ctx
      |> emit "{"
      |> emit_list ~emit_sep:emit_comma
        (fun prop ctx -> match prop with
           | P.Object.Property (_,{ key; pattern; shorthand }) ->
             ctx
             |> emit_object_pattern_property_key key
             |> emit_if
                (not shorthand)
                (fun ctx -> ctx |> emit ": " |> emit_pattern pattern)
           | P.Object.RestProperty (_,{ argument }) ->
             ctx |> emit "..." |> emit_pattern argument
        ) properties
      |> emit "}"
      |> emit_if_some emit_type_annotation typeAnnotation
    | P.Array { elements; typeAnnotation } ->
      ctx
      |> emit "["
      |> emit_list ~emit_sep:emit_comma
        (fun element ctx -> match element with
           | None -> ctx
           | Some (P.Array.Element pattern) ->
             emit_pattern pattern ctx
           | Some (P.Array.RestElement (_,{ argument })) ->
             ctx |> emit "..." |> emit_pattern argument)
        elements
      |> emit "]"
      |> emit_if_some emit_type_annotation typeAnnotation
    | P.Assignment { left; right } ->
      ctx |> emit_pattern left |> emit " = " |> emit_expression right
    | P.Identifier { name; typeAnnotation; optional } ->
      ctx
      |> emit_identifier name
      |> (if optional then emit "?" else emit_none)
      |> emit_if_some emit_type_annotation typeAnnotation
    | P.Expression expr -> emit_expression expr ctx

  and emit_object_pattern_property_key key ctx =
    match key with
    | P.Object.Property.Literal lit ->
      emit_literal lit ctx
    | P.Object.Property.Identifier id ->
      emit_identifier id ctx
    | P.Object.Property.Computed expr ->
      ctx |> emit "[" |> emit_expression expr |> emit "]"

  and emit_object_property_key key ctx =
    match key with
    | E.Object.Property.Literal lit ->
      ctx |> emit_literal lit
    | E.Object.Property.Identifier id ->
      ctx |> emit_identifier id
    | E.Object.Property.Computed expr ->
      ctx |> emit "[" |> emit_expression ~parens:false expr |> emit "]"

  and emit_decorator decorator ctx =
    ctx
    |> emit "@("
    |> emit_expression decorator
    |> emit ")"
    |> emit_newline

  and emit_function ?(as_arrow=false) ?(as_method=false) ?emit_id (loc, {
      F.
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
    (** TODO: handle `predicate`, `expression` ? *)
    let get_scope statements =
      let params, rest = params in
      let arguments =
        List.flatten
        @@ List.append
          (List.map Scope.names_of_pattern params)
          (match rest with
           | Some (_, { F.RestElement.  argument }) ->
             [Scope.names_of_pattern argument]
           | None -> []
          )
      in
      Scope.func_scope arguments statements
    in
    let omit_parameter_parens =
      match as_arrow, fst params, snd params with
      | true, [(_, P.Object _)], _ -> false
      | true, [_], None -> true
      | _ -> false
    in
    ctx
    |> emit_comments loc
    |> (if async then emit "async " else emit_none)
    |> (if not as_method && not as_arrow then emit "function " else emit_none)
    |> (if generator then emit "*" else emit_none)
    |> (match emit_id with
        | None -> emit_if_some emit_identifier id
        | Some emit_id -> emit_id)
    |> emit_if_some emit_type_parameter_declaration typeParameters
    |> emit_if (not omit_parameter_parens) (emit "(")
    |> (
      let (params, rest) = params in fun ctx ->
        ctx
        |> emit_list ~emit_sep:emit_comma emit_pattern params
        |> emit_if_some (fun (_loc, { F.RestElement.  argument }) ctx ->
            ctx |> emit " ..." |> emit_pattern argument) rest
    )
    |> emit_if (not omit_parameter_parens) (emit ")")
    |> emit_if as_arrow (emit " => ")
    |> emit_if_some emit_type_annotation returnType
    |> emit_space
    |> (match body with
        | F.BodyBlock (loc, { body; }) ->
          fun ctx ->
            ctx
            |> emit_comments loc
            |> emit "{"
            |> indent
            |> emit_scope (get_scope body)
            |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement body
            |> remove_scope
            |> dedent
            |> emit "}"
        | F.BodyExpression expr ->
          fun ctx ->
            let parens =
              match expr with
              | _, E.Object _ -> true
              | _ -> false
            in
            ctx
            |> emit_scope ~sep:", " ~emit_newline_after:false (get_scope [])
            |> emit_if parens (emit "(")
            |> emit_expression ~parens:false expr
            |> emit_if parens (emit ")")
            |> remove_scope
       )

  and emit_type_annotation (loc, typeAnnotation) ctx =
    ctx |> emit_comments loc |> emit ": " |> emit_type typeAnnotation

  and emit_variance (_, variance) =
    match variance with
    | V.Plus -> emit "+"
    | V.Minus -> emit "-"

  and emit_block ((loc, block) : (Loc.t * S.Block.t)) ctx =
    ctx
    |> emit_comments loc
    |> emit "{"
    |> indent
    |> emit_list ~emit_sep:emit_semicolon_and_newline emit_statement block.body
    |> dedent
    |> emit "}"

  and emit_identifier ((loc, identifier) : Ast.Identifier.t) ctx =
    ctx |> emit_comments loc |> emit identifier

  and emit_variable_declaration (loc, { declarations; kind }) ctx =
    ctx
    |> emit_comments loc
    |> emit (match kind with
        | S.VariableDeclaration.Var  -> "var "
        | S.VariableDeclaration.Let  -> "let "
        | S.VariableDeclaration.Const  -> "const ")
    |> increase_indent
    |> emit_list
      ~emit_sep:emit_comma_and_newline
      emit_variable_declarator
      declarations
    |> decrease_indent

  and emit_variable_declarator (loc, { id; init }) ctx =
    ctx
    |> emit_comments loc
    |> emit_pattern id
    |> emit_if_some
      (fun init ctx -> ctx |> emit " = " |> emit_expression init)
      init

  and emit_expression_or_spread item ctx = match item with
    | E.Expression expression ->
      ctx |> emit_expression ~parens:false expression
    | E.Spread (_, { argument }) ->
      ctx |> emit "..." |> emit_expression ~parens:false argument

  and emit_type (loc, value) ctx =
    let ctx = emit_comments loc ctx in
    match value with
    | T.Any -> emit "any" ctx
    | T.Mixed -> emit "mixed" ctx
    | T.Empty -> ctx
    | T.Void -> emit "void" ctx
    | T.Null -> emit "null" ctx
    | T.Number -> emit "number" ctx
    | T.String -> emit "string" ctx
    | T.Boolean -> emit "boolean" ctx
    | T.Nullable typ -> ctx |> emit "?" |> emit_type typ
    | T.Function typ -> emit_function_type (loc, typ) ctx
    | T.Object typ ->
      emit_object_type (loc, typ) ctx
    | T.Array typ ->
      ctx |> emit "Array<" |> emit_type typ |> emit ">"
    | T.Generic typ -> emit_generic_type (loc, typ) ctx
    | T.Union (_,_,_) -> ctx
    | T.Intersection (_,_,_) -> ctx
    | T.Typeof typ ->
      ctx
      |> emit "typeof "
      |> emit_type typ
    | T.Tuple typs ->
      ctx
      |> emit "["
      |> emit_list ~emit_sep:emit_comma emit_type typs
      |> emit "]"
    | T.StringLiteral { value = _; raw } -> emit raw ctx
    | T.NumberLiteral { value = _; raw } -> emit raw ctx
    | T.BooleanLiteral { value = _; raw } -> emit raw ctx
    | T.Exists -> emit "*" ctx

  and emit_object_type (_loc, _value) _ctx =
    failwith "emit_object_type: not implemented"

  and emit_type_generic_identifier id ctx =
    match id with
    | T.Generic.Identifier.Unqualified id ->
      ctx |> emit_identifier id
    | T.Generic.Identifier.Qualified (_loc, { qualification; id }) ->
      ctx
      |> emit_identifier id
      |> emit ": "
      |> emit_type_generic_identifier qualification

  and emit_generic_type (loc, { id; typeParameters }) ctx =
    ctx
    |> emit_comments loc
    |> emit_type_generic_identifier id
    |> emit_if_some emit_type_parameter_instantiation typeParameters

  and emit_function_type (_loc, _value) _ctx =
    failwith "emit_function_type: not implemented"

  and emit_type_parameter (loc, value) ctx =
    let { T.ParameterDeclaration.TypeParam.
          name;
          bound;
          variance;
          default } = value
    in
    ctx
    |> emit_comments loc
    |> emit_if_some emit_variance variance
    |> emit name
    |> emit_if_some
      (fun (_, bound) ctx -> ctx |> emit ": " |> emit_type bound)
      bound
    |> emit_if_some
      (fun default ctx -> ctx |> emit " = " |> emit_type default)
      default

  and emit_type_parameter_declaration (loc, { params }) ctx =
    ctx
    |> emit_comments loc
    |> emit "<"
    |> emit_list ~emit_sep:emit_comma emit_type_parameter params
    |> emit ">"

  and emit_type_parameter_instantiation (loc, { params }) ctx =
    ctx
    |> emit_comments loc
    |> emit "<"
    |> emit_list ~emit_sep:emit_comma emit_type params
    |> emit ">"

  and emit_literal (loc, { raw; value = _value }) ctx =
    ctx |> emit_comments loc |> emit raw
  in

  let emit_statements statements ctx =
    let ctx =
      ctx
      |> emit_list
        ~emit_sep:emit_semicolon_and_newline
        emit_statement
        statements
      |> emit_semicolon_and_newline
    in
    ctx |> emit_list emit_comment ctx.comments
  in

  let get_initial_scope =
    Scope.func_scope [] statements
  in

  let ctx = emit_scope get_initial_scope {
    buf = Buffer.create 1024;
    indent = 0;
    comments = comments;
    parent_expr = None;
    parent_stmt = S.Empty;
    scope = Scope.empty;
  } in
  Buffer.to_bytes (emit_statements statements ctx).buf
