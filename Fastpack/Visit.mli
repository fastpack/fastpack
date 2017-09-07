type visit_action = Continue | Break

type visit_handler = {
  visit_statement : Ast.Statement.t -> visit_action;
  visit_expression : Ast.Expression.t -> visit_action;
  visit_function : (Loc.t * Ast.Function.t) -> visit_action;
  visit_pattern : Ast.Pattern.t -> visit_action;
}

val do_nothing : 'a -> visit_action

val default_visit_handler : visit_handler

val visit : visit_handler -> Ast.program -> unit
val visit_list : visit_handler -> (visit_handler -> 'a -> unit) -> 'a list -> unit
val visit_expression : visit_handler -> Ast.Expression.t -> unit
val visit_statement : visit_handler -> Ast.Statement.t -> unit
val visit_pattern : visit_handler -> Ast.Pattern.t -> unit
val visit_block : visit_handler -> (Loc.t * Ast.Statement.Block.t) -> unit
val visit_object_property : visit_handler -> Ast.Expression.Object.Property.t -> unit
val visit_variable_declarator : visit_handler -> Ast.Statement.VariableDeclaration.Declarator.t -> unit
