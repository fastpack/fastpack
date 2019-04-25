module MLSet = Module.LocationSet;
module StringSet = Set.Make(CCString);
module M = Map.Make(String);

module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module P = Ast.Pattern;
module L = Ast.Literal;

module UTF8 = FastpackUtil.UTF8;
module FS = FastpackUtil.FS;
module Parser = FastpackUtil.Parser;
module Scope = FastpackUtil.Scope;
module Visit = FastpackUtil.Visit;

exception Cycle(list(string));
exception Rebuild(string, Module.location);

type t = {
  modules: Hashtbl.t(Module.location, Lazy.t(Lwt.t(Module.t))),
  /**
    x.js
    import X from "./y";
    x.js => (("x.js", "./y"), "y.js")
  */
  staticDeps:
    Hashtbl.t(Module.location, (Module.Dependency.t, Module.location)),
  /**
    x.js
    import("./y");
    x.js => (("x.js", "./y"), "y.js")
  */
  dynamicDeps:
    Hashtbl.t(Module.location, (Module.Dependency.t, Module.location)),
  buildDeps: Hashtbl.t(string, Module.location),
  parents: Hashtbl.t(Module.location, Module.LocationSet.t),
};

let empty = (~size=5000, ()) => {
  modules: Hashtbl.create(size),
  staticDeps: Hashtbl.create(size * 20),
  dynamicDeps: Hashtbl.create(size * 20),
  buildDeps: Hashtbl.create(size * 5),
  parents: Hashtbl.create(size * 20),
};

let lookup = (table, key) => Hashtbl.find_opt(table, key);

let lookup_module = (graph, location) =>
  switch (lookup(graph.modules, location)) {
  | None => None
  | Some(v) => Some(Lazy.force(v))
  };

