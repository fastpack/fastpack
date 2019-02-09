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

type buildResult = result(ScopedEmitter.Bundle.t, error)
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

let rec build = (~dryRun=false, ~bundle=None, ~startLocation=None, builder) => {
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
      CCOpt.get_or(~default=builder.entry_location, startLocation),
    resolver,
    reader: builder.reader,
    graph:
      switch (bundle) {
      | None => DependencyGraph.empty()
      | Some(bundle) => bundle.ScopedEmitter.Bundle.graph
      },
    cache,
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
      let%lwt () = GraphBuilder.build(ctx);
      let%lwt exportFinder = ExportFinder.make(ctx.graph);
      let%lwt () =
        DependencyGraph.iterModules(ctx.graph, (m: Module.t) =>
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
      let%lwt bundle =
        ScopedEmitter.Bundle.make(ctx.graph, ctx.entry_location);
      let%lwt () =
        dryRun ?
          FS.rmdir(tmpOutputDir) : ScopedEmitter.Bundle.emit(ctx, bundle);
      Lwt.return_ok(bundle);
    },
    fun
    | GraphBuilder.Rebuild(filename, location) => {
        Cache.File.invalidate(filename, ctx.cache);
        Module.LocationSet.iter(
          location => Cache.removeModule(location, ctx.cache),
          DependencyGraph.get_module_parents(ctx.graph, location),
        );
        build(builder);
      }
    | Context.PackError(ctx, reason) => {
        let filesWatched = DependencyGraph.get_files(ctx.graph);
        Lwt.return_error({filesWatched, reason});
      }
    | exn => Lwt.fail(exn),
  );
};

let rebuild = (~filesChanged, ~prevResult, builder) =>
  switch (StringSet.elements(filesChanged)) {
  | [] => Lwt.return(prevResult)
  | _ =>
    StringSet.iter(
      f => Cache.File.invalidate(f, builder.cache),
      filesChanged,
    );
    let filesWatched =
      switch (prevResult) {
      | Ok(bundle) =>
        DependencyGraph.get_files(bundle.ScopedEmitter.Bundle.graph)
      | Error({filesWatched, _}) => filesWatched
      };
    switch (StringSet.(inter(filesChanged, filesWatched) |> elements)) {
    | [] => Lwt.return(prevResult)
    | filesMatched =>
      let (run, bundle, startLocation) =
        switch (prevResult) {
        | Error(_) => (true, None, None)
        | Ok(bundle) =>
          switch (
            DependencyGraph.get_changed_module_locations(
              bundle.ScopedEmitter.Bundle.graph,
              filesMatched,
            )
            |> Module.LocationSet.elements
          ) {
          | [] => (false, None, None)
          | [location] =>
            DependencyGraph.remove_module(
              bundle.ScopedEmitter.Bundle.graph,
              location,
            );
            (true, Some(bundle), Some(location));
          | _ => (true, None, None)
          }
        };
      run ? build(~bundle, ~startLocation, builder) : Lwt.return(prevResult);
    };
  };

let finalize = packer => {
  let {reader, _} = packer;
  let%lwt () = Worker.Reader.finalize(reader);
  Lwt.return_unit;
};
