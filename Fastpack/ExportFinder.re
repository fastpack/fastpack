module M = Map.Make(String);
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
  get_all: (Module.DependencyMap.t(Module.t), Module.t) => all_exports,
  exists:
    (Module.DependencyMap.t(Module.t), Module.t, string) => export_exists,
};

let make = () => {
  /* infra for unwrapping `export * from 'module';` statements */
  let unwrapped_batches = ref(M.empty);

  /* TODO: track cyclic dependencies */
  let rec unwrap_batches = (dep_map, m: Module.t) => {
    let decorate = (m, exports) =>
      M.map(export => {export, parent_module: m}, exports);

    List.fold_left(
      ({exports, has_cjs}, batch_request) => {
        let dep = {
          Module.Dependency.request: batch_request,
          requested_from: m.location,
        };

        switch (Module.DependencyMap.get(dep, dep_map)) {
        | Some(m) =>
          switch (m.Module.module_type) {
          | Module.ESM =>
            let {has_cjs: batch_has_cjs, exports: batch_exports} =
              get_all(dep_map, m);
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
                        ++ Module.location_to_string(
                             v1.parent_module.location,
                           )
                        ++ ". Module 2: "
                        ++ Module.location_to_string(
                             v2.parent_module.location,
                           ),
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
  and get_all = (dep_map, m: Module.t) =>
    switch (M.get(m.id, unwrapped_batches^)) {
    | Some(exports) => exports
    | None =>
      let m_unwrapped_batches = unwrap_batches(dep_map, m);
      unwrapped_batches :=
        M.add(m.id, m_unwrapped_batches, unwrapped_batches^);
      m_unwrapped_batches;
    };

  let exists = (dep_map, m, name) => {
    let {exports, has_cjs} = get_all(dep_map, m);
    switch (M.get(name, exports)) {
    | Some(_) => Yes
    | None => if (has_cjs) {Maybe} else {No}
    };
  };

  {get_all, exists};
};
