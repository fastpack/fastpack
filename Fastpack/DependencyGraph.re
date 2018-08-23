module M = Map.Make(String);
module StringSet = Set.Make(String);
exception Cycle(list(string));

type t = {
  modules: Hashtbl.t(Module.location, Module.t),
  static_dependencies:
    Hashtbl.t(Module.location, (Module.Dependency.t, Module.location)),
  dynamic_dependencies:
    Hashtbl.t(Module.location, (Module.Dependency.t, Module.location)),
  files: Hashtbl.t(string, Module.t),
};

let empty = (~size=5000, ()) => {
  modules: Hashtbl.create(size),
  static_dependencies: Hashtbl.create(size * 20),
  dynamic_dependencies: Hashtbl.create(size * 20),
  files: Hashtbl.create(size * 5),
};

let lookup = (table, key) => Hashtbl.find_opt(table, key);

let lookup_module = (graph, location) => lookup(graph.modules, location);

let lookup_dependencies = (~kind, graph, m: Module.t) => {
  let dependencies =
    switch (kind) {
    | `Static => Hashtbl.find_all(graph.static_dependencies, m.location)
    | `Dynamic => Hashtbl.find_all(graph.dynamic_dependencies, m.location)
    | `All =>
      Hashtbl.find_all(graph.static_dependencies, m.location)
      @ Hashtbl.find_all(graph.dynamic_dependencies, m.location)
    };

  List.map(
    ((dep, location)) => (dep, lookup_module(graph, location)),
    dependencies,
  );
};

let to_dependency_map = graph => {
  let to_pairs =
    Hashtbl.map_list((_, (dep, location)) =>
      switch (lookup_module(graph, location)) {
      | None => failwith("not good at all, unknown location")
      | Some(m) => (dep, m)
      }
    );

  List.fold_left(
    (dep_map, (dep, m)) => Module.DependencyMap.add(dep, m, dep_map),
    Module.DependencyMap.empty,
    to_pairs(graph.static_dependencies)
    @ to_pairs(graph.dynamic_dependencies),
  );
};

let add_module = (graph, m: Module.t) =>
  switch (Hashtbl.find_all(graph.modules, m.location)) {
  | [] =>
    Hashtbl.add(graph.modules, m.location, m);
    List.iter(
      filename => Hashtbl.add(graph.files, filename, m),
      M.bindings(m.build_dependencies) |> List.map(((k, _)) => k),
    );
  | [_] =>
    Hashtbl.remove(graph.modules, m.location);
    Hashtbl.add(graph.modules, m.location, m);
  | _ => failwith("DependencyGraph: cannot add more modules")
  };

let add_dependency =
    (~kind, graph, m: Module.t, dep: (Module.Dependency.t, Module.location)) => {
  let dependencies =
    switch (kind) {
    | `Static => graph.static_dependencies
    | `Dynamic => graph.dynamic_dependencies
    };

  Hashtbl.add(dependencies, m.location, dep);
};

let remove_module = (graph, m: Module.t) => {
  let remove = (k, v) =>
    if (Module.equal_location(k, m.location)) {
      None;
    } else {
      Some(v);
    };

  let remove_files = (_, m') =>
    if (Module.equal_location(m.location, m'.Module.location)) {
      None;
    } else {
      Some(m);
    };

  Hashtbl.filter_map_inplace(remove, graph.modules);
  Hashtbl.filter_map_inplace(remove, graph.static_dependencies);
  Hashtbl.filter_map_inplace(remove, graph.dynamic_dependencies);
  Hashtbl.filter_map_inplace(remove_files, graph.files);
};

let get_modules_by_filenames = (graph, filenames) =>
  List.fold_left(
    (modules, filename) =>
      List.fold_left(
        (modules, m) => M.add(m.Module.id, m, modules),
        modules,
        Hashtbl.find_all(graph.files, filename),
      ),
    M.empty,
    filenames,
  )
  |> M.bindings
  |> List.map(snd);

/* TODO: make emitted_modules be LocationSet */
let cleanup = (graph, emitted_modules) => {
  let keep = (location, value) =>
    if (Module.LocationSet.mem(location, emitted_modules)) {
      Some(value);
    } else {
      None;
    };

  let () = Hashtbl.filter_map_inplace(keep, graph.modules);
  let () = Hashtbl.filter_map_inplace(keep, graph.static_dependencies);
  let () = Hashtbl.filter_map_inplace(keep, graph.dynamic_dependencies);
  let () =
    Hashtbl.filter_map_inplace(
      (_, m) => keep(m.Module.location, m),
      graph.files,
    );
  graph;
};

let length = graph => Hashtbl.length(graph.modules);

let modules = graph => Hashtbl.to_seq(graph.modules);

let get_static_chain = (graph, entry) => {
  let modules = ref([]);
  let seen_globally = ref(StringSet.empty);
  let add_module = (m: Module.t) => {
    let location_str = Module.location_to_string(m.location);
    modules := [m, ...modules^];
    seen_globally := StringSet.add(location_str, seen_globally^);
  };

  let check_module = (m: Module.t) => {
    let location_str = Module.location_to_string(m.location);
    StringSet.mem(location_str, seen_globally^);
  };

  let rec sort = (seen, m: Module.t) => {
    let location_str = Module.location_to_string(m.location);
    List.mem(location_str, seen) ?
      /* let prev_m = */
      /*   match lookup_module graph (List.hd seen) with */
      /*   | Some prev_m -> prev_m */
      /*   | None -> Error.ie "DependencyGraph.sort - imporssible state" */
      /* in */
      switch (m.module_type) {
      | Module.ESM
      | Module.CJS_esModule => ()
      | Module.CJS => raise(Cycle([location_str, ...seen]))
      } :
      check_module(m) ?
        () :
        {
          let sort' = sort([location_str, ...seen]);
          let () =
            List.iter(
              sort',
              List.filter_map(
                ((_, m)) => m,
                lookup_dependencies(~kind=`Static, graph, m),
              ),
            );

          add_module(m);
        };
  };

  sort([], entry);
  List.rev(modules^);
};
