module FS = FastpackUtil.FS;
module StringSet = Set.Make(CCString);

type t = {
  current_dir: string,
  tmpOutputDir: string,
  config: Config.t,
  entry_location: Module.location,
  reader: Worker.Reader.t,
  cache: Cache.t,
  cache_report: string,
  project_package: Package.t,
  reporter: Reporter.t,
};
type packResult = result(Context.t, Context.t);

let make = (~reporter=None, config: Config.t) => {
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
  let cache_report =
    switch (config.cache, Cache.isLoadedEmpty(cache)) {
    | (Config.Cache.Disable, _) => "disabled"
    | (Config.Cache.Use, true) => "empty"
    | (Config.Cache.Use, false) => "used"
    };

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

  let reporter =
    switch (reporter) {
    | Some(reporter) => reporter
    | None =>
      switch (config.report) {
      | Config.Reporter.JSON => Reporter.JSON.make()
      | Config.Reporter.Text => Reporter.Text.make()
      }
    };

  Lwt.return({
    current_dir,
    tmpOutputDir,
    config,
    entry_location,
    reader,
    cache,
    cache_report,
    project_package,
    reporter,
  });
};

let rec pack =
        (
          ~dryRun=false,
          ~current_location,
          ~graph,
          ~initial,
          ~start_time,
          packer,
        ) => {
  let {current_dir, tmpOutputDir, config, cache, _} = packer;
  let message =
    if (initial) {
      Printf.sprintf(
        " Cache: %s. Mode: %s.",
        packer.cache_report,
        Mode.to_string(packer.config.mode),
      );
    } else {
      "";
    };

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
    project_package: packer.project_package,
    tmpOutputDir,
    entry_location: packer.entry_location,
    current_location:
      CCOpt.get_or(~default=packer.entry_location, current_location),
    resolver,
    reader: packer.reader,
    graph:
      switch (graph) {
      | None => DependencyGraph.empty()
      | Some(graph) => graph
      },
    cache,
  };

  Lwt.catch(
    () => {
      Logs.debug(x =>
        x("before build. Graph: %d", DependencyGraph.length(ctx.graph))
      );
      let%lwt () = GraphBuilder.build(ctx);
      Logs.debug(x =>
        x("after build. Graph: %d", DependencyGraph.length(ctx.graph))
      );

      let emit =
        switch (dryRun, config.mode) {
        | (_, Mode.Production) =>
          raise(
            Context.PackError(
              ctx,
              NotImplemented(
                None,
                "Production build is not implemented yet"
                ++ "\nUse `--development` for now",
              ),
            ),
          )
        | (true, _) => ScopedEmitter.update_graph
        | (false, _) => ScopedEmitter.emit
        };
      let%lwt (emitted_modules, files) = emit(ctx, start_time);
      let ctx = {
        ...ctx,
        graph: DependencyGraph.cleanup(ctx.graph, emitted_modules),
      };
      Logs.debug(x =>
        x("after cleanup. Graph: %d", DependencyGraph.length(ctx.graph))
      );
      Logs.debug(x =>
        x(
          "after-cleanup-files: %d",
          StringSet.elements(DependencyGraph.get_files(ctx.graph))
          |> List.length,
        )
      );
      let%lwt () =
        Reporter.reportOk(
          ~message=Some(message),
          ~start_time,
          ~ctx,
          ~files,
          packer.reporter,
        );
      Lwt.return_ok(ctx);
    },
    fun
    | GraphBuilder.Rebuild(filename, location) => {
        Cache.File.invalidate(filename, ctx.cache);
        Module.LocationSet.iter(
          location => Cache.removeModule(location, ctx.cache),
          DependencyGraph.get_module_parents(ctx.graph, location),
        );
        pack(
          ~dryRun,
          ~current_location=None,
          ~graph=None,
          ~initial,
          ~start_time,
          packer,
        );
      }
    | Context.PackError(ctx, error) => {
        let%lwt () = Reporter.reportError(~ctx, ~error, packer.reporter);
        Lwt.return_error(ctx);
      }
    | exn => Lwt.fail(exn),
  );
};

let finalize = packer => {
  let {reader, _} = packer;
  let%lwt () = Worker.Reader.finalize(reader);
  Lwt.return_unit;
};

let getContext = result =>
  switch (result) {
  | Ok(ctx) => ctx
  | Error(ctx) => ctx
  };