let lookup_dependencies = (~kind, graph, m: Module.t) => {
  let dependencies =
    switch (kind) {
    | `Static => Hashtbl.find_all(graph.staticDeps, m.location)
    | `Dynamic => Hashtbl.find_all(graph.dynamicDeps, m.location)
    | `All =>
      Hashtbl.find_all(graph.staticDeps, m.location)
      @ Hashtbl.find_all(graph.dynamicDeps, m.location)
    };

  List.map(
    ((dep, location)) => (dep, lookup_module(graph, location)),
    dependencies,
  );
};

let to_dependency_map = graph => {
  let to_pairs =
    CCHashtbl.map_list((_, (dep, location)) =>
      switch (lookup_module(graph, location)) {
      | None => failwith("not good at all, unknown location")
      | Some(m) => (dep, m)
      }
    );

  Lwt_list.fold_left_s(
    (dep_map, (dep, m)) => {
      let%lwt m = m;
      Module.DependencyMap.add(dep, m, dep_map) |> Lwt.return;
    },
    Module.DependencyMap.empty,
    to_pairs(graph.staticDeps) @ to_pairs(graph.dynamicDeps),
  );
};

let add_module = (graph, location, m: Lazy.t(Lwt.t(Module.t))) =>
  Hashtbl.replace(graph.modules, location, m);

let add_module_parents = (graph, location, parents: Module.LocationSet.t) =>
  Hashtbl.add(graph.parents, location, parents);

let get_module_parents = (graph, location) =>
  Hashtbl.find_all(graph.parents, location)
  |> List.fold_left(
       (acc, parents) => Module.LocationSet.union(acc, parents),
       Module.LocationSet.empty,
     );

let add_build_dependencies = (graph, filenames, location) =>
  List.iter(
    filename => Hashtbl.add(graph.buildDeps, filename, location),
    filenames,
  );

let add_dependency =
    (~kind, graph, m: Module.t, dep: (Module.Dependency.t, Module.location)) => {
  let dependencies =
    switch (kind) {
    | `Static => graph.staticDeps
    | `Dynamic => graph.dynamicDeps
    };
  Hashtbl.add(dependencies, m.location, dep);
};

let remove_module = (graph, location: Module.location) => {
  let remove = (k, v) =>
    if (Module.equal_location(k, location)) {
      None;
    } else {
      Some(v);
    };

  let remove_files = (_, location') =>
    if (Module.equal_location(location, location')) {
      None;
    } else {
      Some(location');
    };

  Hashtbl.filter_map_inplace(remove, graph.modules);
  Hashtbl.filter_map_inplace(remove, graph.parents);
  Hashtbl.filter_map_inplace(remove, graph.staticDeps);
  Hashtbl.filter_map_inplace(remove, graph.dynamicDeps);
  Hashtbl.filter_map_inplace(remove_files, graph.buildDeps);
};

let get_files = graph =>
  Hashtbl.fold(
    (filename, _, set) => StringSet.add(filename, set),
    graph.buildDeps,
    StringSet.empty,
  );

let get_changed_module_locations = (graph, filenames) =>
  List.fold_left(
    (locations, filename) =>
      List.fold_left(
        (locations, location) => Module.LocationSet.add(location, locations),
        locations,
        Hashtbl.find_all(graph.buildDeps, filename),
      ),
    Module.LocationSet.empty,
    filenames,
  );

/* TODO: make emitted_modules be LocationSet */
let cleanup = (graph, emitted_modules) => {
  let keep = (location, value) =>
    if (Module.LocationSet.mem(location, emitted_modules)) {
      Some(value);
    } else {
      None;
    };

  Hashtbl.filter_map_inplace(keep, graph.modules);
  Hashtbl.filter_map_inplace(keep, graph.parents);
  Hashtbl.filter_map_inplace(keep, graph.staticDeps);
  Hashtbl.filter_map_inplace(keep, graph.dynamicDeps);

  Hashtbl.filter_map_inplace(
    (_, location) => keep(location, location),
    graph.buildDeps,
  );
  graph;
};

let length = graph => Hashtbl.length(graph.modules);

let modules = graph =>
  CCHashtbl.to_seq(graph.modules)
  |> Sequence.map(((k, m)) => (k, Lazy.force(m)));

let iterModules = (graph, f) =>
  Lwt_list.iter_s(
    ((_, m)) => {
      let%lwt m = m;
      f(m);
    },
    Sequence.to_list(modules(graph)),
  );

let foldModules = (graph, f, acc) =>
  Lwt_list.fold_left_s(
    (acc, (_, m)) => {
      let%lwt m = m;
      f(acc, m);
    },
    acc,
    Sequence.to_list(modules(graph)),
  );


let ensureModule = (graph, location, makeModule) =>
  switch (lookup_module(graph, location)) {
  | Some(mPromise) => mPromise
  | None =>
    let lazyMakeModule = Lazy.from_fun(makeModule);
    add_module(graph, location, lazyMakeModule);
    Lazy.force(lazyMakeModule);
  };

let hasModule = (graph, location) =>
  switch (Hashtbl.find_opt(graph.modules, location)) {
  | Some(_) => true
  | None => false
  };

type dependencies =
  | NoDependendencies
  | Dependencies(list(Module.Dependency.t), list(Module.Dependency.t));

let resolve = (ctx: Context.t, request: Module.Dependency.t) => {
  let basedir =
    switch (request.requested_from) {
    | Module.File({filename: Some(filename), _}) =>
      FilePath.dirname(filename)
    | Module.File({filename: None, _})
    | Module.Runtime
    | Module.EmptyModule
    | Module.Main(_) => ctx.current_dir
    };

  Lwt.catch(
    () => Resolver.resolve(~basedir, request.request, ctx.resolver),
    fun
    | Resolver.Error(path) =>
      Lwt.fail(Error.PackError(CannotResolveModule(path, request)))
    | exn => raise(exn),
  );
};

let is_json = (location: Module.location) =>
  switch (location) {
  | Module.File({filename: Some(filename), preprocessors: []}) =>
    CCString.suffix(~suf=".json", filename)
  | _ => false
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

let read_module =
    (~ctx: Context.t, ~read, ~graph: t, location: Module.location) => {
  let make_module = (location, source) => {
    let%lwt package =
      switch (location) {
      | Module.EmptyModule
      | Module.Runtime => Lwt.return(Package.empty)
      | Module.Main(_) => Lwt.return(ctx.project_package)
      | Module.File({filename: Some(filename), _}) =>
        find_package_for_filename(ctx.cache, ctx.current_dir, filename)

      | Module.File({filename: None, _}) => Lwt.return(ctx.project_package)
      };

    let m =
      Module.{
        id: make_id(Config.projectRootDir(ctx.config), location),
        location,
        package,
        static_dependencies: [],
        dynamic_dependencies: [],
        build_dependencies: M.empty,
        module_type: Module.CJS,
        files: [],
        source,
        scope: FastpackUtil.Scope.empty,
        exports: FastpackUtil.Scope.empty_exports,
        warnings: [],
      };
    Lwt.return((m, NoDependendencies));
  };

  let process_source = () => {
    let%lwt source =
      switch (location) {
      | Module.Main(entry_points) =>
        entry_points
        |> List.map(req => Printf.sprintf("import '%s';\n", req))
        |> String.concat("")
        |> Lwt.return_some

      | Module.EmptyModule => Lwt.return_some("module.exports = {};")

      | Module.Runtime => Lwt.return_some(FastpackTranspiler.runtime)

      | Module.File({filename, _}) =>
        switch (filename) {
        | Some(filename) =>
          let%lwt _ =
            if (!FilePath.is_subdir(filename, Config.projectRootDir(ctx.config))) {
              Lwt.fail(
                Error.PackError(CannotLeavePackageDir(filename)),
              );
            } else {
              Lwt.return_unit;
            };

          let%lwt content =
            switch%lwt (Cache.File.read(filename, ctx.cache)) {
            | Some(content) => Lwt.return(content)
            | None => Lwt.fail(Rebuild(filename, location))
            };

          /* strip #! from the very beginning */
          let content_length = String.length(content);
          let content =
            if (content_length > 2) {
              if (content.[0] == '#' && content.[1] == '!') {
                let nl_index = CCString.find(~sub="\n", content);
                String.sub(content, nl_index, content_length - nl_index);
              } else {
                content;
              };
            } else {
              content;
            };

          Lwt.return_some(content);
        | None => Lwt.return_none
        }
      };

    let self_dependency =
      switch (location) {
      | File({filename: Some(filename), _}) => [filename]
      | _ => []
      };

    /* Make sure module depends on the source file */
    add_build_dependencies(graph, self_dependency, location);

    let recordBuildDependencies =
      Lwt_list.fold_left_s(
        (build_dependencies, filename) =>
          switch%lwt (Cache.File.stat(filename, ctx.cache)) {
          | Some({Unix.st_mtime, _}) =>
            Lwt.return(M.add(filename, st_mtime, build_dependencies))
          | None => Lwt.fail(Failure(filename ++ " does not exist"))
          },
        M.empty,
      );

    switch (is_json(location), source) {
    | (true, Some(source)) =>
      let json =
        Yojson.to_string(`String("module.exports = " ++ source ++ ";"));
      let%lwt (m, dependencies) =
        make_module(location, String.(sub(json, 1, length(json) - 2)));
      let%lwt build_dependencies = recordBuildDependencies(self_dependency);
      Lwt.return(({...m, build_dependencies}, dependencies));
    | (true, None) => failwith("impossible: *.json file without source")
    | (false, _) =>
      let%lwt {
        Worker.source,
        static_dependencies,
        dynamic_dependencies,
        module_type,
        scope,
        exports,
        warnings,
        build_dependencies,
        files,
      } =
        /* switch%lwt (Worker.Reader.read(~location, ~source, ctx.reader)) { */
        switch%lwt (read(location, source)) {
        | Ok(data) => Lwt.return(data)
        | Error(reason) => Lwt.fail(Error.PackError(reason))
        };

      /* module also depends on the filenames used to transpile it*/
      add_build_dependencies(graph, build_dependencies, location);

      let%lwt files =
        Lwt_list.map_s(
          filename => {
            /* TODO: No point in keeping these files in cache */
            let%lwt content = Cache.File.readExisting(filename, ctx.cache);
            Lwt.return((
              FS.relative_path(ctx.tmpOutputDir, filename),
              content,
            ));
          },
          files,
        );

      let%lwt (m, _) = make_module(location, source);
      let%lwt build_dependencies =
        recordBuildDependencies(self_dependency @ build_dependencies);

      Lwt.return((
        {
          ...m,
          warnings,
          module_type,
          scope,
          exports,
          build_dependencies,
          files,
        },
        Dependencies(static_dependencies, dynamic_dependencies),
      ));
    };
  };

  switch (location) {
  | Module.File(_) =>
    switch%lwt (Cache.getModule(location, ctx.cache)) {
    | Some((m: Module.t)) =>
      add_build_dependencies(
        graph,
        m.build_dependencies |> M.bindings |> List.map(fst),
        m.location,
      );
      Lwt.return((m, NoDependendencies));
    | None => process_source()
    }
  | _ => process_source()
  };
};

