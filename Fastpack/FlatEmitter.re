module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
module FS = FastpackUtil.FS;

let emit_module_files = (ctx: Context.t, m: Module.t) =>
  Lwt_list.iter_s(
    ((filename, content)) => {
      let path = FS.abs_path(ctx.output_dir, filename);
      let%lwt () = FS.makedirs(FilePath.dirname(path));
      Lwt_io.(
        with_file(
          ~mode=Lwt_io.Output,
          ~perm=0o640,
          ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
          path,
          ch =>
          write(ch, content)
        )
      );
    },
    m.files,
  );

let run = (ctx: Context.t, _output_channel) => {
  let {Context.entry_location, graph, _} = ctx;
  let get_module_content = (m: Module.t) =>
    /* TODO: make sure m.workspace.Workspace.patches is empty */
    switch (
      Yojson.Safe.from_string("\"" ++ m.workspace.Workspace.value ++ "\"")
    ) {
    | `String(s) => s
    | _ => failwith("unexpected module content")
    };

  let emit_static_chain = entry_module => {
    let chain =
      try (DependencyGraph.get_static_chain(graph, entry_module)) {
      | DependencyGraph.Cycle(filenames) =>
        raise(Context.PackError((ctx, DependencyCycle(filenames))))
      };

    let%lwt () =
      Lwt_list.iter_s(
        m => {
          print_endline("// ---" ++ m.Module.id);
          print_endline(get_module_content(m));
          print_endline("// ------------------------");
          List.iter(
            ((_, location)) =>
              print_endline(Module.location_to_string(location)),
            m.Module.dynamic_dependencies,
          );
          print_endline("// ------------------------");
          Lwt.return_unit;
        },
        chain,
      );

    Lwt.return_unit;
  };

  let entry_module =
    switch (DependencyGraph.lookup_module(graph, entry_location)) {
    | Some(m) => m
    | None =>
      Error.ie(
        Module.location_to_string(entry_location) ++ " not found in the graph",
      )
    };

  let%lwt () = emit_static_chain(entry_module);
  Lwt.return((Module.LocationSet.empty, 0));
};

let emit = (ctx: Context.t) => {
  let temp_file =
    Filename.temp_file(~temp_dir=ctx.output_dir, ".fpack", ".bundle.js");

  Lwt.finalize(
    () => {
      let%lwt (emitted_modules, size) =
        Lwt_io.with_file(
          ~mode=Lwt_io.Output,
          ~perm=0o640,
          ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
          temp_file,
          run(ctx),
        );

      let%lwt () = Lwt_unix.rename(temp_file, ctx.output_file);
      Lwt.return((
        emitted_modules,
        [{Reporter.name: ctx.output_file, size}],
      ));
    },
    () =>
      if%lwt (Lwt_unix.file_exists(temp_file)) {
        Lwt_unix.unlink(temp_file);
      },
  );
};
