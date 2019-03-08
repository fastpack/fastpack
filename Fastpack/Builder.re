module FS = FastpackUtil.FS;
module StringSet = Set.Make(CCString);

type t = {
  current_dir: string,
  tmpOutputDir: string,
  config: Config.t,
  entry_location: Module.location,
  reader: Worker.Reader.t,
  cache: Cache.t,
  project_package: Package.t,
};

type buildResult = result(Bundle.t, error)
and error = {
  reason: Error.reason,
  filesWatched: StringSet.t,
};

let make = (config: Config.t) => {
  let%lwt current_dir = Lwt_unix.getcwd();

  /* entry points */
  let%lwt entry_points =
    Config.entryPoints(config)
    |> Lwt_list.map_p(entry_point => {
         let abs_path = FS.abs_path(current_dir, entry_point);
         switch%lwt (FS.stat_option(abs_path)) {
         | Some({st_kind: Unix.S_REG, _}) =>
           Lwt.return(
             "./"
             ++ FS.relative_path(current_dir, abs_path)
             |> CCString.replace(~sub="\\", ~by="/"),
           )
         | _ => Lwt.return(entry_point)
         };
       });

  let entry_location = Module.Main(entry_points);

  let%lwt tmpOutputDir = FS.makeTempDir(Filename.dirname(Config.outputDir(config)));

  let reader =
    Worker.Reader.make(
      ~project_root=Config.projectRootDir(config),
      ~output_dir=tmpOutputDir,
      ~publicPath=Config.publicPath(config),
      (),
    );

  /* cache & cache reporting */
  let%lwt cache =
    Cache.make(
      switch (Config.isCacheDisabled(config)) {
      | true => Cache.Empty
      | false =>
        Cache.(
          Load({
            currentDir: current_dir,
            projectRootDir: Config.projectRootDir(config),
            mock: Config.mock(config),
            nodeModulesPaths: Config.nodeModulesPaths(config),
            resolveExtension: Config.resolveExtension(config),
            preprocess: Config.preprocess(config),
          })
        )
      },
    );

  let find_package_for_filename = (cache: Cache.t, root_dir, filename) => {
    let rec find_package_json_for_filename = filename =>
      if (!FilePath.is_subdir(filename, root_dir)) {
        Lwt.return_none;
      } else {
        let dirname = FilePath.dirname(filename);
        let package_json = FilePath.concat(dirname, "package.json");
        if%lwt (Cache.File.exists(package_json, cache)) {
          Lwt.return_some(package_json);
        } else {
          find_package_json_for_filename(dirname);
        };
      };

    switch%lwt (find_package_json_for_filename(filename)) {
    | Some(package_json) =>
      let%lwt content = Cache.File.readExisting(package_json, cache);
      Lwt.return(Package.of_json(package_json, content));
    | None => Lwt.return(Package.empty)
    };
  };

  /* main package.json */
  let%lwt project_package =
    find_package_for_filename(
      cache,
      current_dir,
      FilePath.concat(current_dir, "package.json"),
    );
  Lwt.return({
    current_dir,
    tmpOutputDir,
    config,
    entry_location,
    reader,
    cache,
    project_package,
  });
};

type prevRun = {
  bundle: Bundle.t,
  startLocation: Module.location,
};

let buildAll = (~dryRun: bool, ~ctx: Context.t, ~graph, startLocation) => {
  let t = Unix.gettimeofday();
  let%lwt () = DependencyGraph.build(ctx, startLocation, graph);
  Logs.debug(x => x("Graph built: %.3f", Unix.gettimeofday() -. t));
  let%lwt exportFinder = ExportFinder.make(graph);
  let%lwt () =
    DependencyGraph.iterModules(graph, (source: Module.t) =>
      switch (ExportFinder.ensure_exports(source, exportFinder)) {
      | Some((m, name)) =>
        let location_str =
          Module.location_to_string(
            ~base_dir=Some(ctx.current_dir),
            m.location,
          );

        Lwt.fail(
          Error.PackError(
            CannotFindExportedName(
              Module.location_to_string(source.location),
              name,
              location_str,
            ),
          ),
        );
      | None => Lwt.return_unit
      }
    );
  let%lwt bundle = Bundle.make(graph, ctx.entry_location);
  let%lwt () =
    dryRun ? FS.rmdir(ctx.tmpOutputDir) : Bundle.emit(ctx, bundle);
  Lwt.return(bundle);
};

