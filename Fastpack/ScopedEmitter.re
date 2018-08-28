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

let to_eval = s => {
  let json = Yojson.to_string(`String(s));
  String.(sub(json, 1, length(json) - 2));
};

let run = (start_time, ctx: Context.t, output_channel) => {
  /* emit required runtime */
  let emit_runtime = (out, prefix, entry_id) =>
    Lwt_io.write(out) @@
    Printf.sprintf(
      "\n// This function is a modified version of the one created by the Webpack project\nglobal = window;\nprocess = { env: {} };\n%s(function(modules) {\n  // The module cache\n  var installedModules = {};\n\n  // The require function\n  function __fastpack_require__(moduleId) {\n\n    // Check if module is in cache\n    if(installedModules[moduleId]) {\n      return installedModules[moduleId].exports;\n    }\n    // Create a new module (and put it into the cache)\n    var module = installedModules[moduleId] = {\n      id: moduleId,\n      l: false,\n      exports: {}\n    };\n\n    // Execute the module function\n    modules[moduleId].call(\n      module.exports,\n      module,\n      module.exports,\n      __fastpack_require__,\n      __fastpack_import__\n    );\n\n    // Flag the module as loaded\n    module.l = true;\n\n    // Return the exports of the module\n    return module.exports;\n  }\n\n  function __fastpack_import__(moduleId) {\n    if (!window.Promise) {\n      throw 'window.Promise is undefined, consider using a polyfill';\n    }\n    return new Promise(function(resolve, reject) {\n      try {\n        resolve(__fastpack_require__(moduleId));\n      } catch (e) {\n        reject(e);\n      }\n    });\n  }\n\n  __fastpack_require__.m = modules;\n  __fastpack_require__.c = installedModules;\n  __fastpack_require__.omitDefault = function(moduleVar) {\n    var keys = Object.keys(moduleVar);\n    var ret = {};\n    for(var i = 0, l = keys.length; i < l; i++) {\n      var key = keys[i];\n      if (key !== 'default') {\n        ret[key] = moduleVar[key];\n      }\n    }\n    return ret;\n  }\n  return __fastpack_require__(__fastpack_require__.s = '%s');\n})\n",
      prefix,
      entry_id,
    );

  let emitted_modules = ref(MLSet.empty);
  let emit = (graph, entry) => {
    let emit = bytes => Lwt_io.write(output_channel, bytes);
    let%lwt dep_map = DependencyGraph.to_dependency_map(graph);
    let rec emit_module = (m: Module.t) =>
      if (MLSet.mem(m.location, emitted_modules^)) {
        Lwt.return_unit;
      } else {
        emitted_modules := MLSet.add(m.location, emitted_modules^);
        let%lwt () = emit_module_files(ctx, m);
        let workspace = m.Module.workspace;
        let dependencies =
          DependencyGraph.lookup_dependencies(~kind=`All, graph, m);
        let%lwt () =
          Lwt_list.iter_s(
            ((_, m)) =>
              switch (m) {
              | None => Lwt.return_unit
              | Some(m) => let%lwt m = m; emit_module(m)
              },
            dependencies,
          );

        let%lwt () =
          m.id
          |> Printf.sprintf(
               "\"%s\": function(module, exports, __fastpack_require__, __fastpack_import__) {\n",
             )
          |> emit;

        let%lwt () = emit("eval(\"");
        let modify =
          switch (m.state) {
          | Module.Analyzed => (s => s)
          | _ => to_eval
          };

        let%lwt content =
          Workspace.write(
            ~modify,
            ~output_channel,
            ~workspace,
            ~ctx=(m, dep_map),
          );
        let%lwt () =
          Module.location_to_string(
            ~base_dir=Some(ctx.project_root),
            m.location,
          )
          |> Printf.sprintf("\\n//# sourceURL=fpack:///%s\");")
          |> emit;

        let m = {...m, state: Module.Analyzed};
        let () =
          switch (m.location) {
          | Module.File(_) => ctx.cache.modify_content(m, content)
          | _ => ()
          };

        let _ =
          DependencyGraph.add_module(
            graph,
            m.location,
            Lwt.return({...m, workspace: Workspace.of_string(content)}),
          );

        let%lwt () = emit("\n},\n");
        Lwt.return_unit;
      };

    let export =
      switch (ctx.target) {
      | Target.CommonJS => "module.exports = "
      | _ => ""
      };

    let%lwt () = emit_runtime(output_channel, export, entry.Module.id);
    let%lwt () = emit("({\n");
    let%lwt _ = emit_module(entry);
    let%lwt () = emit("\n});\n");
    Lwt.return_unit;
  };

  let {Context.entry_location, graph, _} = ctx;
  let%lwt entry =
    switch (DependencyGraph.lookup_module(graph, entry_location)) {
    | Some(m) => m
    | None =>
      Error.ie(
        Module.location_to_string(entry_location) ++ " not found in the graph",
      )
    };

        Logs.debug(x => x("GTIME: %f", (Unix.gettimeofday() -. start_time)));
  Logs.debug(x => x("BEFORE EMIT: %s", Module.location_to_string(entry.location)));
  let%lwt _ = emit(graph, entry);
  Lwt.return((
    emitted_modules^,
    Lwt_io.position(output_channel) |> Int64.to_int,
  ));
};
/* DependencyGraph.cleanup ctx.graph emitted_modules; */
/* Lwt_io.position output_channel |> Int64.to_int |> Lwt.return */

let emit = (ctx: Context.t, start_time) => {
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
          run(start_time, ctx),
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

let update_graph = (ctx: Context.t) => {
  let%lwt _ = run(0.0, ctx, Lwt_io.null);
  Lwt.return_unit;
};
