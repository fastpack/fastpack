type packResult = result(Context.t, Context.t)
type packFunction =
  (
    ~current_location: option(Module.location),
    ~graph: option(DependencyGraph.t),
    ~initial: bool,
    ~start_time: float
  ) =>
  Lwt.t(packResult)
type t = {
  pack: packFunction,
  finalize: unit => Lwt.t(unit),
}

let make: (~report: option(Reporter.report)=?, Config.t) => Lwt.t(t)
let getContext: packResult => Context.t
