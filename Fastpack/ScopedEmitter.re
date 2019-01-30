module MDM = Module.DependencyMap;
module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

module Bundle = {
  type t = {
    locationToChunk: Hashtbl.t(Module.location, chunkName),
    chunks: Hashtbl.t(chunkName, chunk),
    chunkDependency: Hashtbl.t(chunkName, string),
  }
  and chunkName =
    | Main
    | Named(string)
  and chunk = {
    name: string,
    modules: list(Module.t),
    dependencies: list(string),
  };

  let empty = () => {
    locationToChunk: Hashtbl.create(5000),
    chunks: Hashtbl.create(500),
    chunkDependency: Hashtbl.create(500),
  };

  let nextChunkName = bundle => {
    let length = Hashtbl.length(bundle.chunks);
    length > 0 ? string_of_int(length) ++ ".js" : "";
  };

  let updateLocationHash =
      (modules: list(Module.t), chunkName: chunkName, bundle: t) =>
    List.iter(
      m => {
        /* let loc = Module.location_to_string(m.Module.location); */
        /* let cn = */
        /*   switch (chunkName) { */
        /*   | Named(name) => name */
        /*   | Main => "main" */
        /*   }; */
        /* Logs.debug(x => x("Module %s => %s", loc, cn)); */
        Hashtbl.replace(bundle.locationToChunk, m.Module.location, chunkName);
      },
      modules,
    );

  let splitChunk = (name: string, modules: list(Module.t), bundle: t) => {
    Logs.debug(x => x("Split chunk: %s", name));
    switch (Hashtbl.find_all(bundle.chunks, Named(name))) {
    | [{modules: chunkModules, dependencies, _}] =>
      let modulesLocationSet =
        MLSet.of_list(List.map(m => m.Module.location, modules));
      let chunkModules =
        List.filter(
          m => !MLSet.mem(m.Module.location, modulesLocationSet),
          chunkModules,
        );
      switch (chunkModules) {
      | [] => (bundle, name)
      | chunkModules =>
        /* add new chunk */
        let newName = nextChunkName(bundle);
        Hashtbl.replace(
          bundle.chunks,
          Named(newName),
          {name: newName, modules, dependencies: []},
        );
        updateLocationHash(modules, Named(newName), bundle);
        /* modify old chunk */
        Hashtbl.replace(
          bundle.chunks,
          Named(name),
          {
            name,
            modules: chunkModules,
            dependencies: [newName, ...dependencies],
          },
        );
        updateLocationHash(chunkModules, Named(name), bundle);
        (bundle, newName);
      };
    | _ => failwith("One chunk is expected")
    };
  };

  let addNamedChunk = (name: string, modules: list(Module.t), bundle: t) => {
    /* 0. add new chunk right away */
    Hashtbl.replace(
      bundle.chunks,
      Named(name),
      {name, modules: [], dependencies: []},
    );
    let nextGroup =
      List.fold_left(
        ((groupName, group, rest), m) =>
          switch (
            Hashtbl.find_all(bundle.locationToChunk, m.Module.location),
            groupName,
          ) {
          | ([], _) => (groupName, group, [m, ...rest])
          | ([Named(name)], None) => (Some(name), [m, ...group], rest)
          | ([Named(name)], Some(groupName)) =>
            name == groupName ?
              (Some(groupName), [m, ...group], rest) :
              (Some(groupName), group, [m, ...rest])
          | ([Main], _) => failwith("Cannot split main chunk")
          | _ => failwith("Module references more than 1 chunk")
          },
        (None, [], []),
      );
    let rec splitModules = (modules: list(Module.t), bundle: t) => {
      let (name, group, rest) = nextGroup(modules);
      switch (name) {
      | Some(name) =>
        let (bundle, newChunk) = splitChunk(name, group, bundle);
        let (bundle, rest, dependencies) = splitModules(rest, bundle);
        (bundle, rest, [newChunk, ...dependencies]);
      | None => (bundle, rest, [])
      };
    };
    let (bundle, modules, dependencies) = splitModules(modules, bundle);
    Hashtbl.replace(
      bundle.chunks,
      Named(name),
      {name, modules, dependencies},
    );
    updateLocationHash(modules, Named(name), bundle);
    (Named(name), bundle);
  };

  let addMainChunk = (modules: list(Module.t), bundle: t) => {
    Hashtbl.replace(
      bundle.chunks,
      Main,
      {name: "", modules, dependencies: []},
    );
    updateLocationHash(modules, Main, bundle);
    (Main, bundle);
  };

  let addChunk = (modules: list(Module.t), bundle: t) => {
    let name = nextChunkName(bundle);
    name == "" ?
      addMainChunk(modules, bundle) : addNamedChunk(name, modules, bundle);
  };

