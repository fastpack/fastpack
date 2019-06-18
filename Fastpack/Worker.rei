type t
type init
type request
type response

let make: (
  ~init: unit => Lwt.t(init),
  ~input: unit => Lwt.t(request),
  ~output: response => Lwt.t(unit),
  ~serveForever: bool,
  unit) => t;


let makeInit: (
  ~envVar: CCMap.Make(String).t(string),
  ~project_root: string,
  ~output_dir: string,
  ~publicPath: string,
  unit) => init;
let initFromParent: unit => Lwt.t(init);

let makeRequest: (~location: Module.location, ~source: option(string), unit) => request
let inputFromParent: unit => Lwt.t(request);

let outputToString: response => string
let outputToParent: response => Lwt.t(unit);

let start: t => Lwt.t(unit);

type ok = {
  source: string,
  static_dependencies: list(Module.Dependency.t),
  dynamic_dependencies: list(Module.Dependency.t),
  module_type: Module.module_type,
  scope: FastpackUtil.Scope.t,
  exports: FastpackUtil.Scope.exports,
  usedImports: FastpackUtil.Scope.ImportSet.t,
  warnings: list(string),
  files: list(string),
  build_dependencies: list(string),
};

module Reader: {
  type t;
  let make: (
    ~envVar: CCMap.Make(String).t(string),
    ~project_root: string,
    ~output_dir: string,
    ~publicPath: string,
    unit) => t;
  let read:
    (~location: Module.location, ~source: option(string), t)
    => Lwt.t(result(ok, Error.reason));
  let finalize: t => Lwt.t(unit);

  let responseToResult: (~location: Module.location, ~source: option(string), response) =>
Lwt.t(result(ok, Error.reason))

}
