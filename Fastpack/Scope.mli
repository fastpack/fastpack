(** Abstract scope type. *)
type t

(** An empty top level scope. *)
val empty : t

(** Grow scope given a statement. *)
val on_statement : t -> Ast.Statement.t -> t
val on_program : t -> Ast.program -> t

val block_scope_boundary : Ast.Statement.t -> bool
val func_scope_boundary : Ast.Statement.t -> bool

val bindings : t -> string list
val peek_func_scope : t -> (t * t list)