  type chunkRequest = {
    depRequest: Module.Dependency.t,
    toLocation: Module.location,
  };

  let makeChunk = (graph, entry, seen) => {
    let rec addModule = (seen, location: Module.location) =>
      MLSet.mem(location, seen) ?
        Lwt.return(([], [], seen)) :
        {
          let%lwt m =
            switch (DependencyGraph.lookup_module(graph, location)) {
            | Some(m) => m
            | None =>
              Error.ie(
                Module.location_to_string(location)
                ++ " not found in the graph",
              )
            };

          let seen = MLSet.add(m.location, seen);

          let%lwt (modules, chunkRequests, seen) =
            Lwt_list.fold_left_s(
              ((modules, chunkRequests, seen), (_, m)) =>
                switch (m) {
                | None => failwith("Should not happen")
                | Some(m) =>
                  let%lwt m = m;
                  /* Logs.debug(x => x("Dep: %s", m.Module.id)); */
                  let%lwt (modules', chunkRequests', seen) =
                    addModule(seen, m.Module.location);
                  Lwt.return((
                    modules @ modules',
                    chunkRequests' @ chunkRequests,
                    seen,
                  ));
                },
              ([], [], seen),
              DependencyGraph.lookup_dependencies(~kind=`Static, graph, m)
              |> List.rev,
            );

          let%lwt chunkRequests' =
            DependencyGraph.lookup_dependencies(~kind=`Dynamic, graph, m)
            |> List.rev
            |> Lwt_list.map_s(((depRequest, m')) =>
                 switch (m') {
                 | None => failwith("Should not happen")
                 | Some(m') =>
                   let%lwt m' = m';
                   Lwt.return({depRequest, toLocation: m'.Module.location});
                 }
               );

          Lwt.return((
            [m, ...modules],
            chunkRequests' @ chunkRequests,
            seen,
          ));
        };
    let%lwt (modules, chunkRequests, seen) = addModule(seen, entry);
    Lwt.return((List.rev(modules), chunkRequests, seen));
  };

  let make = (graph: DependencyGraph.t, entry: Module.location) => {
    let rec make' =
            (~chunkReqMap=MDM.empty, ~seen=MLSet.empty, ~location, bundle) => {
      Logs.debug(x => x("Make chunk"));
      let%lwt (modules, chunkRequests, seen) =
        makeChunk(graph, location, seen);
      Logs.debug(x => x("Make chunk done"));
      let (chunkName, bundle) = addChunk(modules, bundle);
      let%lwt (chunkReqMap, bundle) =
        Lwt_list.fold_left_s(
          ((chunkReqMap, bundle), {depRequest, toLocation: location}) => {
            let%lwt (chunkName, chunkReqMap, bundle) =
              make'(~chunkReqMap, ~seen, ~location, bundle);
            Lwt.return((
              MDM.add(depRequest, chunkName, chunkReqMap),
              bundle,
            ));
          },
          (chunkReqMap, bundle),
          List.filter(
            ({toLocation, _}) => !MLSet.mem(toLocation, seen),
            chunkRequests,
          ),
        );
      Lwt.return((chunkName, chunkReqMap, bundle));
    };
    let%lwt (_, chunkReqMap, bundle) = make'(~location=entry, empty());
    Lwt.return((chunkReqMap, bundle));
  };

  let foldChunks = (f, acc, bundle: t) =>
    Lwt_list.fold_left_s(f, acc, CCHashtbl.to_list(bundle.chunks));

  let rec getChunkDependencies =
          (~seen=StringSet.empty, chunkName: chunkName, bundle: t) =>
    switch (Hashtbl.find_all(bundle.chunkDependency, chunkName)) {
    | [] =>
      switch (chunkName) {
      | Main => failwith("Unexpected dependency on the main chunk")
      | Named(name) =>
        switch (Hashtbl.find_all(bundle.chunks, chunkName)) {
        | [] => failwith("Unknown chunk: " ++ name)
        | [{modules, dependencies, _}] =>
          if (StringSet.mem(name, seen)) {
            failwith("Chunk dependency cycle");
          } else {
            let seen = StringSet.add(name, seen);
            let dependencies =
              List.fold_left(
                (set, dep) =>
                  StringSet.union(
                    set,
                    StringSet.of_list(
                      getChunkDependencies(~seen, Named(dep), bundle),
                    ),
                  ),
                List.length(modules) > 0 ?
                  StringSet.singleton(name) : StringSet.empty,
                dependencies,
              )
              |> StringSet.elements;
            List.iter(
              dep => Hashtbl.add(bundle.chunkDependency, chunkName, dep),
              dependencies,
            );
            dependencies;
          }
        | _ => failwith("Several chunks named: " ++ name)
        }
      }
    | found => found
    };
};

let emit_module_files = (ctx: Context.t, m: Module.t) =>
  Lwt_list.iter_s(
    ((filename, content)) => {
      let path = FS.abs_path(ctx.tmpOutputDir, filename);
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

let runtimeMain = {|
global = this;
process = { env: {}, browser: true };
if (!global.Buffer) {
  global.Buffer = { isBuffer: false };
}
// This function is a modified version of the one created by the Webpack project
(function(modules) {
  // The module cache
  var installedModules = {};

  function __fastpack_require__(fromModule, request) {
    var moduleId =
      fromModule === null ? request : modules[fromModule].d[request];

    if (installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    var module = (installedModules[moduleId] = {
      id: moduleId,
      l: false,
      exports: {}
    });

    var r = __fastpack_require__.bind(null, moduleId);
    var helpers = Object.getOwnPropertyNames(__fastpack_require__.helpers);
    for (var i = 0, l = helpers.length; i < l; i++) {
      r[helpers[i]] = __fastpack_require__.helpers[helpers[i]];
    }
    r.imp = r.imp.bind(null, moduleId);
    r.state = state;
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      r,
      r.imp
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  var loadedChunks = {};
  var state = {
    publicPath: ""
  };

  window.__fastpack_update_modules__ = function(newModules) {
    for (var id in newModules) {
      if (modules[id]) {
        throw new Error(
          "Chunk tries to replace already existing module: " + id
        );
      } else {
        modules[id] = newModules[id];
      }
    }
  };

  __fastpack_require__.helpers = {
    omitDefault: function(moduleVar) {
      var keys = Object.keys(moduleVar);
      var ret = {};
      for (var i = 0, l = keys.length; i < l; i++) {
        var key = keys[i];
        if (key !== "default") {
          ret[key] = moduleVar[key];
        }
      }
      return ret;
    },

    default: function(exports) {
      return exports.__esModule ? exports.default : exports;
    },

    imp: function(fromModule, request) {
      if (!window.Promise) {
        throw Error("window.Promise is undefined, consider using a polyfill");
      }
      var sourceModule = modules[fromModule];
      var chunks = (sourceModule.c || {})[request] || [];
      var promises = [];
      for (var i = 0, l = chunks.length; i < l; i++) {
        var js = chunks[i];
        var p = loadedChunks[js];
        if (!p) {
          p = loadedChunks[js] = new Promise(function(resolve, reject) {
            var script = document.createElement("script");
            script.onload = function() {
              resolve();
            };
            script.onerror = function() {
              reject();
              throw new Error("Script load error: " + script.src);
            };
            script.src = state.publicPath + chunks[i];
            document.head.append(script);
          });
          promises.push(p);
        }
      }
      return Promise.all(promises).then(function() {
        return __fastpack_require__(fromModule, request);
      });
    }
  };

  return __fastpack_require__(null, (__fastpack_require__.s = "$fp$main"));
})
|};

let runtimeChunk = "window.__fastpack_update_modules__";

let run = (~start_time, ~bundle, ~chunkRequests, ~withChunk, ctx: Context.t) => {
  let _st = start_time;
  let _req = chunkRequests;
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
  Logs.debug(x => x("FOLDING CHUNKS"));
  Bundle.foldChunks(
    ((emittedFiles, emittedModules), (chunkName, chunk: Bundle.chunk)) => {
      let%lwt (emittedModules, filename, size) =
        withChunk(
          chunkName,
          (chunkFilename, ch) => {
            let emit = bytes => Lwt_io.write(ch, bytes);
            let%lwt () =
              emit(
                switch (chunkName) {
                | Bundle.Main =>   Logs.debug(x => x("chunk: main")); runtimeMain
                | Bundle.Named(name) => Logs.debug(x => x("chunk: %s", name)); runtimeChunk
                },
              );
            let%lwt () = emit("({\n");
            let%lwt emittedModules =
              Lwt_list.fold_left_s(
                (emittedModules, m) => {
                  let () = ensure_exports(m);
                  let%lwt () = emit_module_files(ctx, m);
                  let short_str =
                    Module.location_to_short_string(
                      ~base_dir=Some(ctx.project_root),
                      m.location,
                    );
                  let%lwt () =
                    Printf.sprintf(
                      "/* !s: %s */\n%s:{m:function(module, exports, __fastpack_require__) {\n",
                      CCString.replace(~sub="\\", ~by="/", short_str),
                      Yojson.to_string(`String(m.id)),
                    )
                    |> emit;
                  let%lwt () = emit("eval(\"");
                  let%lwt () = emit(m.Module.source);
                  let%lwt () = emit("\");");

                  let%lwt jsonDependencies =
                    Lwt_list.map_s(
                      (({Module.Dependency.request, _}, m)) =>
                        switch (m) {
                        | Some(m) =>
                          let%lwt m = m;
                          Lwt.return((request, `String(m.Module.id)));
                        | None => failwith("Should not happen")
                        },
                      DependencyGraph.lookup_dependencies(
                        ~kind=`All,
                        ctx.graph,
                        m,
                      ),
                    );

                  let chunkDependencies =
                    CCList.filter_map(
                      ((dep, _)) =>
                        switch (MDM.get(dep, chunkRequests)) {
                        | None => None
                        | Some(chunkName) =>
                          switch (
                            Bundle.getChunkDependencies(chunkName, bundle)
                          ) {
                          | [] => None
                          | deps =>
                            Some((
                              dep.Module.Dependency.request,
                              `List(List.map(s => `String(s), deps)),
                            ))
                          }
                        },
                      DependencyGraph.lookup_dependencies(
                        ~kind=`Dynamic,
                        ctx.graph,
                        m,
                      ),
                    );

                  let chunkData =
                    switch (chunkDependencies) {
                    | [] => ""
                    | _ =>
                      ",\nc: " ++ Yojson.to_string(`Assoc(chunkDependencies))
                    };

                  let%lwt () =
                    emit(
                      Printf.sprintf(
                        "\n},\nd: %s%s",
                        Yojson.to_string(`Assoc(jsonDependencies)),
                        chunkData,
                      ),
                    );
                  let%lwt () = emit("\n},\n");
                  Cache.addModule(m, ctx.cache);
                  Lwt.return(MLSet.add(m.location, emittedModules));
                },
                emittedModules,
                chunk.modules,
              );
            let%lwt () = emit("\n});\n");

            Lwt.return((
              emittedModules,
              chunkFilename,
              Lwt_io.position(ch) |> Int64.to_int,
            ));
          },
        );
      Lwt.return((
        [{Reporter.name: filename, size}, ...emittedFiles],
        emittedModules,
      ));
    },
    ([], MLSet.empty),
    bundle,
  );
};

let emit = (ctx: Context.t, start_time) => {
  let%lwt () = FS.makedirs(ctx.tmpOutputDir);
  Logs.debug(x => x("BEFORE MAKING BUNDLE"));
  let%lwt (chunkRequests, bundle) =
    Bundle.make(ctx.graph, ctx.entry_location);
  Logs.debug(x => x("AFTER MAKING BUNDLE"));
  let withChunk = (name: Bundle.chunkName, f) => {
    let filename =
      switch (name) {
      | Bundle.Main =>
        let filename = FS.relative_path(ctx.output_dir, ctx.output_file);
        FS.abs_path(ctx.tmpOutputDir, filename);
      | Bundle.Named(filename) => FS.abs_path(ctx.tmpOutputDir, filename)
      };
    Lwt_io.with_file(
      ~mode=Lwt_io.Output,
      ~perm=0o644,
      ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
      filename,
      f(filename),
    );
  };
  Lwt.finalize(
    () => {
      Logs.debug(x => x("BEFORE EMIT"));
      let%lwt (emittedFiles, emittedModules) =
        run(~start_time, ~bundle, ~chunkRequests, ~withChunk, ctx);
      Logs.debug(x => x("AFTER EMIT"));

      let%lwt () =
        switch%lwt (FS.stat_option(ctx.output_dir)) {
        | Some({st_kind: Lwt_unix.S_DIR, _}) => FS.rmdir(ctx.output_dir)
        | Some(_) => Lwt_unix.unlink(ctx.output_dir)
        | None => Lwt.return_unit
        };
      let%lwt () = Lwt_unix.rename(ctx.tmpOutputDir, ctx.output_dir);
      let emittedFiles =
        List.map(
          ({Reporter.name, _} as f) => {
            ...f,
            name: FS.abs_path(ctx.output_dir, Filename.basename(name)),
          },
          emittedFiles,
        );
      Lwt.return((emittedModules, emittedFiles));
    },
    () => Lwt.return_unit,
  );
};

let update_graph = (ctx: Context.t, start_time) => {
  let%lwt (chunkRequests, bundle) =
    Bundle.make(ctx.graph, ctx.entry_location);
  let withChunk = (name: Bundle.chunkName, f) => {
    let filename =
      switch (name) {
      | Bundle.Main =>
        let filename = FS.relative_path(ctx.output_dir, ctx.output_file);
        FS.abs_path(ctx.tmpOutputDir, filename);
      | Bundle.Named(filename) => FS.abs_path(ctx.tmpOutputDir, filename)
      };
    f(filename, Lwt_io.null);
  };
  let%lwt (emittedFiles, emittedModules) =
    run(~start_time, ~bundle, ~chunkRequests, ~withChunk, ctx);
  Lwt.return((emittedModules, emittedFiles));
};