let buildOne = (ctx: Context.t) => {
  let request =
    switch (ctx.entry_location) {
    | Module.Main([entry]) => entry
    | _ => failwith("one entry point is expected")
    };
  let%lwt (location, _) =
    DependencyGraph.resolve(
      ctx,
      {Module.Dependency.request, requested_from: ctx.entry_location},
    );
  print_endline(request);
  print_endline(Module.location_to_string(location));
  let source = ref(None);
  let result = ref(None);

  let worker =
    Worker.(
      make(
        ~init=
          () =>
            Lwt.return(
              makeInit(
                ~project_root=Config.projectRootDir(ctx.config),
                ~output_dir=ctx.tmpOutputDir,
                ~publicPath=Config.publicPath(ctx.config),
                (),
              ),
            ),
        ~input=() => Lwt.return(makeRequest(~location, ~source=source^, ())),
        ~output=
          response => {
            let%lwt result' =
              Worker.Reader.responseToResult(
                ~location,
                ~source=source^,
                response,
              );
            result := Some(result');
            Lwt.return_unit;
          },
        ~serveForever=false,
        (),
      )
    );

  let read = (_location, source') => {
    source := source';
    let%lwt () = Worker.start(worker);
    switch (result^) {
    | Some(result) => Lwt.return(result)
    | None => failwith("Didn't collect result")
    };
  };

  let bundle = Bundle.empty();
  let%lwt (m, _) =
    DependencyGraph.read_module(
      ~ctx,
      ~read,
      ~graph=Bundle.getGraph(bundle),
      location,
    );
  print_endline(m.id);

  Lwt.return(bundle);
};

let rec build =
        (
          ~one=false,
          ~dryRun=false,
          ~filesWatched=StringSet.empty,
          ~prevRun=None,
          builder,
        ) => {
  let {current_dir, tmpOutputDir, config, cache, _} = builder;

  let resolver =
    Resolver.make(
      ~project_root=Config.projectRootDir(config),
      ~current_dir,
      ~mock=Config.mock(config),
      ~node_modules_paths=Config.nodeModulesPaths(config),
      ~extensions=Config.resolveExtension(config),
      ~preprocessors=Config.preprocess(config),
      ~cache,
      (),
    );

  let%lwt () = FS.makedirs(tmpOutputDir);
  let ctx = {
    Context.config,
    current_dir,
    project_package: builder.project_package,
    tmpOutputDir,
    entry_location: builder.entry_location,
    resolver,
    reader: builder.reader,
    cache,
  };

  let graph =
    switch (prevRun) {
    | None => DependencyGraph.empty()
    | Some({bundle, _}) => Bundle.getGraph(bundle)
    };

  let startLocation =
    switch (prevRun) {
    | None => builder.entry_location
    | Some({startLocation, _}) => startLocation
    };

  Lwt.catch(
    () => {
      if (Config.mode(config) == Mode.Production) {
        raise(
          Error.PackError(
            NotImplemented(
              "Production build is not implemented yet"
              ++ "\nUse `--development` for now",
            ),
          ),
        );
      };
      let%lwt bundle =
        one ? buildOne(ctx) : buildAll(~dryRun, ~ctx, ~graph, startLocation);
      Lwt.return_ok(bundle);
    },
    fun
    | DependencyGraph.Rebuild(filename, location) => {
        let%lwt () = Cache.File.invalidate(filename, builder.cache);
        Module.LocationSet.iter(
          location => Cache.removeModule(location, builder.cache),
          DependencyGraph.get_module_parents(graph, location),
        );
        build(~filesWatched, builder);
      }
    | Error.PackError(reason) => {
        let%lwt () = FS.rmdir(tmpOutputDir);
        let filesWatched =
          StringSet.union(DependencyGraph.get_files(graph), filesWatched);
        Lwt.return_error({filesWatched, reason});
      }
    | exn => {
        let%lwt () = FS.rmdir(tmpOutputDir);
        Lwt.fail(exn);
      },
  );
};

let shouldRebuild = (~filesChanged, ~prevResult, builder: t) =>
  switch (StringSet.elements(filesChanged)) {
  | [] => Lwt.return_none
  | _ =>
    let%lwt () =
      Lwt_list.iter_s(
        f => Cache.File.invalidate(f, builder.cache),
        StringSet.elements(filesChanged),
      );
    let filesWatched =
      switch (prevResult) {
      | Ok(bundle) => bundle |> Bundle.getGraph |> DependencyGraph.get_files
      | Error({filesWatched, _}) => filesWatched
      };
    switch (StringSet.(inter(filesChanged, filesWatched) |> elements)) {
    | [] => Lwt.return_none
    | filesMatched => Lwt.return_some((filesWatched, filesMatched))
    };
  };

/* TODO: refactor to not call shouldRebuild twice */
let rebuild = (~filesChanged, ~prevResult, builder) =>
  switch%lwt (shouldRebuild(~filesChanged, ~prevResult, builder)) {
  | None => Lwt.return(prevResult)
  | Some((filesWatched, filesMatched)) =>
    let (run, prevRun) =
      switch (prevResult) {
      | Error(_) => (true, None)
      | Ok(bundle) =>
        switch (
          DependencyGraph.get_changed_module_locations(
            Bundle.getGraph(bundle),
            filesMatched,
          )
          |> Module.LocationSet.elements
        ) {
        | [] => (false, None)
        | [location] =>
          DependencyGraph.remove_module(Bundle.getGraph(bundle), location);
          (true, Some({bundle, startLocation: location}));
        | _ => (true, None)
        }
      };
    run ? build(~filesWatched, ~prevRun, builder) : Lwt.return(prevResult);
  };

let getFilenameFilter = (builder: t) => {
  let {config, tmpOutputDir, cache, _} = builder;
  let inCacheDir =
    switch (Cache.getFilename(cache)) {
    | Some(filename) =>
      let cacheDir = FilePath.dirname(filename);
      (
        filename =>
          FilePath.is_subdir(filename, cacheDir) || filename == cacheDir
      );
    | None => (_ => false)
    };
  let outputDir = Config.outputDir(config);
  filename =>
    !FilePath.is_subdir(filename, outputDir)
    && !FilePath.is_subdir(filename, tmpOutputDir)
    && filename != tmpOutputDir
    && filename != outputDir
    && !inCacheDir(filename);
};

let finalize = ({reader, _}) => {
  let%lwt () = Worker.Reader.finalize(reader);
  Lwt.return_unit;
};
