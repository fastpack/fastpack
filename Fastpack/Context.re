type t = {
  config: Config.t,
  current_dir: string,
  project_package: Package.t,
  tmpOutputDir: string,
  entry_location: Module.location,
  current_location: Module.location,
  stack: list(Module.Dependency.t),
  resolver: Resolver.t,
  preprocessor: Preprocessor.t,
  reader: Worker.Reader.t,
  export_finder: ExportFinder.t,
  cache: Cache.t,
  graph: DependencyGraph.t,
};

exception PackError(t, Error.reason);
exception ExitError(string);
exception ExitOK;

let stringOfError = (ctx, error) =>
  Printf.sprintf("\n%s\n", Error.to_string(ctx.current_dir, error));
