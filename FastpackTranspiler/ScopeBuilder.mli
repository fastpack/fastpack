(** Abstract scope type. *)
type t

(** An empty top level scope. *)
val empty : t

(** Grow scope given a statement. *)
val grow : t -> Ast.Statement.t -> t
