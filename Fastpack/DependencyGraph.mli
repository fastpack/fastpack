(**
 * Mutable dependency graph.
 *)

type t

exception Cycle of string list

(** Construct an empty depgraph, the ?size is used as an estimate. *)
val empty : ?size:int -> unit -> t

(** Add module to the depgraph. *)
val add_module : t -> Module.t -> unit

(** Remove module from the depgraph. *)
val remove_module : t -> Module.t -> unit

(** Add dependency between modules to the depgraph. *)
val add_dependency :
  t -> Module.t -> Module.DependencyMap.key * Module.location option -> unit

(** Number of modules in the depgraph. *)
val length : t -> int

val map_modules : (string -> Module.t -> 'a) -> t -> 'a list

(** Lookup module in the depgraph by id. *)
val lookup_module : t -> string -> Module.t option

(** Lookup a list of dependencies for the specified module in the depgraph. *)
val lookup_dependencies :
  t -> Module.t -> (Module.DependencyMap.key * Module.t option) list

(** Return a list of modules in the depgraph sorted in a topological order. *)
val sort : t -> Module.t -> Module.t list

(** Get a list of module ids *)
val get_modules : t -> string list

val get_modules_by_filenames: t -> string list -> Module.t list

val cleanup : t -> Set.Make(String).t -> t
