type t = {
  config: Config.t,
  current_dir: string,
  project_package: Package.t,
  tmpOutputDir: string,
  entry_location: Module.location,
  resolver: Resolver.t,
  reader: Worker.Reader.t,
  cache: Cache.t,
};


