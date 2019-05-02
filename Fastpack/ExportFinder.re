module M = CCMap.Make(CCString);
module Scope = FastpackUtil.Scope;

type export = {
  export: Scope.export,
  parent_module: Module.t,
};

type all_exports = {
  has_cjs: bool,
  exports: M.t(export),
};

type export_exists =
  | Yes /* truly exists in ESM */
  | Maybe /* there are some re-exports from the CJS */
  | No; /* does not exist in ESM */

type t = {
  unwrapped_batches: Hashtbl.t(string, all_exports),
  dependency_map: Module.DependencyMap.t(Module.t),
};

let make = graph => {
  let%lwt dependency_map = DependencyGraph.to_dependency_map(graph);
  Lwt.return({unwrapped_batches: Hashtbl.create(5000), dependency_map});
};

let rec unwrap_batches = (m: Module.t, finder: t) => {
  let decorate = (m, exports) =>
    M.map(export => {export, parent_module: m}, exports);

  List.fold_left(
    ({exports, has_cjs}, batch_request) => {
      let dep = {
        Module.Dependency.request: batch_request,
        encodedRequest: batch_request,
        requested_from: m.location,
      };

      switch (Module.DependencyMap.get(dep, finder.dependency_map)) {
      | Some(m) =>
        switch (m.Module.module_type) {
        | Module.ESM =>
          let {has_cjs: batch_has_cjs, exports: batch_exports} =
            get_all(m, finder);
          let exports =
            M.merge(
              (key, v1, v2) =>
                switch (v1, v2) {
                | (Some(v1), Some(v2)) =>
                  if (key == "default") {
                    Some(v1);
                  } else {
                    /* TODO: define proper error here */
                    failwith(
                      "ExportFinder > Cannot export twice: "
                      ++ key
                      ++ ". Module 1: "
                      ++ Module.location_to_string(v1.parent_module.location)
                      ++ ". Module 2: "
                      ++ Module.location_to_string(v2.parent_module.location),
                    );
                  }
                | (Some(v), None)
                | (None, Some(v)) => Some(v)
                | (None, None) => None
                },
              exports,
              batch_exports,
            );

          {exports, has_cjs: has_cjs || batch_has_cjs};
        | _ => {exports, has_cjs: true}
        }
      | None => failwith("Cannot find module: " ++ batch_request)
      };
    },
    {
      exports: decorate(m, m.exports.names),
      has_cjs: m.module_type != Module.ESM,
    },
    m.exports.batches,
  );
}
and get_all = (m: Module.t, finder: t) =>
  switch (Hashtbl.find_opt(finder.unwrapped_batches, m.id)) {
  | Some(exports) => exports
  | None =>
    let m_unwrapped_batches = unwrap_batches(m, finder);
    Hashtbl.replace(finder.unwrapped_batches, m.id, m_unwrapped_batches);
    m_unwrapped_batches;
  };

let exists = (m, name, finder) => {
  let {exports, has_cjs} = get_all(m, finder);
  switch (M.get(name, exports)) {
  | Some(_) => Yes
  | None => if (has_cjs) {Maybe} else {No}
  };
};

/* TODO: we can collect all missing exports here */
let ensure_exports = (m: Module.t, finder: t) =>
  m.scope
  |> Scope.bindings
  |> List.fold_left(
       (found, (_, binding)) =>
         switch (found) {
         | Some(_) => found
         | None =>
           switch (binding) {
           | {Scope.typ: Scope.Import({remote: Some(remote), source}), _} =>
             let dep = {
               Module.Dependency.request: source,
               encodedRequest: source,
               requested_from: m.location,
             };
             switch (Module.DependencyMap.get(dep, finder.dependency_map)) {
             | None =>
               failwith(
                 "Something is extremely wrong: resolution error "
                 ++ source
                 ++ " "
                 ++ Module.location_to_string(m.location),
               )
             | Some(m) =>
               switch (exists(m, remote, finder)) {
               | Yes
               | Maybe => None
               | No => Some((m, remote))
               }
             };

           | _ => None
           }
         },
       None,
     );
