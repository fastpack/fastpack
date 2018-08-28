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

let re_name = Re_posix.compile_pat("[^A-Za-z0-9_]+");

let to_eval = s => {
  let json = Yojson.to_string(`String(s));
  String.(sub(json, 1, length(json) - 2));
};

type input = {
  location: Module.location,
  source: option(string),
};

type output =
  | Complete(complete)
  | ParseError(list((Loc.t, FlowParser.Parse_error.t)))
  | PreprocessorError(string)
  | UnhandledCondition(string)
  | Traceback(string)
and complete = {
  source: string,
  static_dependencies: list(Module.Dependency.t),
  dynamic_dependencies: list(Module.Dependency.t),
  module_type: Module.module_type,
  scope: Scope.t,
  exports: Scope.exports,
  files: list(string),
  build_dependencies: list(string),
};

let start = (~project_root, ~current_dir, ~output_dir) => {
  let%lwt {Preprocessor.process, finalize, _} =
    Preprocessor.make(~configs=[], ~project_root, ~current_dir, ~output_dir);

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
                      property:
                        E.Member.PropertyIdentifier((_, "__esModule")),
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

  let analyze = (location, source) => {
    let location_str =
      Module.location_to_string(~base_dir=Some(project_root), location);
    let ((_, stmts, _) as program, _) =
      FastpackUtil.Parser.parse_source(source);

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

    let fastpack_require = request =>
      Printf.sprintf(
        "__fastpack_require__(\"%s:%s\")",
        location_str,
        request,
      );

    let fastpack_import = request =>
      Printf.sprintf(
        "__fastpack_import__(/* \"%s:%s\")",
        location_str,
        request,
      );

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
    let ensure_module_var = (~name=None, request) =>
      switch (M.get(request, module_vars^), name) {
      | (Some(var), None) => (var, "")
      | (Some(var), Some(name)) =>
        if (var == name) {
          (var, "");
        } else {
          (var, define_var(name, var));
        }
      | (None, Some(name)) =>
        module_vars := M.add(request, name, module_vars^);
        (name, define_var(name, fastpack_require(request)));
      | (None, None) =>
        let var = {
          n_module := n_module^ + 1;
          let name = Re.replace(~f=_ => "_", re_name, request);
          avoid_name_collision(Printf.sprintf("_%d_%s", n_module^, name));
        };

        module_vars := M.add(request, var, module_vars^);
        (var, define_var(var, fastpack_require(request)));
      };

    let module_default_vars = ref(M.empty);
    let ensure_module_default_var = request =>
      switch (M.get(request, module_default_vars^)) {
      | Some(var) => (var, "")
      | None =>
        let (module_var, module_var_definition) = ensure_module_var(request);
        let var = avoid_name_collision(module_var ++ "__default");
        let expression =
          Printf.sprintf(
            "%s.__esModule ? %s.default : %s",
            module_var,
            module_var,
            module_var,
          );
        module_default_vars := M.add(request, var, module_default_vars^);
        (var, module_var_definition ++ define_var(var, expression));
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

    let patch_imported_name = (~from_request, _, remote) =>
      switch (remote) {
      | "default" =>
        let (default_var, _) = ensure_module_default_var(from_request);

        default_var;
      | _ =>
        let (module_var, _) = ensure_module_var(from_request);
        module_var ++ "." ++ remote;
      };

    let define_local_exports = exports =>
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

    let define_remote_exports = (~request, exports) => {
      let (module_var, module_var_definition) = ensure_module_var(request);

      let exports =
        exports
        |> List.map(((exported, remote)) =>
             switch (remote) {
             | "default" =>
               let (default_var, default_definition) =
                 ensure_module_default_var(request);

               default_definition ++ define_export(exported, default_var);
             | _ => define_export(exported, module_var ++ "." ++ remote)
             }
           )
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
          Mode.Development, /* TODO: this should be fixed*/
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
              () => {
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
                  | false => fastpack_require(dep.request) ++ ";\n"
                  | true =>
                    let (_, module_var_definition) =
                      ensure_module_var(~name=namespace, dep.request);

                    let (_, module_default_var_definition) =
                      switch (default) {
                      | None => ("", "")
                      | Some(_) => ensure_module_default_var(dep.request)
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
            patch_with(loc._end.offset, 0, () =>
              ";" ++ define_local_exports(exports)
            );

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
              source: None,
            }) =>
            patch_loc_with(loc, () =>
              specifiers |> export_from_specifiers |> define_local_exports
            )

          | S.ExportNamedDeclaration({
              exportKind: S.ExportValue,
              declaration: None,
              specifiers:
                Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
              source: Some((_, {value: request, _})),
            }) =>
            let _ = add_dependency(~kind=`Static, request);
            patch_loc_with(loc, () =>
              specifiers
              |> export_from_specifiers
              |> define_remote_exports(~request)
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
              () => {
                let (module_var, module_var_definition) =
                  ensure_module_var(dep.request);

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
              () => {
                let (module_var, module_var_definition) =
                  ensure_module_var(dep.request);
                let updated_exports =
                  Printf.sprintf(
                    "Object.assign(module.exports, __fastpack_require__.omitDefault(%s));",
                    module_var,
                  );

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
          Mode.Development, /* TODO: fix later */
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
          patch_loc_with(loc, () => fastpack_import(dep.request));
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
            patch_loc_with(loc, () => fastpack_require(dep.request));
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
              patch_loc_with(loc, () =>
                patch_imported_name(
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

  let rec parse = () => {
    let%lwt input: Lwt.t(input) = Lwt_io.read_value(Lwt_io.stdin);
    let {location, source} = input;
    let%lwt output =
      Lwt.catch(
        () => {
          let location_str =
            Module.location_to_string(
              ~base_dir=Some(project_root),
              location,
            );
          let%lwt (source, build_dependencies, files) =
            process(location, source);
          let (
            workspace,
            static_dependencies,
            dynamic_dependencies,
            scope,
            exports,
            module_type,
          ) =
            analyze(location, source);
          let%lwt source =
            Workspace.write(
              ~modify=to_eval,
              ~output_channel=Lwt_io.null,
              ~workspace,
              ~ctx=(),
            );
          Lwt.return(
            Complete({
              source:
                source
                ++ Printf.sprintf(
                     "\\n//# sourceURL=fpack:///%s",
                     location_str,
                   ),
              static_dependencies,
              dynamic_dependencies,
              module_type,
              scope,
              exports,
              build_dependencies,
              files,
            }),
          );
        },
        fun
        | FlowParser.Parse_error.Error(args) => Lwt.return(ParseError(args))
        | Preprocessor.Error(message) =>
          Lwt.return(PreprocessorError(message))
        | FastpackUtil.Error.UnhandledCondition(message) =>
          Lwt.return(UnhandledCondition(message))
        | exn =>
          Traceback(Printexc.(to_string(exn) ++ "\n" ++ get_backtrace()))
          |> Lwt.return,
      );
    let%lwt () = Lwt_io.write_value(Lwt_io.stdout, output);
    parse();
  };

  Lwt.finalize(() => parse(), finalize);
};

module Reader = {
  type t = {
    read:
      (~location: Module.location, ~source: option(string)) => Lwt.t(output),
    finalize: unit => Lwt.t(unit),
  };

  let ps_project_root = ref("");
  let ps_output_dir = ref("");
  let pool =
    Lwt_pool.create(
      4,
      ~dispose=
        ((p, _, _)) => {
          p#terminate;
          p#close |> ignore |> Lwt.return;
        },
      () => {
        Logs.debug(x => x("reader created"));
        module FS = FastpackUtil.FS;
        let fpack_binary_path =
          /* TODO: handle on Windows? */
          (
            switch (Sys.argv[0].[0]) {
            | '/'
            | '.' => Sys.argv[0]
            | _ => FileUtil.which(Sys.argv[0])
            }
          )
          |> FileUtil.readlink
          |> FS.abs_path(Unix.getcwd());

        let cmd =
          Printf.sprintf(
            "%s parsing-server --project-root='%s' --output='%s'",
            fpack_binary_path,
            ps_project_root^,
            ps_output_dir^,
          );
        FS.open_process(cmd);
      },
    );

  let make = (~project_root, ~output_dir) => {
    ps_project_root := project_root;
    ps_output_dir := output_dir;

    let read = (~location, ~source) =>
      Lwt_pool.use(
        pool,
        ((_, fp_in_ch, fp_out_ch)) => {
          let%lwt () = Lwt_io.write_value(fp_out_ch, {location, source});
          let%lwt output: Lwt.t(output) = Lwt_io.read_value(fp_in_ch);
          Lwt.return(output);
        },
      );

    Lwt.return({read, finalize: () => Lwt_pool.clear(pool)});
  };
};
