module FS = FastpackUtil.FS;
module StringSet = Set.Make(String);

type t = {
  pack: packFunction,
  finalize: unit => Lwt.t(unit),
}
and packFunction =
  (
    ~current_location: option(Module.location),
    ~graph: option(DependencyGraph.t),
    ~initial: bool,
    ~start_time: float
  ) =>
  Lwt.t(packResult)
and packResult = result(Context.t, Context.t);

let make = (~report=None, config: Config.t) => {
  let%lwt current_dir = Lwt_unix.getcwd();

  /* entry points */
  let%lwt entry_points =
    config.entryPoints
    |> Lwt_list.map_p(entry_point => {
         let abs_path = FS.abs_path(current_dir, entry_point);
         switch%lwt (FS.stat_option(abs_path)) {
         | Some({st_kind: Unix.S_REG, _}) =>
           Lwt.return("./" ++ FS.relative_path(current_dir, abs_path))
         | _ => Lwt.return(entry_point)
         };
       });

  let entry_location = Module.Main(entry_points);

  /* TODO: the next line may not belong here */
  /* TODO: also cleanup the directory before emitting, maybe? */
  let%lwt () = FS.makedirs(config.outputDir);

  /* TODO: verify is project_root exists */

  /* FIXME: rename later */
  let output_dir = config.outputDir;
  let project_root = config.projectRootDir;
  let output_file = config.outputFilename;

  /* preprocessor */
  let%lwt preprocessor =
    Preprocessor.make(
      ~configs=config.preprocess,
      ~project_root,
      ~current_dir,
      ~output_dir,
    );

  let%lwt reader = Worker.Reader.make(~project_root, ~output_dir);

  /* cache & cache reporting */
  let%lwt cache =
    Cache.create(
      switch (config.cache) {
      | Config.Cache.Disable => Cache.Memory
      | Config.Cache.Use =>
        Cache.(
          Persistent({
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
    switch (config.cache, cache.starts_empty) {
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
        if%lwt (FSCache.exists(package_json, cache.files)) {
          Lwt.return_some(package_json);
        } else {
          find_package_json_for_filename(dirname);
        };
      };

    switch%lwt (find_package_json_for_filename(filename)) {
    | Some(package_json) =>
      let%lwt content = FSCache.readExisting(package_json, cache.files);
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

  /* make sure resolve extensions all start with '.'*/
  let extensions =
    config.resolveExtension
    |> List.filter(ext => String.trim(ext) != "")
    |> List.map(ext =>
         switch (ext.[0]) {
         | '.' => ext
         | _ => "." ++ ext
         }
       );

  let {Reporter.report_ok, report_error} =
    Reporter.make(
      switch (report) {
      | Some(report) => report
      | None =>
        switch (config.report) {
        | Config.Reporter.JSON => Reporter.JSON
        | Config.Reporter.Text => Reporter.Text
        }
      },
    );

  let rec pack = (~current_location, ~graph, ~initial, ~start_time) => {
    let message =
      if (initial) {
        Printf.sprintf(
          " Cache: %s. Mode: %s.",
          cache_report,
          Mode.to_string(config.mode),
        );
      } else {
        "";
      };

    let resolver =
      Resolver.make(
        ~project_root,
        ~current_dir,
        ~mock=config.mock,
        ~node_modules_paths=config.nodeModulesPaths,
        ~extensions,
        ~preprocessor,
        ~cache,
      );

    let ctx = {
      Context.project_root,
      current_dir,
      project_package,
      output_dir,
      output_file,
      entry_location,
      current_location:
        CCOpt.get_or(~default=entry_location, current_location),
      stack: [],
      mode: config.mode,
      target: config.target,
      resolver,
      preprocessor,
      reader,
      export_finder: ExportFinder.make(),
      graph: CCOpt.get_or(~default=DependencyGraph.empty(), graph),
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
        let%lwt (emitted_modules, files) =
          switch (config.mode) {
          | Mode.Production =>
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
          | Mode.Test
          | Mode.Development => ScopedEmitter.emit(ctx, start_time)
          };
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
          report_ok(~message=Some(message), ~start_time, ~ctx, ~files);
        Lwt.return_ok(ctx);
      },
      fun
      | GraphBuilder.Rebuild(filename, location) => {
          FSCache.invalidate(filename, ctx.cache.files);
          Module.LocationSet.iter(
            location => ctx.cache.remove_module(location),
            DependencyGraph.get_module_parents(ctx.graph, location),
          );
          pack(~current_location=None, ~graph=None, ~initial, ~start_time);
        }
      | Context.PackError(ctx, error) => {
          let%lwt () = report_error(~ctx, ~error);
          Lwt.return_error(ctx);
        }
      | exn => Lwt.fail(exn),
    );
  };
  let finalize = () => {
    let%lwt () = preprocessor.Preprocessor.finalize();
    let%lwt () = reader.Worker.Reader.finalize();
    Lwt.return_unit;
  };
  Lwt.return({pack, finalize});
};

let getContext = result =>
  switch (result) {
  | Ok(ctx) => ctx
  | Error(ctx) => ctx
  };
