type t
type packResult = result(Context.t, Context.t)

let make: (~reporter: option(Reporter.t)=?,Config.t) => Lwt.t(t)
let pack: (
   ~dryRun: bool=?, 
    ~current_location: option(Module.location),
    ~graph: option(DependencyGraph.t),
    ~initial: bool,
    ~start_time: float,
    t
  ) =>
  Lwt.t(packResult);
let finalize: t => Lwt.t(unit);

let getContext: packResult => Context.t;
