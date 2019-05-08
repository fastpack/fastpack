
type t
type file = {
  absPath: string,
  relPath: string,
  size: int,
}

let empty: unit => t;
let make: (DependencyGraph.t, Module.location) => t;
let emit: (Context.t, t) => Lwt.t(unit);
let getGraph: t => DependencyGraph.t;
let getFiles: t => list(file);
let getTotalSize: t => int;
let getWarnings: t => option(string);
