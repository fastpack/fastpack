open PackerUtil;

module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module L = Ast.Literal;
module P = Ast.Pattern;

module Parser = FastpackUtil.Parser;
module Scope = FastpackUtil.Scope;
module Visit = FastpackUtil.Visit;
module UTF8 = FastpackUtil.UTF8;
module FS = FastpackUtil.FS;

module StringSet = Set.Make(String);
module M = Map.Make(String);
module DM = Map.Make(Module.Dependency);
module MDM = Module.DependencyMap;

let debug = Logs.debug;

type binding_type =
  | Collision;

let pack = (cache: Cache.t, ctx: Context.t, result_channel) => {
  let read_module = read_module(~ctx, ~cache);

  let bytes = Lwt_bytes.create(50_000_000);
  let output_channel = Lwt_io.of_bytes(~mode=Lwt_io.Output, bytes);
  let total_modules = ref(StringSet.empty);
  let has_dynamic_modules = ref(false);

  /* internal top-level bindings in the file */
  let gen_int_binding = (module_id, name) =>
    Printf.sprintf("$i__%s__%s", module_id, name);

  let gen_ext_binding = (module_id, name) =>
    Printf.sprintf("$e__%s__%s", module_id, name);

  let gen_ext_namespace_binding = module_id =>
    Printf.sprintf("$n__%s", module_id);

  let gen_wrapper_binding = location => {
    let module_id = Module.make_id(ctx.current_dir, location);
    Printf.sprintf("$w__%s", module_id);
  };

  /* potential collisions, never appear on the top-level
   * It should be safe to move this generator into the `analyze` function
   * since these names are always scoped
   * */
  let gen_collision_binding = (module_id, name) =>
    Printf.sprintf("$c__%s__%s", module_id, name);

  let may_collide = name =>
    Str.string_match(Str.regexp("^\\$[iewcn]__"), name, 0);

  let rec pack =
          (~with_wrapper=false, ctx: Context.t, entry_location, modules) => {
    debug(m => m("Packing: %s", Module.location_to_string(entry_location)));

    let module_processed =
      modules
      |> MDM.bindings
      |> List.filter_map(((_, m)) =>
           if (m.Module.location == entry_location) {
             Some(m);
           } else {
             None;
           }
         );

    switch (with_wrapper, module_processed) {
    | (true, [m, ..._]) =>
      let wrapper =
        Printf.sprintf(
          "function %s() {return %s.exports;}\n",
          gen_wrapper_binding(entry_location),
          gen_ext_namespace_binding(m.Module.id),
        );

      Lwt_io.write(output_channel, wrapper);

    | _ =>
      let resolved_requests = ref(DM.empty);
      let add_resolved_request = (req, resolved) =>
        resolved_requests := DM.add(req, resolved, resolved_requests^);

      let get_resolved_request = req => DM.get(req, resolved_requests^);

      let has_module = location =>
        modules
        |> MDM.bindings
        |> List.exists(((_, m)) => m.Module.location == location);

      let get_module = location => {
        let matching =
          modules
          |> MDM.bindings
          |> List.filter(((_, m)) => m.Module.location == location);

        switch (matching) {
        | [] => None
        | [(_, m), ..._] => Some(m)
        };
      };

      let name_of_binding =
          (~typ=None, module_id, name, binding: Scope.binding) =>
        switch (typ) {
        | Some(Collision) => gen_collision_binding(module_id, name)
        | None =>
          switch (binding.exported) {
          | Some(exported) =>
            switch (exported, binding.typ) {
            | (["default"], Scope.Function) when name != "default" =>
              gen_int_binding(module_id, name)
            | _ => gen_ext_binding(module_id) @@ String.concat("_", exported)
            }
          | None => gen_int_binding(module_id, name)
          }
        };

      /* Keep track of all dynamic dependencies while packing */
      let dynamic_deps = ref([]);
      let add_dynamic_dep = (ctx, m, request, location) => {
        let dep = {Module.Dependency.request, requested_from: location};

        let () = dynamic_deps := [(ctx, m, dep), ...dynamic_deps^];
        let () = has_dynamic_modules := true;
        dep;
      };

      let rec process = (ctx: Context.t, graph, m: Module.t) => {
        let ctx = {...ctx, current_location: m.location};

        let analyze = (module_id, location, source) => {
          debug(m =>
            m("Analyzing: %s", Module.location_to_string(location))
          );

          let ((_, stmts, _) as program, _) = Parser.parse_source(source);

          let workspace = ref(Workspace.of_string(source));
          let {
                Workspace.patch,
                sub_loc,
                patch_loc,
                patch_with,
                patch_loc_with,
                remove_loc,
                remove,
                _,
              } as patcher =
            Workspace.make_patcher(workspace);

          let patch_binding = (~typ=None, name, binding: Scope.binding) => {
            patch_loc(binding.loc) @@
            name_of_binding(~typ, module_id, name, binding);
            if (binding.shorthand) {
              patch(binding.loc.start.offset, 0) @@ name ++ ": ";
            };
          };

          let (program_scope, exports) = Scope.of_program(stmts);
          /* always add the namespace binding */
          patch(0, 0) @@
          Printf.sprintf(
            "let %s = { id: \"%s\", exports: {}};\n",
            gen_ext_namespace_binding(module_id),
            module_id,
          );

          let () =
            Scope.iter(
              ((name, binding)) =>
                switch (binding.typ) {
                | Scope.Import(_) => ()
                | _ => patch_binding(name, binding)
                },
              program_scope,
            );

          let patch_namespace = (~add_exports=false, loc) => {
            let patch_content =
              gen_ext_namespace_binding(module_id)
              ++ (if (add_exports) {".exports"} else {""});

            patch_loc(loc, patch_content);
          };

          let rec resolve_import = (dep_map, location, source, remote) => {
            let dep = {
              Module.Dependency.request: source,
              requested_from: location,
            };

            let m = MDM.get(dep, dep_map);
            switch (m) {
            | None =>
              raise(
                PackError((ctx, CannotResolveModule((dep.request, dep)))),
              )
            | Some(m) =>
              switch (remote) {
              | None =>
                Printf.sprintf("%s.exports") @@
                gen_ext_namespace_binding(m.Module.id)
              | Some(remote) =>
                switch (
                  Module.(
                    m.module_type == ESM || m.module_type == CJS_esModule
                  ),
                  remote,
                ) {
                | (false, "default") =>
                  Printf.sprintf("%s.exports") @@
                  gen_ext_namespace_binding(m.Module.id)
                | (false, remote) =>
                  Printf.sprintf(
                    "%s.exports.%s",
                    gen_ext_namespace_binding(m.Module.id),
                    remote,
                  )
                | (true, remote) =>
                  /* TODO: this doesn't take into account batch re-exports */
                  switch (M.get(remote, m.exports.Scope.names)) {
                  | None =>
                    if (m.module_type == Module.ESM) {
                      let location_str =
                        Module.location_to_string(
                          ~base_dir=Some(ctx.current_dir),
                          m.location,
                        );

                      raise(
                        PackError((
                          ctx,
                          CannotFindExportedName((remote, location_str)),
                        )),
                      );
                    } else {
                      Printf.sprintf(
                        "%s.exports.%s",
                        gen_ext_namespace_binding(m.id),
                        remote,
                      );
                    }
                  | Some(export) =>
                    switch (export) {
                    | Scope.Default => gen_ext_binding(m.id, "default")
                    | Scope.Own((
                        _,
                        {typ: Scope.Import({source, remote}), _},
                      ))
                    | Scope.ReExport({Scope.remote, source}) =>
                      resolve_import(dep_map, m.location, source, remote)
                    | Scope.Own((_, binding)) =>
                      name_of_binding(m.id, remote, binding)
                    | Scope.ReExportNamespace(_) => failwith("not impl")
                    }
                  }
                }
              }
            };
          };

          let add_exports = es_module => {
            let namespace = gen_ext_namespace_binding(module_id);
            patch_with(
              UTF8.length(source),
              0,
              ((_, dep_map)) => {
                let expr =
                  exports.names
                  |> M.bindings
                  |> List.map(((exported_name, export)) => {
                       let value =
                         switch (export) {
                         | Scope.Default =>
                           gen_ext_binding(module_id, "default")
                         | Scope.ReExport({Scope.remote, source})
                         | Scope.Own((
                             _,
                             {typ: Scope.Import({source, remote}), _},
                           )) =>
                           resolve_import(dep_map, m.location, source, remote)
                         | Scope.Own((internal_name, binding)) =>
                           name_of_binding(module_id, internal_name, binding)
                         | Scope.ReExportNamespace(_) => failwith("not impl")
                         };

                       Printf.sprintf(
                         "%s.exports.%s = %s;\n",
                         namespace,
                         exported_name,
                         value,
                       );
                     })
                  |> String.concat("");

                Printf.sprintf(
                  "\ntry{%s%s.exports.__esModule = %s.exports.__esModule || %s;}catch(_){}\n",
                  expr,
                  namespace,
                  namespace,
                  if (es_module) {"true"} else {"false"},
                );
              },
            );
          };

          let add_target_export = () =>
            patch_with(UTF8.length(source), 0, ((_, dep_map)) =>
              switch (ctx.target) {
              | Target.Application => ""
              | Target.ESM =>
                exports.names
                |> M.bindings
                |> List.map(((exported_name, export)) => {
                     let value =
                       switch (export) {
                       | Scope.Default =>
                         gen_ext_binding(module_id, "default")
                       | Scope.ReExport({Scope.remote, source})
                       | Scope.Own((
                           _,
                           {typ: Scope.Import({source, remote}), _},
                         )) =>
                         resolve_import(dep_map, m.location, source, remote)
                       | Scope.Own((internal_name, binding)) =>
                         name_of_binding(module_id, internal_name, binding)
                       | Scope.ReExportNamespace(_) => failwith("not impl")
                       };

                     if (exported_name == "default") {
                       Printf.sprintf("export default %s;\n", value);
                     } else {
                       Printf.sprintf(
                         "export {%s as %s};\n",
                         value,
                         exported_name,
                       );
                     };
                   })
                |> String.concat("")
              | Target.CommonJS =>
                Printf.sprintf("module.exports = %s.exports;\n") @@
                gen_ext_namespace_binding(module_id)
              }
            );

          /* Static dependencies */
          let static_deps = ref([]);
          let add_static_dep = request => {
            let dep = {Module.Dependency.request, requested_from: location};

            static_deps := [dep, ...static_deps^];
            dep;
          };

          let used_imports =
            ref(
              Scope.fold_left(
                (used_imports, (name, binding)) =>
                  switch (binding.typ) {
                  | Scope.Import({source, _}) =>
                    M.add(name, (source, false), used_imports)
                  | _ => used_imports
                  },
                M.empty,
                program_scope,
              ),
            );
          let use_name = name =>
            switch (M.get(name, used_imports^)) {
            | Some((source, _)) =>
              used_imports := M.add(name, (source, true), used_imports^)
            | None => ()
            };

          let scopes = ref([program_scope]);
          let collisions = ref([M.empty]);
          let top_scope = () => List.hd(scopes^);
          let top_collisions = () => List.hd(collisions^);

          let push_scope = scope => {
            let scope_collisions =
              Scope.fold_left(
                (acc, (name, binding)) => {
                  let update_acc = () => {
                    let () =
                      patch_binding(~typ=Some(Collision), name, binding);
                    M.add(name, binding, acc);
                  };

                  if (may_collide(name)) {
                    switch (M.get(name, acc)) {
                    | None => update_acc()
                    | Some(prev_binding) when prev_binding.loc != binding.loc =>
                      update_acc()
                    | _ => acc
                    };
                  } else {
                    acc;
                  };
                },
                top_collisions(),
                scope,
              );

            /* let () = print_col (top_collisions ()) in */
            /* let () = print_col scope_collisions in */
            collisions := [scope_collisions, ...collisions^];
            scopes := [scope, ...scopes^];
          };

          let pop_scope = () => {
            collisions := List.tl(collisions^);
            scopes := List.tl(scopes^);
          };

          let get_top_level_binding = name => {
            let binding = Scope.get_binding(name, top_scope());
            switch (binding) {
            | None => None
            | Some(b) =>
              let top_level_binding = Scope.get_binding(name, program_scope);
              switch (top_level_binding) {
              | Some(top_level) =>
                if (b === top_level) {
                  Some(b);
                } else {
                  None;
                }
              | None => None
              };
            };
          };

          let patch_identifier = ((loc, name)) =>
            switch (get_top_level_binding(name)) {
            | Some(binding) =>
              use_name(name);
              patch_loc_with(loc, ((_, dep_map)) =>
                switch (binding.typ) {
                | Scope.Import({source, remote}) =>
                  resolve_import(dep_map, location, source, remote)
                | _ => name_of_binding(module_id, name, binding)
                }
              );
            | None =>
              switch (M.get(name, top_collisions())) {
              | Some(binding) =>
                patch_loc(loc) @@
                name_of_binding(
                  ~typ=Some(Collision),
                  module_id,
                  name,
                  binding,
                )
              | None => ()
              }
            };

          let rec patch_pattern = ((_, node)) =>
            switch (node) {
            | P.Object({properties, _}) =>
              let on_property = (
                fun
                | P.Object.Property((loc, {pattern, shorthand, _})) => {
                    if (shorthand) {
                      patch(loc.Loc.start.offset, 0) @@ sub_loc(loc) ++ ": ";
                    };
                    patch_pattern(pattern);
                  }
                | P.Object.RestProperty((_, {argument})) =>
                  patch_pattern(argument)
              );

              List.iter(on_property, properties);
            | P.Array({elements, _}) =>
              let on_element = (
                fun
                | None => ()
                | Some(P.Array.Element(node)) => patch_pattern(node)
                | Some(P.Array.RestElement((_, {argument}))) =>
                  patch_pattern(argument)
              );

              List.iter(on_element, elements);
            | P.Assignment({left, _}) => patch_pattern(left)
            | P.Identifier({name, _}) => patch_identifier(name)
            | P.Expression(_) => ()
            };

          let patch_dynamic_dep = (loc, dep, require) =>
            patch_loc_with(loc, _ =>
              switch (get_resolved_request(dep)) {
              | None =>
                Error.ie("At this point dependency should be resolved")
              | Some(Module.EmptyModule)
              | Some(Module.Runtime) =>
                Error.ie("Unexpected module for the dynamic dependency")
              | Some(location) =>
                let wrapper = gen_wrapper_binding(location);
                Printf.sprintf("%s(%s)", require, wrapper);
              }
            );

          /* Level of statement */
          let stmt_level = ref(0);

          let enter_function = ({Visit.parents, _}, f) =>
            push_scope(Scope.of_function(parents, f, top_scope()));

          let leave_function = (_, _) => pop_scope();

          let enter_block = ({Visit.parents, _}, block) =>
            push_scope(Scope.of_block(parents, block, top_scope()));

          let leave_block = (_, _) => pop_scope();

          let enter_statement = ({Visit.parents, _}, (loc, stmt)) => {
            let () =
              push_scope(
                Scope.of_statement(parents, (loc, stmt), top_scope()),
              );

            switch (stmt, stmt_level^) {
            | (S.Block(_), 0) => ()
            | _ => stmt_level := stmt_level^ + 1
            };
          };

          let leave_statement = (_, (_, stmt)) => {
            let () = pop_scope();
            switch (stmt, stmt_level^) {
            | (S.Block(_), 0) => ()
            | _ => stmt_level := stmt_level^ - 1
            };
          };

          let visit_statement = (visit_ctx, (loc, stmt)) => {
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
              switch (stmt) {
              | S.ImportDeclaration({
                  source: (_, {value: request, _}),
                  specifiers: None,
                  default: None,
                  _,
                }) =>
                let _ = add_static_dep(request);
                remove_loc(loc);
                Visit.Continue(visit_ctx);

              | S.ImportDeclaration(_) =>
                remove_loc(loc);
                Visit.Continue(visit_ctx);

              | S.ExportNamedDeclaration({source: Some((_, {value, _})), _}) =>
                let _ = add_static_dep(value);
                remove_loc(loc);
                Visit.Break;

              | S.ExportNamedDeclaration({
                  specifiers:
                    Some(
                      S.ExportNamedDeclaration.ExportSpecifiers(specifiers),
                    ),
                  _,
                }) =>
                List.iter(
                  (
                    (
                      _,
                      {
                        S.ExportNamedDeclaration.ExportSpecifier.local: (
                          _,
                          local,
                        ),
                        _,
                      },
                    ),
                  ) =>
                    use_name(local),
                  specifiers,
                );
                remove_loc(loc);
                Visit.Break;

              | S.ExportNamedDeclaration({
                  specifiers:
                    Some(S.ExportNamedDeclaration.ExportBatchSpecifier(_)),
                  _,
                }) =>
                remove_loc(loc);
                Visit.Break;

              | S.ExportDefaultDeclaration({
                  declaration:
                    S.ExportDefaultDeclaration.Declaration((
                      expr_loc,
                      S.FunctionDeclaration({id: Some((_, name)), _}),
                    )),
                  _,
                }) =>
                /* TODO: check named class as well */
                remove(
                  loc.Loc.start.offset,
                  expr_loc.Loc.start.offset - loc.Loc.start.offset,
                );
                patch(loc.Loc._end.offset, 0) @@
                Printf.sprintf(
                  ";const %s = %s;",
                  gen_ext_binding(module_id, "default"),
                  gen_int_binding(module_id, name),
                );
                Visit.Continue(visit_ctx);

              | S.ExportDefaultDeclaration({
                  declaration:
                    S.ExportDefaultDeclaration.Declaration((
                      expr_loc,
                      S.FunctionDeclaration(_),
                    )),
                  _,
                })
              | S.ExportDefaultDeclaration({
                  declaration:
                    S.ExportDefaultDeclaration.Declaration((
                      expr_loc,
                      S.ClassDeclaration(_),
                    )),
                  _,
                })
              | S.ExportDefaultDeclaration({
                  declaration:
                    S.ExportDefaultDeclaration.Expression((expr_loc, _)),
                  _,
                }) =>
                patch(
                  loc.Loc.start.offset,
                  expr_loc.Loc.start.offset - loc.Loc.start.offset,
                ) @@
                Printf.sprintf("const %s = ") @@
                gen_ext_binding(module_id, "default");
                Visit.Continue(visit_ctx);

              | S.ExportDefaultDeclaration({
                  declaration:
                    S.ExportDefaultDeclaration.Declaration((stmt_loc, _)),
                  _,
                })
              | S.ExportNamedDeclaration({
                  declaration: Some((stmt_loc, _)),
                  _,
                }) =>
                remove(
                  loc.Loc.start.offset,
                  stmt_loc.Loc.start.offset - loc.Loc.start.offset,
                );
                Visit.Continue(visit_ctx);

              | S.ForIn({left: S.ForIn.LeftPattern(pattern), _})
              | S.ForOf({left: S.ForOf.LeftPattern(pattern), _}) =>
                patch_pattern(pattern);
                Visit.Continue(visit_ctx);

              | _ => Visit.Continue(visit_ctx)
              }
            };
          };

          let visit_expression = (visit_ctx, (loc, expr)) => {
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
              /* patch shorthands, since we will be doing renaming */
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

              /* static imports */
              | E.Call({
                  callee: (_, E.Identifier((_, "require"))),
                  arguments: [
                    E.Expression((
                      _,
                      E.Literal({value: L.String(request), _}),
                    )),
                  ],
                  _,
                }) =>
                if ((!) @@ Scope.has_binding("require", top_scope())) {
                  let dep = add_static_dep(request);
                  patch_loc_with(loc, ((_, dep_map)) =>
                    switch (MDM.get(dep, dep_map)) {
                    | None =>
                      raise(
                        PackError((
                          ctx,
                          CannotResolveModule((dep.request, dep)),
                        )),
                      )
                    | Some(m) =>
                      Printf.sprintf("(%s.exports)") @@
                      gen_ext_namespace_binding(m.id)
                    }
                  );
                };
                Visit.Break;

              | E.Import((_, E.Literal({value: L.String(request), _}))) =>
                let dep = add_dynamic_dep(ctx, m, request, location);
                patch_dynamic_dep(loc, dep, "__fastpack_import__");
                Visit.Break;

              | E.Import(_) =>
                let msg = "import(_) is supported only with the constant argument";

                raise(PackError((ctx, NotImplemented((Some(loc), msg)))));

              /* replace identifiers */
              | E.Identifier((loc, name) as id) =>
                let () =
                  switch (name) {
                  | "module"
                      when !(Scope.has_binding("module") @@ top_scope()) =>
                    patch_namespace(loc)
                  | "exports"
                      when !(Scope.has_binding("exports") @@ top_scope()) =>
                    patch_namespace(~add_exports=true, loc)
                  | _ => patch_identifier(id)
                  };

                Visit.Break;

              | E.Assignment({left, _}) =>
                patch_pattern(left);
                Visit.Continue(visit_ctx);

              | _ => Visit.Continue(visit_ctx)
              }
            };
          };

          let handler = {
            ...Visit.default_visit_handler,
            visit_statement,
            visit_expression,
            enter_statement,
            leave_statement,
            enter_function,
            leave_function,
            enter_block,
            leave_block,
          };
          let module_type = get_module_type(stmts);
          Visit.visit(handler, program);
          add_exports(
            module_type == Module.ESM || module_type == Module.CJS_esModule,
          );
          if (location == ctx.entry_location) {
            add_target_export();
          };

          used_imports^
          |> M.bindings
          |> List.filter_map(((_, (source, used))) =>
               if (used) {
                 Some(source);
               } else {
                 None;
               }
             )
          |> List.iter(source => {
               let _ = add_static_dep(source);
               ();
             });

          (workspace^, static_deps^, program_scope, exports, module_type);
        };

        let source = m.Module.workspace.Workspace.value;
        let (workspace, static_deps, scope, exports, module_type) =
          is_json(m.location) ?
            {
              let workspace =
                Workspace.of_string @@
                Printf.sprintf(
                  "const %s = %s;",
                  gen_ext_namespace_binding(m.id),
                  source,
                );

              (workspace, [], Scope.empty, Scope.empty_exports, Module.CJS);
            } :
            (
              try (analyze(m.id, m.location, source)) {
              | Flow_parser.Parse_error.Error(args) =>
                let location_str = Module.location_to_string(m.location);
                raise(
                  PackError((ctx, CannotParseFile((location_str, args)))),
                );
              | Scope.ScopeError(reason) =>
                raise(PackError((ctx, ScopeError(reason))))
              }
            );

        let m = {...m, workspace, scope, exports, module_type};
        DependencyGraph.add_module(graph, m);

        /* check all static dependecies */
        let%lwt () =
          Lwt_list.iter_s(
            req => {
              let%lwt (resolved, _) = resolve(ctx, req);
              if (has_module(resolved)) {
                let () = add_resolved_request(req, resolved);
                Lwt.return_unit;
              } else {
                let resolved_str = Module.location_to_string(resolved);
                let%lwt dep_module =
                  switch (DependencyGraph.lookup_module(graph, resolved_str)) {
                  | None =>
                    let%lwt m = read_module(~from_module=Some(m), resolved);
                    let%lwt m =
                      process(
                        {...ctx, stack: [req, ...ctx.stack]},
                        graph,
                        m,
                      );

                    let () = add_resolved_request(req, resolved);
                    Lwt.return(m);
                  | Some(m) =>
                    let () = add_resolved_request(req, resolved);
                    Lwt.return(m);
                  };

                let () =
                  DependencyGraph.add_dependency(
                    graph,
                    m,
                    (req, Some(dep_module.location)),
                  );

                Lwt.return_unit;
              };
            },
            static_deps,
          );

        Lwt.return(m);
      };

      let emit = (graph, entry) => {
        let emit = bytes => Lwt_io.write(output_channel, bytes);
        let emit_module = (dep_map, m: Module.t) => {
          debug(m_ =>
            m_("Emitting: %s", Module.location_to_string(m.location))
          );
          let%lwt () = emit_module_files(ctx, m);
          let%lwt () = emit(Printf.sprintf("\n/* %s */\n\n", m.id));
          let%lwt _ =
            Workspace.write(
              ~output_channel,
              ~workspace=m.Module.workspace,
              ~ctx=(m, dep_map),
            );

          Lwt.return_unit;
        };

        let (emit_wrapper_start, emit_wrapper_end) =
          if (with_wrapper) {
            (
              (
                () =>
                  emit @@
                  "\nfunction "
                  ++ gen_wrapper_binding(entry.Module.location)
                  ++ "() {\n"
              ),
              (
                () =>
                  emit @@
                  Printf.sprintf("\nreturn %s.exports;\n}\n") @@
                  gen_ext_namespace_binding(entry.Module.id)
              ),
            );
          } else {
            ((() => emit("")), (() => emit("")));
          };

        let%lwt () = emit_wrapper_start();
        let%lwt modules = {
          let sorted =
            try (DependencyGraph.sort(graph, entry)) {
            | DependencyGraph.Cycle(filenames) =>
              raise(PackError((ctx, DependencyCycle(filenames))))
            };

          sorted
          |> Lwt_list.fold_left_s(
               (dependency_map, m) => {
                 let%lwt () = emit_module(dependency_map, m);
                 resolved_requests^
                 |> DM.bindings
                 |> List.filter(((_, value)) => value == m.location)
                 |> List.fold_left(
                      (acc, (k, _)) => MDM.add(k, m, acc),
                      dependency_map,
                    )
                 |> Lwt.return;
               },
               resolved_requests^
               |> DM.bindings
               |> List.filter(((_, resolved)) => {
                    let resolved_str = Module.location_to_string(resolved);
                    if (has_module(resolved)) {
                      true;
                    } else {
                      switch (
                        DependencyGraph.lookup_module(graph, resolved_str)
                      ) {
                      | Some(m) =>
                        Module.(
                          m.module_type == ESM || m.module_type == CJS_esModule
                        )
                      | None => false
                      };
                    };
                  })
               |> List.fold_left(
                    (modules, (dep, resolved)) => {
                      let resolved_str = Module.location_to_string(resolved);
                      switch (get_module(resolved)) {
                      | Some(m) => MDM.add(dep, m, modules)
                      | None =>
                        switch (
                          DependencyGraph.lookup_module(graph, resolved_str)
                        ) {
                        | Some(m) => MDM.add(dep, m, modules)
                        | None =>
                          Error.ie(
                            "Module should be found. See previous step: "
                            ++ resolved_str,
                          )
                        }
                      };
                    },
                    modules,
                  ),
             );
        };

        let%lwt () = emit_wrapper_end();
        Lwt.return(modules);
      };

      let graph = DependencyGraph.empty();
      let%lwt entry = read_module(entry_location);
      let%lwt entry = process(ctx, graph, entry);
      let%lwt dynamic_deps =
        Lwt_list.map_s(
          ((ctx, _, req)) => {
            let%lwt (resolved, _) = resolve(ctx, req);
            add_resolved_request(req, resolved);
            Lwt.return((ctx, resolved));
          },
          dynamic_deps^,
        );

      let%lwt modules = emit(graph, entry);
      let%lwt _ =
        Lwt_list.fold_left_s(
          (seen, (ctx, resolved)) =>
            switch (resolved) {
            | Module.Runtime
            | Module.EmptyModule => Error.ie("Unexpected dynamic dependency")
            | location =>
              let location_str = Module.location_to_string(location);
              if (StringSet.mem(location_str, seen)) {
                Lwt.return(seen);
              } else {
                let%lwt () = pack(~with_wrapper=true, ctx, location, modules);

                Lwt.return(StringSet.add(location_str, seen));
              };
            },
          StringSet.empty,
          dynamic_deps,
        );

      let new_modules =
        graph
        |> DependencyGraph.modules
        |> Sequence.map(((loc, _)) => loc)
        |> StringSet.of_seq;

      total_modules := StringSet.union(total_modules^, new_modules);
      Lwt.return_unit;
    };
  };

  let {Context.entry_location, _} = ctx;
  let%lwt () = pack(ctx, entry_location, MDM.empty);

  let bundle =
    output_channel
    |> Lwt_io.position
    |> Int64.to_int
    |> Lwt_bytes.extract(bytes, 0)
    |> Lwt_bytes.to_string;

  let (header, footer) =
    switch (ctx.target) {
    | Target.Application => ("(function() {\n", "})()\n")
    | Target.CommonJS => ("", "")
    | Target.ESM => ("", "")
    };

  let dynamic_import_runtime =
    if (has_dynamic_modules^) {
      "var __fastpack_cache__ = {};\n\nfunction __fastpack_import__(f) {\nif (!window.Promise) {\n  throw 'window.Promise is undefined, consider using a polyfill';\n}\nreturn new Promise(function(resolve, reject) {\n  try {\n    if (__fastpack_cache__[f.name] === undefined) {\n      __fastpack_cache__[f.name] = f();\n    }\n    resolve(__fastpack_cache__[f.name]);\n  } catch (e) {\n    reject(e);\n  }\n});\n}\n";
    } else {
      "";
    };

  let%lwt () = Lwt_io.write(result_channel, header);
  let%lwt () = Lwt_io.write(result_channel, dynamic_import_runtime);
  let%lwt () = Lwt_io.write(result_channel, bundle);
  let%lwt () = Lwt_io.write(result_channel, footer);
  Lwt.return({
    Reporter.graph: DependencyGraph.empty(),
    size: Lwt_io.position(result_channel) |> Int64.to_int,
  });
};
