module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
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

exception Rebuild(string, Module.location);

let debug = Logs.debug;
let re_name = Re.Posix.compile_pat("[^A-Za-z0-9_]+");

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
      Lwt.fail(Context.PackError(ctx, CannotResolveModule(path, request)))
    | exn => raise(exn),
  );
};

let is_json = (location: Module.location) =>
  switch (location) {
  | Module.File({filename: Some(filename), preprocessors: []}) =>
    String.suffix(~suf=".json", filename)
  | _ => false
  };

let get_module_type = stmts => {
  /* TODO: what if module has only import() expression? */
  let import_or_export = (module_type, (_, stmt): S.t(Loc.t, Loc.t)) =>
    switch (module_type) {
    | Module.ESM
    | Module.CJS_esModule => module_type
    | Module.CJS =>
      switch (stmt) {
      | S.Expression({
          expression: (
            _,
            E.Assignment({
              operator: E.Assignment.Assign,
              left: (
                _,
                P.Expression((
                  _,
                  E.Member({
                    _object: (_, E.Identifier((_, "exports"))),
                    property: E.Member.PropertyIdentifier((_, "__esModule")),
                    computed: false,
                    _,
                  }),
                )),
              ),
              right: (_, E.Literal({value: L.Boolean(true), _})),
            }),
          ),
          _,
        }) => Module.CJS_esModule
      | S.ExportDefaultDeclaration(_)
      | S.ExportNamedDeclaration(_)
      | S.ImportDeclaration(_) => Module.ESM
      | _ => module_type
      }
    };

  List.fold_left(import_or_export, Module.CJS, stmts);
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

let read_module = (~ctx: Context.t, location: Module.location) => {
  /* Logs.debug(x => x("READING: %s", Module.location_to_string(location))); */
  let make_module = (location, source) => {
    let%lwt package =
      switch (location) {
      | Module.EmptyModule
      | Module.Runtime => Lwt.return(Package.empty)
      | Module.Main(_) => Lwt.return(ctx.project_package)
      | Module.File({filename: Some(filename), _}) =>
        find_package_for_filename(ctx.cache, ctx.current_dir, filename)

      | Module.File({filename: None, _}) => Lwt.return(ctx.project_package)
      /* switch (from_module) { */
      /* | None => Lwt.return(ctx.project_package) */
      /* | Some((m: Module.t)) => Lwt.return(m.package) */
      /* } */
      };

    let m =
      Module.{
        id: make_id(ctx.project_root, location),
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
            if (!FilePath.is_subdir(filename, ctx.project_root)) {
              Lwt.fail(
                Context.PackError(ctx, CannotLeavePackageDir(filename)),
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
                let nl_index = String.find(~sub="\n", content);
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
    DependencyGraph.add_build_dependencies(
      ctx.graph,
      self_dependency,
      location,
    );

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
        build_dependencies,
        files,
      } =
        switch%lwt (Worker.Reader.read(~location, ~source, ctx.reader)) {
        | Ok(data) => Lwt.return(data)
        | Error(reason) => Lwt.fail(Context.PackError(ctx, reason))
        };

      /* module also depends on the filenames used to transpile it*/
      DependencyGraph.add_build_dependencies(
        ctx.graph,
        build_dependencies,
        location,
      );

      let%lwt files =
        Lwt_list.map_s(
          filename => {
            let%lwt content = Cache.File.readExisting(filename, ctx.cache);
            Lwt.return((filename, content));
          },
          files,
        );

      let%lwt (m, _) = make_module(location, source);
      let%lwt build_dependencies =
        recordBuildDependencies(self_dependency @ build_dependencies);

      Lwt.return((
        {...m, module_type, scope, exports, build_dependencies, files},
        Dependencies(static_dependencies, dynamic_dependencies),
      ));
    };
  };

  switch (location) {
  | Module.File(_) =>
    switch%lwt (Cache.getModule(location, ctx.cache)) {
    | Some((m: Module.t)) =>
      DependencyGraph.add_build_dependencies(
        ctx.graph,
        m.build_dependencies |> M.bindings |> List.map(fst),
        m.location,
      );
      Lwt.return((m, NoDependendencies));
    | None => process_source()
    }
  | _ => process_source()
  };
};

let build = (ctx: Context.t) => {
  /* TODO: handle this at a higher level, IllegalConfiguration error */
  let%lwt () =
    if (ctx.Context.target == Target.ESM) {
      Lwt.fail(
        Context.PackError(
          ctx,
          NotImplemented(
            None,
            "EcmaScript6 target is not supported "
            ++ "for the regular packer - use flat\n",
          ),
        ),
      );
    } else {
      Lwt.return_unit;
    };

  /* Gather dependencies */
  let rec process = (~seen: Module.LocationSet.t, location: Module.location) => {
    DependencyGraph.add_module_parents(ctx.graph, location, seen);
    DependencyGraph.ensureModule(
      ctx.graph,
      location,
      () => {
        /* let%lwt (m, deps) = read_module(~ctx, location); */
        let%lwt (m, deps) = Lwt.no_cancel(read_module(~ctx, location));
        let graph = ctx.graph;
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
                  switch (DependencyGraph.hasModule(ctx.graph, resolved)) {
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
              DependencyGraph.add_dependency(
                ~kind,
                graph,
                m,
                (req, resolved),
              ),
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

  let%lwt _ = process(~seen=Module.LocationSet.empty, ctx.current_location);
  Lwt.return_unit;
};
