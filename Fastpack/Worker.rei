
let start: (~project_root: string, ~output_dir: string, unit) => Lwt.t('a);

type ok = {
  source: string,
  static_dependencies: list(Module.Dependency.t),
  dynamic_dependencies: list(Module.Dependency.t),
  module_type: Module.module_type,
  scope: FastpackUtil.Scope.t,
  exports: FastpackUtil.Scope.exports,
  files: list(string),
  build_dependencies: list(string),
};

module Reader: {
  type t;
  let make: (~project_root: string, ~output_dir: string, unit) => t;
  let read:
    (~location: Module.location, ~source: option(string), t)
    => Lwt.t(result(ok, Error.reason));
  let finalize: t => Lwt.t(unit);
}
