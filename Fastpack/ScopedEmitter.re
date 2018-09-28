module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

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
  let%lwt dep_map = DependencyGraph.to_dependency_map(ctx.graph);

  let ensure_export_exists = (m: Module.t, name) =>
    switch (ctx.export_finder.exists(dep_map, m, name)) {
    | ExportFinder.Yes
    | ExportFinder.Maybe => ()
    | ExportFinder.No =>
      let location_str =
        Module.location_to_string(
          ~base_dir=Some(ctx.current_dir),
          m.location,
        );

      raise(
        Context.PackError(ctx, CannotFindExportedName(name, location_str)),
      );
    };

  let ensure_exports = (m: Module.t) =>
    m.scope
    |> Scope.bindings
    |> List.iter(((_, binding)) =>
         switch (binding) {
         | {Scope.typ: Scope.Import({remote: Some(remote), source}), _} =>
           let dep = {
             Module.Dependency.request: source,
             requested_from: m.location,
           };
           switch (Module.DependencyMap.get(dep, dep_map)) {
           | None =>
             failwith(
               "Something is extremely wrong: resolution error "
               ++ source
               ++ " "
               ++ Module.location_to_string(m.location),
             )
           | Some(m) => ensure_export_exists(m, remote)
           };

         | _ => ()
         }
       );
  /* emit required runtime */
  let emit_runtime = (out, prefix, entry_id) =>
    Lwt_io.write(out) @@
    Printf.sprintf(
      {|
global = this;
process = { env: {}, browser: true };
if(!global.Buffer) {
  global.Buffer = {isBuffer: false};
}
// This function is a modified version of the one created by the Webpack project
%s(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(fromModule, request) {
    var moduleId = fromModule === null ? request : modules[fromModule].d[request];

    // Check if module is in cache
    if(installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    // Create a new module (and put it into the cache)
    var module = installedModules[moduleId] = {
      id: moduleId,
      l: false,
      exports: {}
    };

    var r = __fastpack_require__.bind(null, moduleId);
    r.default = __fastpack_require__.default;
    r.omitDefault = __fastpack_require__.omitDefault;
    // Execute the module function
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      r,
      __fastpack_import__.bind(null, moduleId)
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(fromModule, request) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(fromModule, request));
      } catch (e) {
        reject(e);
      }
    });
  }

  __fastpack_require__.m = modules;
  __fastpack_require__.c = installedModules;
  __fastpack_require__.omitDefault = function(moduleVar) {
    var keys = Object.keys(moduleVar);
    var ret = {};
    for(var i = 0, l = keys.length; i < l; i++) {
      var key = keys[i];
      if (key !== 'default') {
        ret[key] = moduleVar[key];
      }
    }
    return ret;
  }
  __fastpack_require__.default = function(exports) {
    return exports.__esModule ? exports.default : exports;
  }
  return __fastpack_require__(null, __fastpack_require__.s = '%s');
})
    |},
      prefix,
      entry_id,
    );

  let emitted_modules = ref(MLSet.empty);
  let emit = (graph, entry) => {
    let emit = bytes => Lwt_io.write(output_channel, bytes);
    let rec emit_module = (m: Module.t) =>
      if (MLSet.mem(m.location, emitted_modules^)) {
        Lwt.return_unit;
      } else {
        let () = ensure_exports(m);
        emitted_modules := MLSet.add(m.location, emitted_modules^);
        let%lwt () = emit_module_files(ctx, m);
        let dependencies =
          DependencyGraph.lookup_dependencies(~kind=`All, graph, m);
        let%lwt () =
          Lwt_list.iter_s(
            ((_, m)) =>
              switch (m) {
              | None => Lwt.return_unit
              | Some(m) =>
                let%lwt m = m;
                emit_module(m);
              },
            dependencies,
          );

        let location_str =
          Module.location_to_string(
            ~base_dir=Some(ctx.project_root),
            m.location,
          );
        let%lwt () =
          Printf.sprintf(
            "%s:{m:function(module, exports, __fastpack_require__, __fastpack_import__) {\n",
            Yojson.to_string(`String(m.id)),
          )
          |> emit;
        let%lwt () = emit("eval(\"");
        let%lwt () = emit(m.Module.source);
        let%lwt () =
          location_str
          |> Printf.sprintf("\\n//# sourceURL=fpack:///%s\");")
          |> emit;

        let%lwt jsonDependencies =
          Lwt_list.map_s(
            (({Module.Dependency.request, _}, m)) =>
              switch (m) {
              | Some(m) =>
                let%lwt m = m;
                Lwt.return((request, `String(m.Module.id)));
              | None => failwith("Should not happen")
              },
            dependencies,
          );

        let%lwt () =
          emit(
            Printf.sprintf(
              "\n},\nd: %s",
              Yojson.to_string(`Assoc(jsonDependencies)),
            ),
          );
        let%lwt () = emit("\n},\n");
        Cache.addModule(m, ctx.cache);
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

  Logs.debug(x => x("GTIME: %f", Unix.gettimeofday() -. start_time));
  Logs.debug(x =>
    x("BEFORE EMIT: %s", Module.location_to_string(entry.location))
  );
  let%lwt _ = emit(graph, entry);
  Lwt.return((
    emitted_modules^,
    Lwt_io.position(output_channel) |> Int64.to_int,
  ));
};

let emit = (ctx: Context.t, start_time) => {
  let (temp_file, _) =
    Filename.open_temp_file(
      ~perms=0o644,
      ~temp_dir=ctx.output_dir,
      ".fpack",
      ".bundle.js",
    );

  Lwt.finalize(
    () => {
      let%lwt (emitted_modules, size) =
        Lwt_io.with_file(
          ~mode=Lwt_io.Output,
          ~perm=0o644,
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

let update_graph = (ctx: Context.t, start_time) => {
  let%lwt (emitted_modules, _) = run(start_time, ctx, Lwt_io.null);
  Lwt.return((
    emitted_modules,
    [{Reporter.name: "dry-run", size: 0}],
  ));
};
