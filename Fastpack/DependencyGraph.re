module StringSet = Set.Make(CCString);
exception Cycle(list(string));

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