let build = (ctx: Context.t, startLocation: Module.location, graph: t) => {
  /* Gather dependencies */
  let rec process = (~seen: Module.LocationSet.t, location: Module.location) => {
    let read = (location, source) =>
      Worker.Reader.read(~location, ~source, ctx.reader);
    add_module_parents(graph, location, seen);
    ensureModule(
      graph,
      location,
      () => {
        let%lwt (m, deps) =
          Lwt.no_cancel(read_module(~ctx, ~read, ~graph, location));
        let%lwt m =
          switch (deps) {
          | NoDependendencies => Lwt.return(m)
          | Dependencies(static_dependencies, dynamic_dependencies) =>
            let resolve_dependencies =
              Lwt_list.map_s(req => {
                let%lwt (resolved, build_dependencies) = resolve(ctx, req);
                Lwt.return(((req, resolved), build_dependencies));
              });

            let%lwt static_dependencies =
              resolve_dependencies(static_dependencies);
            let%lwt dynamic_dependencies =
              resolve_dependencies(dynamic_dependencies);

            let collect_dependencies = (dependencies, build_dependencies) =>
              Lwt_list.fold_left_s(
                ((resolved, build), (r, b)) => {
                  let%lwt build =
                    Lwt_list.fold_left_s(
                      (build, filename) =>
                        switch%lwt (Cache.File.stat(filename, ctx.cache)) {
                        | Some({Unix.st_mtime, _}) =>
                          Lwt.return(M.add(filename, st_mtime, build))
                        | None =>
                          Lwt.fail(Failure(filename ++ " does not exist"))
                        },
                      build,
                      b,
                    );

                  Lwt.return(([r, ...resolved], build));
                },
                ([], build_dependencies),
                dependencies,
              );

            let build_dependencies = m.build_dependencies;
            let%lwt (static_dependencies, build_dependencies) =
              collect_dependencies(static_dependencies, build_dependencies);

            let%lwt (dynamic_dependencies, build_dependencies) =
              collect_dependencies(dynamic_dependencies, build_dependencies);

            add_build_dependencies(
              graph,
              M.bindings(build_dependencies) |> List.map(fst),
              m.location,
            );

            Lwt.return({
              ...m,
              static_dependencies: List.rev(static_dependencies),
              dynamic_dependencies: List.rev(dynamic_dependencies),
              build_dependencies,
            });
          };

        let updateGraph = (~kind, dependencies) => {
          let%lwt () =
            Lwt_list.iter_p(
              ((_, resolved)) => {
                let%lwt () =
                  switch (hasModule(graph, resolved)) {
                  | false =>
                    let%lwt _ =
                      process(
                        ~seen=Module.LocationSet.add(location, seen),
                        resolved,
                      );
                    Lwt.return_unit;
                  | true => Lwt.return_unit
                  };
                Lwt.return_unit;
              },
              dependencies,
            );

          List.iter(
            ((req, resolved)) =>
              add_dependency(~kind, graph, m, (req, resolved)),
            dependencies,
          );
          Lwt.return_unit;
        };

        let%lwt () = updateGraph(~kind=`Static, m.static_dependencies);
        let%lwt () = updateGraph(~kind=`Dynamic, m.dynamic_dependencies);
        Lwt.return(m);
      },
    );
  };

  let%lwt _ = process(~seen=Module.LocationSet.empty, startLocation);
  Lwt.return_unit;
};
