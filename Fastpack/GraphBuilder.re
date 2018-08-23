module MLSet = Module.LocationSet;
module StringSet = Set.Make(String);
module M = Map.Make(String);

module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module P = Ast.Pattern;
module L = Ast.Literal;

module UTF8 = FastpackUtil.UTF8;
module FS = FastpackUtil.FS;
module Parser = FastpackUtil.Parser;
module Scope = FastpackUtil.Scope;
module Visit = FastpackUtil.Visit;

let debug = Logs.debug;
let re_name = Re_posix.compile_pat("[^A-Za-z0-9_]+");

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
    () => ctx.resolver.resolve(~basedir, request.request),
    fun
    | Resolver.Error(path) =>
      Lwt.fail(Context.PackError(ctx, CannotResolveModule(path, request)))
    | exn => raise(exn),
  );
};

let is_json = (location: Module.location) =>
  switch (location) {
  | Module.File({filename: Some(filename), _}) =>
    String.suffix(~suf=".json", filename)
  | _ => false
  };

let get_module_type = stmts => {
  /* TODO: what if module has only import() expression? */
  let import_or_export = (module_type, (_, stmt): S.t(Loc.t)) =>
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

let read_module =
    (
      ~from_module=None,
      ~ctx: Context.t,
      ~cache: Cache.t,
      location: Module.location,
    ) => {
  debug(x => x("READING: %s", Module.location_to_string(location)));
  let make_module = (location, source) => {
    let%lwt package =
      switch (location) {
      | Module.EmptyModule
      | Module.Runtime => Lwt.return(Package.empty)
      | Module.Main(_) => Lwt.return(ctx.project_package)
      | Module.File({filename: Some(filename), _}) =>
        let%lwt (package, _) =
          cache.find_package_for_filename(ctx.current_dir, filename);

        Lwt.return(package);
      | Module.File({filename: None, _}) =>
        switch (from_module) {
        | None => Lwt.return(ctx.project_package)
        | Some((m: Module.t)) => Lwt.return(m.package)
        }
      };

    Module.{
      id: make_id(ctx.project_root, location),
      location,
      package,
      static_dependencies: [],
      dynamic_dependencies: [],
      build_dependencies: M.empty,
      module_type: Module.CJS,
      files: [],
      state: Initial,
      workspace: Workspace.of_string(source),
      scope: FastpackUtil.Scope.empty,
      exports: FastpackUtil.Scope.empty_exports,
    }
    |> Lwt.return;
  };

  switch (location) {
  | Module.Main(entry_points) =>
    let source =
      entry_points
      |> List.map(req => Printf.sprintf("import '%s';\n", req))
      |> String.concat("");

    make_module(location, source);

  | Module.EmptyModule => make_module(location, "module.exports = {};")

  | Module.Runtime => make_module(location, FastpackTranspiler.runtime)

  | Module.File({filename, _}) =>
    switch%lwt (cache.get_module(location)) {
    | Some(m) => Lwt.return(m)
    | None =>
      /* filename is Some (abs path) or None at this point */
      let%lwt (source, self_dependency) =
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

          let%lwt ({content, _}, _) =
            Lwt.catch(
              () => cache.get_file(filename),
              fun
              | Cache.FileDoesNotExist(filename) =>
                Lwt.fail(Context.PackError(ctx, CannotReadModule(filename)))
              | exn => raise(exn),
            );

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

          Lwt.return((Some(content), [filename]));
        | None => Lwt.return((None, []))
        };

      let {Preprocessor.process, _} = ctx.preprocessor;
      let%lwt (source, build_dependencies, files) =
        Lwt.catch(
          () => process(location, source),
          fun
          | FlowParser.Parse_error.Error(args) => {
              let location_str = Module.location_to_string(location);
              let src =
                switch (source) {
                | Some(src) => src
                | None => ""
                };
              Lwt.fail(
                Context.PackError(
                  ctx,
                  CannotParseFile((location_str, args, src)),
                ),
              );
            }
          | Preprocessor.Error(message) =>
            Lwt.fail(Context.PackError(ctx, PreprocessorError(message)))
          | FastpackUtil.Error.UnhandledCondition(message) =>
            Lwt.fail(Context.PackError(ctx, UnhandledCondition(message)))
          | exn => Lwt.fail(exn),
        );

      let%lwt files =
        Lwt_list.map_s(
          filename => {
            let%lwt ({content, _}, _) = cache.get_file(filename);
            Lwt.return((filename, content));
          },
          files,
        );

      let%lwt m = make_module(location, source);
      let%lwt build_dependencies =
        Lwt_list.fold_left_s(
          (build_dependencies, filename) => {
            let%lwt ({digest, _}, _) = cache.get_file(filename);
            Lwt.return(M.add(filename, digest, build_dependencies));
          },
          M.empty,
          self_dependency @ build_dependencies,
        );

      let m = {...m, state: Module.Preprocessed, files, build_dependencies};

      let () = cache.modify_content(m, source);
      Lwt.return(m);
    }
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

  let cache = ctx.cache;

  let analyze = (_id, location, source) => {
    let ((_, stmts, _) as program, _) = Parser.parse_source(source);

    module Ast = FlowParser.Ast;
    module Loc = FlowParser.Loc;
    module S = Ast.Statement;
    module E = Ast.Expression;
    module L = Ast.Literal;

    let workspace = ref(Workspace.of_string(source));
    let {
          Workspace.patch,
          patch_with,
          patch_loc,
          patch_loc_with,
          remove,
          remove_loc,
          _,
        } as patcher =
      Workspace.make_patcher(workspace);

    let (program_scope, exports) = Scope.of_program(stmts);
    let scopes = ref([program_scope]);
    let top_scope = () => List.hd(scopes^);
    let push_scope = scope => scopes := [scope, ...scopes^];

    let pop_scope = () => scopes := List.tl(scopes^);

    let get_binding = name => Scope.get_binding(name, top_scope());

    let has_binding = name => Scope.has_binding(name, top_scope());

    let define_var = Printf.sprintf("const %s = %s;");

    let fastpack_require = (id, request) =>
      Printf.sprintf(
        "__fastpack_require__(/* \"%s\" */ \"%s\")",
        request,
        id,
      );

    let fastpack_import = (id, request) =>
      Printf.sprintf("__fastpack_import__(/* \"%s\" */ \"%s\")", request, id);

    let get_module = (dep: Module.Dependency.t, dep_map) =>
      switch (Module.DependencyMap.get(dep, dep_map)) {
      | Some(m) => m
      | None =>
        raise(Context.PackError(ctx, CannotResolveModule(dep.request, dep)))
      };

    let rec avoid_name_collision = (~n=0, name) => {
      let name =
        switch (n) {
        | 0 => name
        | _ => Printf.sprintf("%s_%d", name, n)
        };

      if (!has_binding(name)) {
        name;
      } else {
        avoid_name_collision(~n=n + 1, name);
      };
    };

    let n_module = ref(0);
    let module_vars = ref(M.empty);
    let ensure_module_var = (~name=None, request, m: Module.t) =>
      switch (M.get(m.Module.id, module_vars^), name) {
      | (Some(var), None) => (var, "")
      | (Some(var), Some(name)) =>
        if (var == name) {
          (var, "");
        } else {
          (var, define_var(name, var));
        }
      | (None, Some(name)) =>
        module_vars := M.add(m.id, name, module_vars^);
        (name, define_var(name, fastpack_require(m.id, request)));
      | (None, None) =>
        let var = {
          n_module := n_module^ + 1;
          let name = Re.replace(~f=_ => "_", re_name, request);
          avoid_name_collision(Printf.sprintf("_%d_%s", n_module^, name));
        };

        module_vars := M.add(m.Module.id, var, module_vars^);
        (var, define_var(var, fastpack_require(m.id, request)));
      };

    let module_default_vars = ref(M.empty);
    let ensure_module_default_var = m =>
      switch (M.get(m.Module.id, module_default_vars^)) {
      | Some(var) => (var, "")
      | None =>
        let (module_var, module_var_definition) = ensure_module_var("", m);
        switch (m.module_type) {
        | Module.ESM => (module_var ++ ".default", module_var_definition)
        | Module.CJS
        | Module.CJS_esModule =>
          let var = avoid_name_collision(module_var ++ "__default");
          let expression =
            Printf.sprintf(
              "%s.__esModule ? %s.default : %s",
              module_var,
              module_var,
              module_var,
            );

          module_default_vars := M.add(m.Module.id, var, module_default_vars^);
          (var, module_var_definition ++ define_var(var, expression));
        };
      };

    let static_dependencies = ref([]);
    let dynamic_dependencies = ref([]);
    let add_dependency = (~kind, request) => {
      let dep = {Module.Dependency.request, requested_from: location};
      let () =
        switch (kind) {
        | `Static => static_dependencies := [dep, ...static_dependencies^]
        | `Dynamic => dynamic_dependencies := [dep, ...dynamic_dependencies^]
        };

      dep;
    };

    let ensure_export_exists = (~dep_map, m: Module.t, name) =>
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

    let export_from_specifiers =
      List.map(
        (
          (
            _,
            {
              S.ExportNamedDeclaration.ExportSpecifier.local: (_, local),
              exported,
            },
          ),
        ) => {
        let exported =
          switch (exported) {
          | Some((_, name)) => name
          | None => local
          };

        (exported, local);
      });

    let define_export = (exported, local) =>
      Printf.sprintf(
        "Object.defineProperty(exports, \"%s\", {enumerable: true, get: function() {return %s;}});",
        exported,
        local,
      );

    let patch_imported_name = (~dep_map, ~from_request, _, remote) => {
      let dep = {
        Module.Dependency.request: from_request,
        requested_from: location,
      };

      let m = get_module(dep, dep_map);
      let () = ensure_export_exists(~dep_map, m, remote);
      switch (remote) {
      | "default" =>
        let (default_var, _) = ensure_module_default_var(m);

        default_var;
      | _ =>
        let (module_var, _) = ensure_module_var("", m);

        module_var ++ "." ++ remote;
      };
    };

    let define_local_exports = (~dep_map, exports) =>
      exports
      |> List.map(((exported, local)) => {
           let local =
             switch (get_binding(local)) {
             | Some({
                 typ: Scope.Import({source, remote: Some(remote)}),
                 loc,
                 _,
               }) =>
               patch_imported_name(
                 ~dep_map,
                 ~from_request=source,
                 (loc, local),
                 remote,
               )
             | None =>
               failwith("Cannot export previously undefined name:" ++ local)
             | _ => local
             };

           define_export(exported, local);
         })
      |> String.concat("");

    let define_remote_exports = (~dep_map, ~request, ~from_module, exports) => {
      let (module_var, module_var_definition) =
        ensure_module_var(request, from_module);

      let exports =
        exports
        |> List.map(((exported, remote)) => {
             let () = ensure_export_exists(~dep_map, from_module, remote);
             switch (remote) {
             | "default" =>
               let (default_var, default_definition) =
                 ensure_module_default_var(from_module);

               default_definition ++ define_export(exported, default_var);
             | _ => define_export(exported, module_var ++ "." ++ remote)
             };
           })
        |> String.concat("");

      module_var_definition ++ exports;
    };

    let enter_function = ({Visit.parents, _}, f) =>
      push_scope(Scope.of_function(parents, f, top_scope()));

    let leave_function = (_, _) => pop_scope();

    let enter_block = ({Visit.parents, _}, block) =>
      push_scope(Scope.of_block(parents, block, top_scope()));

    let leave_block = (_, _) => pop_scope();

    let enter_statement = ({Visit.parents, _}, stmt) =>
      push_scope(Scope.of_statement(parents, stmt, top_scope()));

    let leave_statement = (_, _) => pop_scope();

    let visit_statement = (visit_ctx, (loc: Loc.t, stmt)) => {
      let action =
        Mode.patch_statement(
          patcher,
          ctx.Context.mode,
          visit_ctx,
          (loc, stmt),
        );

      switch (action) {
      | Visit.Break => Visit.Break
      | Visit.Continue(visit_ctx) =>
        let _ =
          switch (stmt) {
          | S.ImportDeclaration({
              source: (_, {value: request, _}),
              specifiers,
              default,
              _,
            }) =>
            let dep = add_dependency(~kind=`Static, request);
            patch_with(
              0,
              0,
              ((_, dep_map)) => {
                let m: Module.t = get_module(dep, dep_map);
                let namespace =
                  switch (specifiers) {
                  | Some(
                      S.ImportDeclaration.ImportNamespaceSpecifier((
                        _,
                        (_, name),
                      )),
                    ) =>
                    Some(name)
                  | _ => None
                  };

                let has_names = default != None || specifiers != None;
                let patch =
                  switch (has_names) {
                  /* import 'some'; */
                  | false => fastpack_require(m.id, dep.request) ++ ";\n"
                  | true =>
                    let (_, module_var_definition) =
                      ensure_module_var(~name=namespace, dep.request, m);

                    let (_, module_default_var_definition) =
                      switch (default) {
                      | None => ("", "")
                      | Some(_) => ensure_module_default_var(m)
                      };

                    module_var_definition ++ module_default_var_definition;
                  };

                if (patch == "") {
                  "";
                } else {
                  patch ++ "\n";
                };
              },
            );
            remove_loc(loc);

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: Some((stmt_loc, _) as declaration),
              _,
            }) =>
            let exports =
              Scope.names_of_node(declaration)
              |> List.map((((_, name), _, _)) => (name, name));

            remove(
              loc.start.offset,
              stmt_loc.start.offset - loc.start.offset,
            );
            patch_with(loc._end.offset, 0, ((_, dep_map)) =>
              ";" ++ define_local_exports(~dep_map, exports)
            );

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
              source: None,
            }) =>
            patch_loc_with(loc, ((_, dep_map)) =>
              specifiers
              |> export_from_specifiers
              |> define_local_exports(~dep_map)
            )

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
              source: Some((_, {value: request, _})),
            }) =>
            let dep = add_dependency(~kind=`Static, request);
            patch_loc_with(
              loc,
              ((_, dep_map)) => {
                let m = get_module(dep, dep_map);
                specifiers
                |> export_from_specifiers
                |> define_remote_exports(~dep_map, ~request, ~from_module=m);
              },
            );

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(
                  S.ExportNamedDeclaration.ExportBatchSpecifier(
                    _,
                    Some((_, spec)),
                  ),
                ),
              source: Some((_, {value: request, _})),
            }) =>
            let dep = add_dependency(~kind=`Static, request);
            patch_loc_with(
              loc,
              ((_, dep_map)) => {
                let m = get_module(dep, dep_map);
                let (module_var, module_var_definition) =
                  ensure_module_var(dep.request, m);

                module_var_definition ++ define_export(spec, module_var);
              },
            );

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(S.ExportNamedDeclaration.ExportBatchSpecifier(_, None)),
              source: Some((_, {value: request, _})),
            }) =>
            let dep = add_dependency(~kind=`Static, request);
            patch_loc_with(
              loc,
              ((_, dep_map)) => {
                let m = get_module(dep, dep_map);
                let (module_var, module_var_definition) =
                  ensure_module_var(dep.request, m);

                let updated_exports =
                  switch (m.module_type) {
                  | Module.CJS
                  | Module.CJS_esModule =>
                    Printf.sprintf(
                      "Object.assign(module.exports, __fastpack_require__.omitDefault(%s));",
                      module_var,
                    )
                  | Module.ESM =>
                    let {ExportFinder.exports, _} =
                      ctx.export_finder.get_all(dep_map, m);

                    exports
                    |> M.bindings
                    |> List.filter(((name, _)) => name != "default")
                    |> List.map(((name, _)) =>
                         (name, module_var ++ "." ++ name)
                       )
                    |> List.map(((exported, local)) =>
                         define_export(exported, local)
                       )
                    |> String.concat("");
                  };

                module_var_definition ++ "" ++ updated_exports;
              },
            );

          | S.ExportDefaultDeclaration({
              declaration: S.ExportDefaultDeclaration.Expression(_),
              default,
            })
          | S.ExportDefaultDeclaration({
              declaration:
                S.ExportDefaultDeclaration.Declaration((
                  _,
                  S.FunctionDeclaration({id: None, _}),
                )),
              default,
            })
          | S.ExportDefaultDeclaration({
              declaration:
                S.ExportDefaultDeclaration.Declaration((
                  _,
                  S.ClassDeclaration({id: None, _}),
                )),
              default,
            }) =>
            patch(
              loc.start.offset,
              default._end.offset - loc.start.offset,
              "exports.default =",
            )

          | S.ExportDefaultDeclaration({
              declaration:
                S.ExportDefaultDeclaration.Declaration((
                  expr_loc,
                  S.FunctionDeclaration({id: Some((_, id)), _}),
                )),
              _,
            })
          | S.ExportDefaultDeclaration({
              declaration:
                S.ExportDefaultDeclaration.Declaration((
                  expr_loc,
                  S.ClassDeclaration({id: Some((_, id)), _}),
                )),
              _,
            }) =>
            remove(
              loc.start.offset,
              expr_loc.start.offset - loc.start.offset,
            );
            patch(
              loc._end.offset,
              0,
              Printf.sprintf("\nexports.default = %s;\n", id),
            );

          | _ => ()
          };

        Visit.Continue(visit_ctx);
      };
    };

    let visit_expression = (visit_ctx, (loc: Loc.t, expr)) => {
      let action =
        Mode.patch_expression(
          patcher,
          ctx.Context.mode,
          visit_ctx,
          (loc, expr),
        );

      switch (action) {
      | Visit.Break => Visit.Break
      | Visit.Continue(visit_ctx) =>
        switch (expr) {
        | E.Object({properties}) =>
          properties
          |> List.iter(prop =>
               switch (prop) {
               | E.Object.Property((
                   loc,
                   E.Object.Property.Init({
                     key: E.Object.Property.Identifier((_, name)),
                     shorthand: true,
                     _,
                   }),
                 )) =>
                 patch(loc.Loc.start.offset, 0) @@ name ++ ": "
               | _ => ()
               }
             );
          Visit.Continue(visit_ctx);

        | E.Import((_, E.Literal({value: L.String(request), _}))) =>
          let dep = add_dependency(~kind=`Dynamic, request);
          patch_loc_with(
            loc,
            ((_, dep_map)) => {
              let {Module.id: module_id, _} = get_module(dep, dep_map);
              fastpack_import(module_id, dep.request);
            },
          );
          Visit.Break;

        | E.Call({
            callee: (_, E.Identifier((_, "require"))),
            arguments: [
              E.Expression((_, E.Literal({value: L.String(request), _}))),
            ],
            _,
          }) =>
          if (!has_binding("require")) {
            let dep = add_dependency(~kind=`Static, request);
            patch_loc_with(
              loc,
              ((_, dep_map)) => {
                let {Module.id: module_id, _} = get_module(dep, dep_map);
                fastpack_require(module_id, dep.request);
              },
            );
          };
          Visit.Break;

        | E.Identifier((loc, "require")) =>
          let () =
            if (!has_binding("require")) {
              patch_loc(loc, "__fastpack_require__");
            } else {
              ();
            };

          Visit.Break;

        | E.Identifier((loc, name)) =>
          let () =
            switch (get_binding(name)) {
            | Some({typ: Scope.Import({source, remote: Some(remote)}), _}) =>
              patch_loc_with(loc, ((_, dep_map)) =>
                patch_imported_name(
                  ~dep_map,
                  ~from_request=source,
                  (loc, name),
                  remote,
                )
              )
            | _ => ()
            };
          Visit.Break;

        | _ => Visit.Continue(visit_ctx)
        }
      };
    };

    let module_type = get_module_type(stmts);
    let () =
      if (module_type == Module.ESM) {
        patch(0, 0, "module.exports.__esModule = true;\n");
      } else {
        ();
      };

    let handler = {
      ...Visit.default_visit_handler,
      visit_statement,
      visit_expression,
      enter_function,
      leave_function,
      enter_block,
      leave_block,
      enter_statement,
      leave_statement,
    };

    Visit.visit(handler, program);

    (
      workspace^,
      static_dependencies^,
      dynamic_dependencies^,
      program_scope,
      exports,
      module_type,
    );
  };

  /* Gather dependencies */
  let rec process = (ctx: Context.t, graph, m: Module.t) => {
    let ctx = {...ctx, current_location: m.location};

    /* find module static & dynamic module dependencies
     * both come empty if modules was cached */
    let (m, static_dependencies, dynamic_dependencies) =
      if (m.state != Module.Analyzed) {
        let source = m.Module.workspace.Workspace.value;
        let (
          workspace,
          static_dependencies,
          dynamic_dependencies,
          scope,
          exports,
          module_type,
        ) =
          is_json(m.location) ?
            {
              let workspace =
                Printf.sprintf("module.exports = %s;", source)
                |> Workspace.of_string;

              (
                workspace,
                [],
                [],
                Scope.empty,
                Scope.empty_exports,
                Module.CJS,
              );
            } :
            (
              try (analyze(m.id, m.location, source)) {
              | FlowParser.Parse_error.Error(args) =>
                let location_str = Module.location_to_string(m.location);
                raise(
                  Context.PackError(
                    ctx,
                    CannotParseFile((location_str, args, source)),
                  ),
                );
              | Scope.ScopeError(reason) =>
                raise(Context.PackError(ctx, ScopeError(reason)))
              }
            );

        (
          {...m, workspace, scope, exports, module_type},
          static_dependencies,
          dynamic_dependencies,
        );
      } else {
        (m, [], []);
      };

    let%lwt m =
      if (m.state != Module.Analyzed) {
        let resolve_dependencies =
          Lwt_list.map_p(req => {
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
                  (build, filename) => {
                    let%lwt ({digest, _}, _) = cache.get_file(filename);
                    Lwt.return(M.add(filename, digest, build));
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
      } else {
        Lwt.return(m);
      };

    DependencyGraph.add_module(graph, m);

    let update_graph = (~kind, dependencies) =>
      Lwt_list.iter_s(
        ((req, resolved)) => {
          let%lwt dep_module =
            switch (DependencyGraph.lookup_module(graph, resolved)) {
            | None =>
              let ctx = {...ctx, stack: [req, ...ctx.stack]};
              let%lwt m =
                read_module(~ctx, ~cache, ~from_module=Some(m), resolved);
              process(ctx, graph, m);
            | Some(m) => Lwt.return(m)
            };

          DependencyGraph.add_dependency(
            ~kind,
            graph,
            m,
            (req, dep_module.location),
          );
          Lwt.return_unit;
        },
        dependencies,
      );

    let%lwt () = update_graph(~kind=`Static, m.static_dependencies);
    let%lwt () = update_graph(~kind=`Dynamic, m.dynamic_dependencies);
    Lwt.return(m);
  };

  let {Context.current_location, _} = ctx;
  let%lwt entry = read_module(~ctx, ~cache, current_location);
  let%lwt _ = process(ctx, ctx.graph, entry);
  Lwt.return_unit;
};
