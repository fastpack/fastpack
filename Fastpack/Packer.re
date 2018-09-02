module FS = FastpackUtil.FS;

type t = {
  pack:
    (
      ~current_location: option(Module.location),
      ~graph: option(DependencyGraph.t),
      ~initial: bool,
      ~start_time: float
    ) =>
    Lwt.t(result(Context.t, Context.t)),
  finalize: unit => Lwt.t(unit),
};

let make = (~report=None, options: Config.t) => {
  let%lwt current_dir = Lwt_unix.getcwd();

  /* entry points */
  let%lwt entry_points =
    options.entryPoints
    |> Lwt_list.map_p(entry_point => {
         let abs_path = FS.abs_path(current_dir, entry_point);
         switch%lwt (FS.stat_option(abs_path)) {
         | Some({st_kind: Unix.S_REG, _}) =>
           Lwt.return("./" ++ FS.relative_path(current_dir, abs_path))
         | _ => Lwt.return(entry_point)
         };
       });

  let entry_location = Module.Main(entry_points);

  /* output directory & output filename */
  let (output_dir, output_file) = {
    let output_dir = FS.abs_path(current_dir, options.outputDir);
    let output_file = FS.abs_path(output_dir, options.outputFilename);
    let output_file_parent_dir = FilePath.dirname(output_file);
    if (output_dir == output_file_parent_dir
        || FilePath.is_updir(output_dir, output_file_parent_dir)) {
      (output_dir, output_file);
    } else {
      let error =
        "Output filename must be a subpath of output directory.\n"
        ++ "Output directory:\n  "
        ++ output_dir
        ++ "\n"
        ++ "Output filename:\n  "
        ++ output_file
        ++ "\n";

      raise(Context.ExitError(error));
    };
  };

  /* TODO: the next line may not belong here */
  /* TODO: also cleanup the directory before emitting, maybe? */
  let%lwt () = FS.makedirs(output_dir);

  /* project_root */
  let project_root =
    FastpackUtil.FS.abs_path(current_dir, options.projectRootDir);

  /* preprocessor */
  let%lwt preprocessor =
    Preprocessor.make(
      ~configs=options.preprocess,
      ~project_root,
      ~current_dir,
      ~output_dir,
    );

  let%lwt reader = Worker.Reader.make(~project_root, ~output_dir);

  /* cache & cache reporting */
  let%lwt cache = Cache.create(options.cache);
  let cache_report =
    switch (options.cache, cache.starts_empty) {
    | (Config.Cache.Disable, _) => "disabled"
    | (Config.Cache.Use, true) => "empty"
    | (Config.Cache.Use, false) => "used"
    };

  /* main package.json */
  let%lwt (project_package, _) =
    cache.find_package_for_filename(
      current_dir,
      FilePath.concat(current_dir, "package.json"),
    );

  /* make sure resolve extensions all start with '.'*/
  let extensions =
    options.resolveExtension
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
        switch (options.report) {
        | Config.Reporter.JSON => Reporter.JSON
        | Config.Reporter.Text => Reporter.Text
        }
      },
    );
  let pack = (~current_location, ~graph, ~initial, ~start_time) => {
    let message =
      if (initial) {
        Printf.sprintf(
          " Cache: %s. Mode: %s.",
          cache_report,
          Mode.to_string(options.mode),
        );
      } else {
        "";
      };

    let resolver =
      Resolver.make(
        ~project_root,
        ~current_dir,
        ~mock=options.mock,
        ~node_modules_paths=options.nodeModulesPaths,
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
      mode: options.mode,
      target: options.target,
      resolver,
      preprocessor,
      reader,
      export_finder: ExportFinder.make(),
      graph: CCOpt.get_or(~default=DependencyGraph.empty(), graph),
      cache,
    };

    Lwt.catch(
      () => {
        let%lwt () = GraphBuilder.build(ctx);
        let%lwt (emitted_modules, files) =
          switch (options.mode) {
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
        let%lwt () =
          report_ok(~message=Some(message), ~start_time, ~ctx, ~files);
        Lwt.return_ok(ctx);
      },
      fun
      | Context.PackError(ctx, error) => {
          let%lwt () = report_error(~ctx, ~error);
          Lwt.return_error(ctx);
        }
      | exn => raise(exn),
    );
  };
  let finalize = () => {
    let%lwt () = cache.dump();
    let%lwt () = preprocessor.Preprocessor.finalize();
    let%lwt () = reader.Worker.Reader.finalize();
    Lwt.return_unit;
  };
  Lwt.return({pack, finalize});
};
