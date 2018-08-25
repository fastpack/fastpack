type t = {
  project_root: string,
  current_dir: string,
  project_package: Package.t,
  output_dir: string,
  output_file: string,
  entry_location: Module.location,
  current_location: Module.location,
  stack: list(Module.Dependency.t),
  mode: Mode.t,
  target: Target.t,
  resolver: Resolver.t,
  preprocessor: Preprocessor.t,
  export_finder: ExportFinder.t,
  cache: Cache.t,
  graph: DependencyGraph.t,
};


exception PackError(t, Error.reason);
exception ExitError(string);
exception ExitOK;

let stringOfError = (ctx, error) =>
  Printf.sprintf("\n%s\n", Error.to_string(ctx.current_dir, error));
