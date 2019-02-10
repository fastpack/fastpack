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
    config.entryPoints
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

  let%lwt tmpOutputDir = FS.makeTempDir(Filename.dirname(config.outputDir));

  let reader =
    Worker.Reader.make(
      ~project_root=config.projectRootDir,
      ~output_dir=tmpOutputDir,
      ~publicPath=config.publicPath,
      (),
    );

  /* cache & cache reporting */
  let%lwt cache =
    Cache.make(
      switch (config.cache) {
      | Config.Cache.Disable => Cache.Empty
      | Config.Cache.Use =>
        Cache.(
          Load({
            currentDir: current_dir,
            projectRootDir: config.projectRootDir,
            mock: config.mock,
            nodeModulesPaths: config.nodeModulesPaths,
            resolveExtension: config.resolveExtension,
            preprocess: config.preprocess,
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

let rec build =
        (~dryRun=false, ~filesWatched=StringSet.empty, ~prevRun=None, builder) => {
  let {current_dir, tmpOutputDir, config, cache, _} = builder;

  let resolver =
    Resolver.make(
      ~project_root=config.projectRootDir,
      ~current_dir,
      ~mock=config.mock,
      ~node_modules_paths=config.nodeModulesPaths,
      ~extensions=config.resolveExtension,
      ~preprocessors=config.preprocess,
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
    current_location:
      switch (prevRun) {
      | None => builder.entry_location
      | Some({startLocation, _}) => startLocation
      },
    resolver,
    reader: builder.reader,
    cache,
  };

  let graph =
    switch (prevRun) {
    | None => DependencyGraph.empty()
    | Some({bundle, _}) => bundle.Bundle.graph
    };

  Lwt.catch(
    () => {
      if (config.mode == Mode.Production) {
        raise(
          Context.PackError(
            ctx,
            NotImplemented(
              None,
              "Production build is not implemented yet"
              ++ "\nUse `--development` for now",
            ),
          ),
        );
      };
      let%lwt () = DependencyGraph.build(ctx, graph);
      let%lwt exportFinder = ExportFinder.make(graph);
      let%lwt () =
        DependencyGraph.iterModules(graph, (m: Module.t) =>
          switch (ExportFinder.ensure_exports(m, exportFinder)) {
          | Some((m, name)) =>
            let location_str =
              Module.location_to_string(
                ~base_dir=Some(ctx.current_dir),
                m.location,
              );

            Lwt.fail(
              Context.PackError(
                ctx,
                CannotFindExportedName(name, location_str),
              ),
            );
          | None => Lwt.return_unit
          }
        );
      let%lwt bundle = Bundle.make(graph, ctx.entry_location);
      let%lwt () =
        dryRun ? FS.rmdir(tmpOutputDir) : Bundle.emit(ctx, bundle);
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
    | Context.PackError(_, reason) => {
        let filesWatched =
          StringSet.union(
            DependencyGraph.get_files(graph),
            filesWatched,
          );
        Lwt.return_error({filesWatched, reason});
      }
    | exn => Lwt.fail(exn),
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
    /* StringSet.iter( */
    /*   f => Cache.File.invalidate(f, builder.cache), */
    /*   filesChanged, */
    /* ); */
    let filesWatched =
      switch (prevResult) {
      | Ok(bundle) => DependencyGraph.get_files(bundle.Bundle.graph)
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
            bundle.Bundle.graph,
            filesMatched,
          )
          |> Module.LocationSet.elements
        ) {
        | [] => (false, None)
        | [location] =>
          DependencyGraph.remove_module(bundle.Bundle.graph, location);
          (true, Some({bundle, startLocation: location}));
        | _ => (true, None)
        }
      };
    run ? build(~filesWatched, ~prevRun, builder) : Lwt.return(prevResult);
  };

let getFilenameFilter = (builder: t) => {
  let {config, tmpOutputDir, _} = builder;
  filename =>
    !FilePath.is_subdir(filename, config.outputDir)
    && !FilePath.is_subdir(filename, tmpOutputDir)
    && filename != tmpOutputDir
    && filename != config.outputDir;
};

let finalize = packer => {
  let {reader, _} = packer;
  let%lwt () = Worker.Reader.finalize(reader);
  Lwt.return_unit;
};