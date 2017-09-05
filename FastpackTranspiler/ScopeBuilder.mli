(**
 * Abstract scope type.
 **)
type t

(**
 * An empty top level scope.
 **)
val empty : t

(**
 * Hook on visit Ast.Statement.t which produces the next scope which is going to
 * be used by the next statement within the statement list.
 **)
val visit_statement_h : t -> Ast.Statement.t -> t

(**
 * Hook on visit Ast.Statement.t which is produces the next scope which is
 * going to be used by the children of the statement
 **)
val visit_statement_v : t -> Ast.Statement.t -> t
