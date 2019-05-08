/**
 * Mutable dependency graph.
 */;

type t;

exception Cycle(list(string));
exception Rebuild(string, Module.location);

/**
 * Construct an empty depgraph
 *
 * The optional ?size is used as an estimate.
 */

let empty: (~size: int=?, unit) => t;

/** Add module to the depgraph. */

/* let add_module: (t, Module.location, Lazy.t(Lwt.t(Module.t)) => unit; */
let add_module_parents: (t, Module.location, Module.LocationSet.t) => unit;
let get_module_parents: (t, Module.location) => Module.LocationSet.t;
/* let ensureModule: (t, Module.location, unit => Lwt.t(Module.t)) => Lwt.t(Module.t) */

let add_build_dependencies: (t, list(string), Module.location) => unit;



/** Remove module from the depgraph. */

let remove_module: (t, Module.location) => unit;

/** Number of modules in the depgraph. */

let length: t => int;

/** Return a sequence of all modules in the depgraph */

let modules: t => Sequence.t((Module.location, Module.t));

let iterModules: (t, Module.t => unit) => unit;
let foldModules: (t, ('a, Module.t) => 'a, 'a) => 'a;

/** Lookup module in the depgraph by id. */

let lookup_module: (t, Module.location) => option(Module.t);
/* let hasModule: (t, Module.location) => bool; */

/** Lookup a list of dependencies for the specified module in the depgraph. */

let lookup_dependencies:
  (~kind: [ `All | `Dynamic | `Static ], t, Module.t) =>
  Sequence.t((Module.Dependency.t, Module.t))

/** Return all dependencies as a mapping */

let to_dependency_map: t => Module.DependencyMap.t(Module.t);

/** Return a list of modules in the depgraph sorted in a topological order
  * starting with the initial module provided.
  * This only conciders static dependencies */

/* let get_static_chain: (t, Module.t) => list(Module.t); */

let get_files: t => Set.Make(CCString).t;

/** Return a list of modules which depend on any of filename supplied */

let get_changed_module_locations: (t, list(string)) => Module.LocationSet.t;

/** Remove all modules except those which locations are specified */

let cleanup: (t, Module.LocationSet.t) => t;


let build: (Context.t, Module.location, t) => Lwt.t(unit)
let resolve: (Context.t, Module.Dependency.t) => Lwt.t((Module.location, list(string)))



type dependencies =
  | NoDependendencies
  | Dependencies(list(Module.Dependency.t), list(Module.Dependency.t));
let read_module:
  (~ctx: Context.t,
   ~read: (Module.location, option(string)) => Lwt.t(result(Worker.ok, Error.reason)),
   ~graph: t,
   Module.location)
   => Lwt.t((Module.t, dependencies))


