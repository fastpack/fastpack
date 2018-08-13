(**
 * Mutable dependency graph.
 *)

type t

exception Cycle of string list

(**
 * Construct an empty depgraph
 *
 * The optional ?size is used as an estimate.
 *)
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

(** Return a sequence of all modules in the depgraph *)
val modules : t -> (string * Module.t) Sequence.t

(** Lookup module in the depgraph by id. *)
val lookup_module : t -> string -> Module.t option

(** Lookup a list of dependencies for the specified module in the depgraph. *)
val lookup_dependencies :
  t -> Module.t -> (Module.DependencyMap.key * Module.t option) list

(** Return all dependencies as a mapping *)
val to_dependency_map : t -> Module.t Module.DependencyMap.t

(** Return a list of modules in the depgraph sorted in a topological order. *)
val sort : t -> Module.t -> Module.t list

(** Return a list of modules which depend on any of filename supplied *)
val get_modules_by_filenames: t -> string list -> Module.t list

(** Remove all modules except those which locations are specified *)
val cleanup : t -> Set.Make(String).t -> t
