module MDM = Module.DependencyMap;
module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

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

let runtimeMain = publicPath =>
  Printf.sprintf(
    {|
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
    publicPath: %s
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
              setTimeout(resolve);
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
|},
    Yojson.to_string(`String(publicPath)),
  );

let runtimeChunk = "window.__fastpack_update_modules__";

module Bundle = {
  type t = {
    graph: DependencyGraph.t,
    chunkRequests: MDM.t(chunkName),
    locationToChunk: Hashtbl.t(Module.location, chunkName),
    chunks: Hashtbl.t(chunkName, chunk),
    chunkDependency: Hashtbl.t(chunkName, string),
    emittedFiles: Hashtbl.t(string, file),
  }
  and chunkName =
    | Main
    | Named(string)
  and chunk = {
    name: string,
    modules: list(Module.t),
    dependencies: list(string),
  }
  and file = {
    absPath: string,
    relPath: string,
    size: int,
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
    let bundle = {
      graph,
      chunkRequests: MDM.empty,
      locationToChunk: Hashtbl.create(5000),
      chunks: Hashtbl.create(500),
      chunkDependency: Hashtbl.create(500),
      emittedFiles: Hashtbl.create(500),
    };

    let nextChunkName = () => {
      let length = Hashtbl.length(bundle.chunks);
      length > 0 ? string_of_int(length) ++ ".js" : "";
    };

    let updateLocationHash = (modules: list(Module.t), chunkName: chunkName) =>
      List.iter(
        m =>
          Hashtbl.replace(
            bundle.locationToChunk,
            m.Module.location,
            chunkName,
          ),
        modules,
      );

    let splitChunk = (name: string, modules: list(Module.t)) => {
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
        | [] => name
        | chunkModules =>
          /* add new chunk */
          let newName = nextChunkName();
          Hashtbl.replace(
            bundle.chunks,
            Named(newName),
            {name: newName, modules, dependencies: []},
          );
          updateLocationHash(modules, Named(newName));
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
          updateLocationHash(chunkModules, Named(name));
          newName;
        };
      | _ => failwith("One chunk is expected")
      };
    };

    let addMainChunk = (modules: list(Module.t)) => {
      Hashtbl.replace(
        bundle.chunks,
        Main,
        {name: "", modules, dependencies: []},
      );
      updateLocationHash(modules, Main);
      Main;
    };

    let addNamedChunk = (name: string, modules: list(Module.t)) => {
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
      let rec splitModules = (modules: list(Module.t)) => {
        let (name, group, rest) = nextGroup(modules);
        switch (name) {
        | Some(name) =>
          let newChunk = splitChunk(name, group);
          let (rest, dependencies) = splitModules(rest);
          (rest, [newChunk, ...dependencies]);
        | None => (rest, [])
        };
      };
      let (modules, dependencies) = splitModules(modules);
      Hashtbl.replace(
        bundle.chunks,
        Named(name),
        {name, modules, dependencies},
      );
      updateLocationHash(modules, Named(name));
      Named(name);
    };

    let addChunk = (modules: list(Module.t)) => {
      let name = nextChunkName();
      name == "" ? addMainChunk(modules) : addNamedChunk(name, modules);
    };

    let rec make' = (~chunkReqMap=MDM.empty, ~seen=MLSet.empty, location) => {
      Logs.debug(x => x("Make chunk"));
      let%lwt (modules, chunkRequests, seen) =
        makeChunk(graph, location, seen);
      let chunkName = addChunk(modules);
      let%lwt chunkReqMap =
        Lwt_list.fold_left_s(
          (chunkReqMap, {depRequest, toLocation: location}) => {
            let%lwt (chunkName, chunkReqMap) =
              make'(~chunkReqMap, ~seen, location);
            Lwt.return(MDM.add(depRequest, chunkName, chunkReqMap));
          },
          chunkReqMap,
          List.filter(
            ({toLocation, _}) => !MLSet.mem(toLocation, seen),
            chunkRequests,
          ),
        );
      Lwt.return((chunkName, chunkReqMap));
    };
    let%lwt (_, chunkRequests) = make'(entry);
    Lwt.return({...bundle, chunkRequests});
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

  let emit = (ctx: Context.t, bundle: t) => {
    /* more here */
    let%lwt emittedModules =
      Lwt_list.fold_left_s(
        (emittedModules, (chunkName, chunk)) => {
          let (dirname, basename) = {
            let filename =
              FS.abs_path(
                ctx.tmpOutputDir,
                FS.relative_path(
                  ctx.config.outputDir,
                  ctx.config.outputFilename,
                ),
              );
            (FilePath.dirname(filename), FilePath.basename(filename));
          };
          let%lwt () = FS.makedirs(dirname);
          let filename =
            switch (chunkName) {
            | Main => FS.abs_path(dirname, basename)
            | Named(filename) => FS.abs_path(dirname, filename)
            };
          Lwt_io.with_file(
            ~mode=Lwt_io.Output,
            ~perm=0o644,
            ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
            filename,
            ch => {
              let emit = bytes => Lwt_io.write(ch, bytes);
              let%lwt () =
                emit(
                  switch (chunkName) {
                  | Main => runtimeMain(ctx.config.publicPath)
                  | Named(_name) => runtimeChunk
                  },
                );
              let%lwt () = emit("({\n");
              let%lwt emittedModules =
                Lwt_list.fold_left_s(
                  (emittedModules, m) => {
                    let%lwt () = emit_module_files(ctx, m);
                    let short_str =
                      Module.location_to_short_string(
                        ~base_dir=Some(ctx.config.projectRootDir),
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
                          switch (MDM.get(dep, bundle.chunkRequests)) {
                          | None => None
                          | Some(chunkName) =>
                            switch (getChunkDependencies(chunkName, bundle)) {
                            | [] => None
                            | deps =>
                              let dirname = FilePath.dirname(filename);
                              let prefix =
                                FilePath.make_relative(
                                  ctx.tmpOutputDir,
                                  dirname,
                                );
                              Some((
                                dep.Module.Dependency.request,
                                `List(
                                  List.map(
                                    s =>
                                      `String(
                                        CCString.replace(
                                          ~sub="\\",
                                          ~by="/",
                                          prefix == "" ?
                                            s : prefix ++ "/" ++ s,
                                        ),
                                      ),
                                    deps,
                                  ),
                                ),
                              ));
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
                        ",\nc: "
                        ++ Yojson.to_string(`Assoc(chunkDependencies))
                      };

                    let%lwt () =
                      emit(
                        Printf.sprintf(
                          "\n},\nd: %s%s",
                          Yojson.to_string(`Assoc(jsonDependencies)),
                          chunkData,
                        ),
                      );
                    Cache.addModule(m, ctx.cache);
                    let%lwt () = emit("\n},\n");
                    Lwt.return(MLSet.add(m.location, emittedModules));
                  },
                  emittedModules,
                  chunk.modules,
                );
              let%lwt () = emit("\n});\n");
              /* save the fact that chunk was emitted */
              let relPath =
                FilePath.make_relative(ctx.tmpOutputDir, filename);
              let absPath = FS.abs_path(ctx.config.outputDir, relPath);
              Hashtbl.replace(
                bundle.emittedFiles,
                absPath,
                {
                  absPath,
                  relPath,
                  size: Lwt_io.position(ch) |> Int64.to_int,
                },
              );
              Lwt.return(emittedModules);
            },
          );
        },
        MLSet.empty,
        CCHashtbl.to_list(bundle.chunks),
      );
    let _ = DependencyGraph.cleanup(bundle.graph, emittedModules);
    Lwt_unix.rename(ctx.tmpOutputDir, ctx.config.outputDir);
  };

  let getTotalSize = (bundle: t) =>
    List.fold_left(
      (acc, (_, {size, _})) => acc + size,
      0,
      CCHashtbl.to_list(bundle.emittedFiles),
    );
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

let run = (~start_time, ~bundle, ~withChunk, ctx: Context.t) => {
  let _st = start_time;
  let%lwt exportFinder = ExportFinder.make(ctx.graph);
  let ensureImports = (m: Module.t) =>
    switch (ExportFinder.ensure_exports(m, exportFinder)) {
    | Some((m, name)) =>
      let location_str =
        Module.location_to_string(
          ~base_dir=Some(ctx.current_dir),
          m.location,
        );

      raise(
        Context.PackError(ctx, CannotFindExportedName(name, location_str)),
      );
    | None => ()
    };

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
                | Bundle.Main => runtimeMain(ctx.config.publicPath)
                | Bundle.Named(_name) => runtimeChunk
                },
              );
            let%lwt () = emit("({\n");
            let%lwt emittedModules =
              Lwt_list.fold_left_s(
                (emittedModules, m) => {
                  let () = ensureImports(m);
                  let%lwt () = emit_module_files(ctx, m);
                  let short_str =
                    Module.location_to_short_string(
                      ~base_dir=Some(ctx.config.projectRootDir),
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
                        switch (MDM.get(dep, bundle.Bundle.chunkRequests)) {
                        | None => None
                        | Some(chunkName) =>
                          switch (
                            Bundle.getChunkDependencies(chunkName, bundle)
                          ) {
                          | [] => None
                          | deps =>
                            let dirname = FilePath.dirname(chunkFilename);
                            let prefix =
                              FilePath.make_relative(
                                ctx.tmpOutputDir,
                                dirname,
                              );
                            Some((
                              dep.Module.Dependency.request,
                              `List(
                                List.map(
                                  s =>
                                    `String(
                                      CCString.replace(
                                        ~sub="\\",
                                        ~by="/",
                                        prefix == "" ? s : prefix ++ "/" ++ s,
                                      ),
                                    ),
                                  deps,
                                ),
                              ),
                            ));
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
  let%lwt bundle = Bundle.make(ctx.graph, ctx.entry_location);
  Logs.debug(x => x("AFTER MAKING BUNDLE"));
  let withChunk = (name: Bundle.chunkName, f) => {
    let (dirname, basename) = {
      let filename =
        FS.abs_path(
          ctx.tmpOutputDir,
          FS.relative_path(ctx.config.outputDir, ctx.config.outputFilename),
        );
      (FilePath.dirname(filename), FilePath.basename(filename));
    };
    let%lwt () = FS.makedirs(dirname);
    let filename =
      switch (name) {
      | Bundle.Main => FS.abs_path(dirname, basename)
      | Bundle.Named(filename) => FS.abs_path(dirname, filename)
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
        run(~start_time, ~bundle, ~withChunk, ctx);
      Logs.debug(x => x("AFTER EMIT"));

      let%lwt () =
        switch%lwt (FS.stat_option(ctx.config.outputDir)) {
        | Some({st_kind: Lwt_unix.S_DIR, _}) =>
          FS.rmdir(ctx.config.outputDir)
        | Some(_) => Lwt_unix.unlink(ctx.config.outputDir)
        | None => Lwt.return_unit
        };
      let%lwt () = Lwt_unix.rename(ctx.tmpOutputDir, ctx.config.outputDir);
      let emittedFiles =
        List.map(
          ({Reporter.name, _} as f) => {
            ...f,
            name: FS.abs_path(ctx.config.outputDir, Filename.basename(name)),
          },
          emittedFiles,
        );
      Lwt.return((emittedModules, emittedFiles));
    },
    () => Lwt.return_unit,
  );
};

let update_graph = (ctx: Context.t, start_time) => {
  let%lwt bundle = Bundle.make(ctx.graph, ctx.entry_location);
  let withChunk = (name: Bundle.chunkName, f) => {
    let filename =
      switch (name) {
      | Bundle.Main =>
        let filename =
          FS.relative_path(ctx.config.outputDir, ctx.config.outputFilename);
        FS.abs_path(ctx.tmpOutputDir, filename);
      | Bundle.Named(filename) => FS.abs_path(ctx.tmpOutputDir, filename)
      };
    f(filename, Lwt_io.null);
  };
  let%lwt (emittedFiles, emittedModules) =
    run(~start_time, ~bundle, ~withChunk, ctx);
  Lwt.return((emittedModules, emittedFiles));
};
