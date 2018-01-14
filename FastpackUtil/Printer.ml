module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module E = Ast.Expression
module P = Ast.Pattern
module S = Ast.Statement
module L = Ast.Literal
module SL = Ast.StringLiteral
module T = Ast.Type
module V = Ast.Variance
module C = Ast.Class
module F = Ast.Function
module J = Ast.JSX

module APS = AstParentStack

let debug = Logs.debug

(** Printer context *)
type printer_ctx = {
  (** Current indentation level *)
  indent : int;

  (** Mutable buffer *)
  buf : Buffer.t;

  (** List of comments *)
  comments : Loc.t Ast.Comment.t list;

  (** Parent stack *)
  parents : APS.parent list;

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
  let precedence node =
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
    | E.JSXFragment _
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

  let is_required ((loc : Loc.t), node) { comments; parents;  _ } =
    let has_comments =
      List.exists
        (fun ((c_loc : Loc.t), _) -> c_loc._end.offset < loc.start.offset)
        comments
    in
    let parent_stmt, parent_expr =
      match APS.top_statement parents, APS.top_expression parents with
      | None, _ ->
        (* we always expect parent statement to be in the stack at this moment *)
        assert false;
      | Some (_, stmt), None ->
        stmt, None
      | Some (_, stmt), Some (_, expr) ->
        stmt, Some expr
    in
    has_comments ||
      match parent_stmt, parent_expr, node with
      | S.Expression _, None, E.Identifier _
      | S.Expression _, None, E.ArrowFunction _
      | S.Expression _, None, E.Object _
      | S.Expression _, None, E.Class _
      | S.Expression _, None, E.Function _ ->
        true
      | S.Expression _, _, E.Assignment {
          operator = E.Assignment.Assign; left = (_, P.Object _); _ } ->
        true
      | S.Expression _, _, E.Assignment {
          operator = E.Assignment.Assign; left = (_, P.Array _); _ } ->
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

let push_parent_stmt stmt ctx =
  { ctx with parents = APS.push_statement stmt ctx.parents }

let pop_parent_stmt stmt ctx =
  assert (List.hd ctx.parents = (APS.Statement stmt));
  { ctx with parents = List.tl ctx.parents }

let push_parent_function func ctx =
  { ctx with parents = APS.push_function func ctx.parents }

let pop_parent_function func ctx =
  assert (List.hd ctx.parents = (APS.Function func));
  { ctx with parents = List.tl ctx.parents }

let push_parent_block block ctx =
  { ctx with parents = APS.push_block block ctx.parents }

let pop_parent_block block ctx =
  assert (List.hd ctx.parents = (APS.Block block));
  { ctx with parents = List.tl ctx.parents }

let push_parent_expr expr ctx =
  { ctx with parents = APS.push_expression expr ctx.parents }

let pop_parent_expr expr ctx =
  assert (List.hd ctx.parents = (APS.Expression expr));
  { ctx with parents = List.tl ctx.parents }

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

let print ?(with_scope=false) (_, (statements : Loc.t S.t list), comments) =

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
      | None -> assert false
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
    if List.length before > 0 then
      let ctx = emit_list emit_comment before ctx in
      {ctx with comments = after}
    else
      ctx

  and emit_statement (loc, statement) ctx =
    let ctx = ctx |> emit_comments loc |> push_parent_stmt (loc, statement) in
    let ctx =
      match statement with
      | S.Empty -> ctx

      | S.Block block ->
        ctx
        |> emit_block (loc, block)

      | S.Expression { expression; directive = _directive } ->
        ctx
        |> emit_expression expression
        |> emit_semicolon_and_newline

      | S.If { test; consequent; alternate } ->
        ctx
        |> emit "if (" |> emit_expression test |> emit ") "
        |> emit_statement consequent
        |> emit_if_some
          (fun alternate ctx ->
            ctx
            |> emit " else "
            |> emit_statement alternate
          )
          alternate

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
        |> emit_semicolon_and_newline

      | S.Continue { label } ->
        ctx
        |> emit "continue"
        |> emit_if_some
            (fun (_loc, name) ctx -> ctx |> emit_space |> emit name)
            label
        |> emit_semicolon_and_newline

      | S.With { _object; body } ->
        ctx
        |> emit "with (" |> emit_expression _object |> emit ") "
        |> emit_statement body

      | S.Switch { discriminant; cases } ->
        ctx
        |> emit "switch (" |> emit_expression discriminant |> emit ") {"
        |> indent
        |> emit_list
          ~emit_sep:emit_newline
          (fun (_loc, { S.Switch.Case. test; consequent }) ctx ->
            ctx
            |> (match test with
                | None ->
                  emit "default:\n"
                | Some test ->
                  fun ctx ->
                    ctx |> emit "case " |> emit_expression test |> emit ":\n")
            |> emit_statements consequent
          ) cases
        |> dedent
        |> emit "}"

      | S.Return { argument } ->
        ctx
        |> emit "return "
        |> emit_if_some emit_expression argument
        |> emit_semicolon_and_newline

      | S.Throw { argument } ->
        ctx
        |> emit "throw "
        |> emit_expression argument
        |> emit_semicolon_and_newline

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
        |> emit_newline

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
        |> emit ")"
        |> emit_semicolon_and_newline

      | S.For { init; test; update; body } ->
        ctx
        |> emit "for ("
        |> emit_if_some
          (fun init ->
             match init with
             | S.For.InitDeclaration decl ->
               emit_variable_declaration ~emit_sep:emit_comma decl
             | S.For.InitExpression expression ->
               emit_expression expression
          )
          init
        |> emit_semicolon
        |> emit " "
        |> emit_if_some emit_expression test
        |> emit_semicolon
        |> emit " "
        |> emit_if_some emit_expression update
        |> emit ")"
        |> emit_scope
          ~sep:", "
          ~emit_newline_after:false
          @@ Scope.of_statement (List.tl ctx.parents) (loc, statement)
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
            | S.ForIn.LeftPattern pattern -> emit_pattern pattern)
        |> emit " in "
        |> emit_expression right
        |> emit ")"
        |> emit_scope
          ~sep:", "
          ~emit_newline_after:false
          @@ Scope.of_statement (List.tl ctx.parents) (loc, statement)
        |> indent
        |> emit_statement body
        |> dedent
        |> remove_scope

      | S.ForOf { left; right; body; async } ->
        ctx
        |> emit "for "
        |> emit_if async (emit "await ")
        |> emit "("
        |> (match left with
            | S.ForOf.LeftDeclaration decl -> emit_variable_declaration decl
            | S.ForOf.LeftPattern pattern -> emit_pattern pattern)
        |> emit " of "
        |> emit_expression right
        |> emit ")"
        |> emit_scope
          ~sep:", "
          ~emit_newline_after:false
          @@ Scope.of_statement (List.tl ctx.parents) (loc, statement)
        |> indent
        |> emit_statement body
        |> dedent
        |> remove_scope

      | S.Debugger ->
        ctx
        |> emit "debugger"
        |> emit_semicolon_and_newline

      | S.FunctionDeclaration func ->
        emit_function (loc, func) ctx

      | S.VariableDeclaration decl ->
        ctx
        |> emit_variable_declaration (loc, decl)
        |> emit_semicolon_and_newline

      | S.ClassDeclaration cls ->
        ctx |> emit_class cls

      | S.ImportDeclaration { importKind; source; specifiers; default } ->
        let emit_kind kind =
          match kind with
          | Some S.ImportDeclaration.ImportType -> emit " type "
          | Some S.ImportDeclaration.ImportTypeof -> emit " typeof "
          | _ -> emit_none
        in
        let emit_specifiers specifiers ctx =
          ctx
          |> (match specifiers with
              | S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, ident)) ->
                emit ("* as " ^ ident)
              | S.ImportDeclaration.ImportNamedSpecifiers specifiers ->
                let emit_specifier {S.ImportDeclaration. kind; local; remote} ctx =
                  ctx
                  |> emit_kind kind
                  |> emit_identifier remote
                  |> emit_if_some
                    (fun local ctx -> ctx |> emit " as " |> emit_identifier local)
                    local
                in
                fun ctx ->
                 ctx
                 |> emit "{"
                 |> emit_list ~emit_sep:emit_comma emit_specifier specifiers
                 |> emit "}"
             )
        in
        let has_names = default <> None || specifiers <> None in
        ctx
        |> emit "import"
        |> emit_kind (Some importKind)
        |> emit_if has_names (emit " ")
        |> emit_if_some emit_identifier default
        |> emit_if (default <> None && specifiers <> None) emit_comma
        |> emit_if_some emit_specifiers specifiers
        |> emit_if has_names (emit " from")
        |> emit " "
        |> emit_string_literal source
        |> emit_semicolon_and_newline

      | S.ExportNamedDeclaration {
          declaration;
          specifiers;
          source;
          exportKind } ->
        let emit_specifiers spec ctx =
          match spec with
          | S.ExportNamedDeclaration.ExportSpecifiers specifiers ->
            ctx
            |> emit "{ "
            |> emit_list ~emit_sep:emit_comma
              (fun (_,{S.ExportNamedDeclaration.ExportSpecifier.
                        local; exported }) ctx ->
                ctx
                |> emit_identifier local
                |> emit_if_some
                  (fun exported ctx ->
                     ctx
                     |> emit " as "
                     |> emit_identifier exported
                  )
                  exported
              )
              specifiers
            |> emit " }"
          | S.ExportNamedDeclaration.ExportBatchSpecifier (_, exported) ->
            ctx
            |> emit "*"
            |> emit_if_some
              (fun exported ctx ->
                 ctx |> emit " as " |> emit_identifier exported
              )
              exported
        in
        ctx
        |> emit "export "
        |> emit_if (exportKind = S.ExportType) (emit "type ")
        |> emit_if_some emit_statement declaration
        |> emit_if_some emit_specifiers specifiers
        |> emit_if_some
          (fun source ctx -> ctx |> emit " from " |> emit_string_literal source)
          source
        |> emit_semicolon_and_newline

      | S.ExportDefaultDeclaration { declaration; _ } ->
        ctx
        |> emit "export default "
        |> (match declaration with
            | S.ExportDefaultDeclaration.Declaration stmt ->
              emit_statement stmt
            | S.ExportDefaultDeclaration.Expression expr ->
              emit_expression expr)
        |> emit_semicolon_and_newline
      | S.InterfaceDeclaration _ ->
        failwith "Interface declaration is not supported"
      | S.TypeAlias _ ->
        failwith "TypeAlias is not supported"
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
      | S.DeclareInterface _ -> failwith "DeclareInterface not supported"
      | S.DeclareTypeAlias _ -> failwith "DeclareTypeAlias not supported"
      | S.DeclareOpaqueType _ -> failwith "DeclareOpaqueType not supported"
      | S.OpaqueType _ -> failwith "OpaqueType not supported"
    in
    ctx |> pop_parent_stmt (loc, statement)

  and emit_expression ?(parens=true) (loc, expression) ctx =
    let parens = parens && Parens.is_required (loc, expression) ctx in
    let ctx =
      ctx
      |> emit_if parens (emit "(")
      |> emit_comments loc
      |> push_parent_expr (loc, expression)
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
          (fun prop ctx ->
             match prop with
             | E.Object.Property (loc, prop) ->
               let ctx = emit_comments loc ctx in
               begin
                 match prop with
                 | E.Object.Property.Init { key; value; shorthand } ->
                   if shorthand then
                     ctx |> emit_object_property_key key
                   else
                     ctx
                     |> emit_object_property_key key
                     |> emit ": "
                     |> emit_expression ~parens:false value
                 | E.Object.Property.Method { key; value; } ->
                   ctx
                   |> emit_function
                     ~emit_id:(emit_object_property_key key)
                     ~as_method:true
                     value
                 | E.Object.Property.Get { key; value } ->
                   ctx
                   |> emit "get "
                   |> emit_function
                     ~emit_id:(emit_object_property_key key)
                     ~as_method:true
                     value
                 | E.Object.Property.Set { key; value } ->
                   ctx
                   |> emit "set "
                   |> emit_function
                     ~emit_id:(emit_object_property_key key)
                     ~as_method:true
                     value
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
          | E.Member.PropertyPrivateName name ->
            emit_private_name name
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
      | E.JSXFragment { frag_openingElement = _; frag_closingElement = _; frag_children } ->
        ctx
        |> emit "<>"
        |> emit_jsx_children frag_children
        |> emit "</>"
      | E.Class cls ->
        ctx |> emit_class cls
      | E.TypeCast _ ->
        failwith "TypeCast is not supported"
      | E.MetaProperty _ ->
        failwith "MetaProperty is not supported"
    in
    ctx
    |> emit_if parens (emit ")")
    |> pop_parent_expr (loc, expression)

  and emit_jsx_expression_container { J.ExpressionContainer. expression } ctx =
    ctx
    |> emit "{"
    |> (match expression with
        | J.ExpressionContainer.Expression expr ->
          emit_expression ~parens:false expr
        | J.ExpressionContainer.EmptyExpression _ ->
          emit_none
        )
    |> emit "}"

  and emit_jsx_children children ctx =
    ctx
    |> emit_list
      (fun (_, child) ->
         match child with
         | J.Text { raw; _ } -> emit raw
         | J.ExpressionContainer expr -> emit_jsx_expression_container expr
         | J.Element element -> emit_jsx_element element
         | J.Fragment _ | J.SpreadChild _ -> failwith "Fragment/SpreadChild are not implemented"
      )
      children

  and emit_jsx_element {
      openingElement = (_, { J.Opening.  name; selfClosing; attributes; });
      children;
      closingElement;
      } ctx =
    let emit_identifier (_, {J.Identifier. name }) =
      emit name
    in
    let emit_namespaced_name (_, {J.NamespacedName. namespace; name }) ctx =
      ctx
      |> emit_identifier namespace
      |> emit ":"
      |> emit_identifier name
    in
    let emit_name name =
      let rec emit_member_expression (_, {J.MemberExpression. _object; property }) ctx =
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
                     emit_jsx_expression_container expr
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
    |> emit_jsx_children children
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
      | C.Body.PrivateField _ ->
        failwith "Class PrivateField is not implemented"
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

  and emit_pattern (loc, pattern) ctx =
    let ctx = emit_comments loc ctx in
    match pattern with
    | P.Object { properties; typeAnnotation } ->
      ctx
      |> emit "{"
      |> emit_list ~emit_sep:emit_comma
        (fun prop ctx -> match prop with
           | P.Object.Property (_,{ key; pattern; shorthand; }) ->
             ctx
             |> emit_if
               (not shorthand)
               (fun ctx -> ctx |> emit_object_pattern_property_key key |> emit ": ")
             |> emit_pattern pattern
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
    | P.Expression expr ->
      emit_expression expr ctx

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
    | E.Object.Property.PrivateName name ->
      ctx |> emit_private_name name
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

  and emit_function ?(as_arrow=false) ?(as_method=false) ?emit_id ((loc, {
      F.
      id;
      params = (_, {params; rest});
      body;
      async;
      generator;
      predicate = _predicate;
      expression = _expression;
      returnType;
      typeParameters
    }) as f) ctx =
    (** TODO: handle `predicate`, `expression` ? *)
    let omit_parameter_parens =
      match as_arrow, params, rest with
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
    |> emit_list ~emit_sep:emit_comma emit_pattern params
    |> emit_if (List.length params > 0 && rest <> None) (emit ",")
    |> emit_if_some (fun (_loc, { F.RestElement.  argument }) ctx ->
        ctx |> emit " ..." |> emit_pattern argument) rest
    |> emit_if (not omit_parameter_parens) (emit ")")
    |> emit_scope
      ~sep:", "
      ~emit_newline_after:false
      (Scope.of_function ctx.parents f)
    |> emit_if as_arrow (emit " => ")
    |> emit_if_some emit_type_annotation returnType
    |> emit_space
    |> (match body with
        | F.BodyBlock ((loc, _) as block) ->
          fun ctx ->
            ctx
            |> emit_comments loc
            |> push_parent_function f
            |> emit_block block
            |> pop_parent_function f
            |> emit_newline
        | F.BodyExpression expr ->
          fun ctx ->
            let parens =
              match expr with
              | _, E.Object _ -> true
              | _ -> false
            in
            ctx
            |> emit_if parens (emit "(")
            |> push_parent_function f
            |> emit_expression ~parens:false expr
            |> pop_parent_function f
            |> emit_if parens (emit ")")
       )
    |> remove_scope

  and emit_type_annotation (loc, typeAnnotation) ctx =
    ctx |> emit_comments loc |> emit ": " |> emit_type typeAnnotation

  and emit_variance (_, variance) =
    match variance with
    | V.Plus -> emit "+"
    | V.Minus -> emit "-"

  and emit_block (loc, block) ctx =
    ctx
    |> emit_comments loc
    |> emit "{"
    |> emit_scope (Scope.of_block ctx.parents (loc, block))
    |> indent
    |> push_parent_block (loc, block)
    |> emit_statements block.body
    |> pop_parent_block (loc, block)
    |> remove_scope
    |> dedent
    |> emit "}"

  and emit_identifier (loc, identifier) ctx =
    ctx |> emit_comments loc |> emit identifier

  and emit_variable_declaration
      ?(emit_sep=emit_comma_and_newline)
      (loc, { declarations; kind }) ctx =
    ctx
    |> emit_comments loc
    |> emit (match kind with
        | S.VariableDeclaration.Var  -> "var "
        | S.VariableDeclaration.Let  -> "let "
        | S.VariableDeclaration.Const  -> "const ")
    |> increase_indent
    |> emit_list
      ~emit_sep
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
    | T.BooleanLiteral value -> emit (if value then "true" else "false") ctx
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
    |> emit_identifier name
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

  and emit_literal (loc, {L. raw; _ }) ctx =
    ctx |> emit_comments loc |> emit raw

  and emit_string_literal (_, {SL. raw; _ }) =
    emit raw

  and emit_private_name (loc, (_, name)) ctx =
    ctx |> emit_comments loc |> emit "#" |> emit name

  and emit_statements statements =
    emit_list emit_statement statements
  in

  let ctx = emit_scope (fun _ -> fst @@ Scope.of_program statements) {
    buf = Buffer.create 1024;
    indent = 0;
    comments = comments;
    parents = [];
    scope = Scope.empty;
  } in
  Buffer.to_bytes
    (ctx
     |> emit_statements statements
     |> (fun ctx -> emit_list emit_comment ctx.comments ctx)
    ).buf
