/**
 * Mutable dependency graph.
 */;

type t;

exception Cycle(list(string));

/**
 * Construct an empty depgraph
 *
 * The optional ?size is used as an estimate.
 */

let empty: (~size: int=?, unit) => t;

/** Add module to the depgraph. */

let add_module: (t, Module.location, Lwt.t(Module.t)) => Lwt.t(Module.t);

let add_build_dependencies: (t, list(string), Module.location) => unit;



/** Remove module from the depgraph. */

let remove_module: (t, Module.location) => unit;

/** Add dependency between modules to the depgraph. */

let add_dependency:
  (
    ~kind: [< | `Dynamic | `Static],
    t,
    Module.t,
    (Module.DependencyMap.key, Module.location)
  ) =>
  unit;

/** Number of modules in the depgraph. */

let length: t => int;

/** Return a sequence of all modules in the depgraph */

let modules: t => Sequence.t((Module.location, Lwt.t(Module.t)));

/** Lookup module in the depgraph by id. */

let lookup_module: (t, Module.location) => option(Lwt.t(Module.t));

/** Lookup a list of dependencies for the specified module in the depgraph. */

let lookup_dependencies:
  (~kind: [< | `All | `Dynamic | `Static], t, Module.t) =>
  list((Module.DependencyMap.key, option(Lwt.t(Module.t))));

/** Return all dependencies as a mapping */

let to_dependency_map: t => Lwt.t(Module.DependencyMap.t(Module.t));

/** Return a list of modules in the depgraph sorted in a topological order
  * starting with the initial module provided.
  * This only conciders static dependencies */

/* let get_static_chain: (t, Module.t) => list(Module.t); */

let get_files: t => Set.Make(String).t;

/** Return a list of modules which depend on any of filename supplied */

let get_changed_module_locations: (t, list(string)) => Module.LocationSet.t;

/** Remove all modules except those which locations are specified */

let cleanup: (t, Module.LocationSet.t) => t;
