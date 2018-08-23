module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;
module S = Ast.Statement;
module F = Ast.Function;
module P = Ast.Pattern;
module L = Ast.Literal;
module SL = Ast.StringLiteral;
module M = Map.Make(String);

type scope_type =
  | BlockScope
  | FunctionScope;

type t = {
  parent: option(t),
  bindings: M.t(binding),
}
and binding = {
  typ,
  loc: Loc.t,
  exported: option(list(string)),
  shorthand: bool,
}
and typ =
  | Import(import)
  | Function
  | Argument
  | Class
  | Var
  | Let
  | Const
and import = {
  source: string,
  remote: option(string),
};

type exports = {
  has_default: bool,
  batches: list(string),
  names: M.t(export),
}
and export =
  | Default
  | Own(string, binding)
  | ReExport(import)
  | ReExportNamespace(string);

type reason =
  | NamingCollision(string, Loc.t, Loc.t)
  | PreviouslyUndefinedExport(string);

exception ScopeError(reason);

let error_to_string = (error: reason) => {
  let loc_to_string = ({Loc.start, _end, _}) =>
    Printf.sprintf(
      "(%d:%d) - (%d:%d)",
      start.line,
      start.column,
      _end.line,
      _end.column,
    );

  switch (error) {
  | NamingCollision(name, loc, prev_loc) =>
    Printf.sprintf(
      "Naming Collision: name '%s' at %s is already defined at %s\n",
      name,
      loc_to_string(loc),
      loc_to_string(prev_loc),
    )
  | PreviouslyUndefinedExport(name) =>
    Printf.sprintf("Cannot export previously undefined name '%s'\n", name)
  };
};

let empty = {bindings: M.empty, parent: None};

let empty_exports = {has_default: false, batches: [], names: M.empty};

let string_of_binding = ({typ, loc, exported, _}) =>
  (
    switch (typ) {
    | Import({source, remote}) =>
      let remote =
        switch (remote) {
        | None => "*"
        | Some(n) => n
        };
      Printf.sprintf("Import %s from '%s'", remote, source);
    | Function => "Function"
    | Class => "Class"
    | Argument => "Argument"
    | Var => "Var"
    | Let => "Let"
    | Const => "Const"
    }
  )
  ++ (
    switch (exported) {
    | None => ""
    | Some(names) =>
      Printf.sprintf(" [exported as %s]") @@ String.concat(", ", names)
    }
  )
  ++ Loc.(
       Printf.sprintf(
         " [%d:%d - %d:%d]",
         loc.start.line,
         loc.start.column,
         loc._end.line,
         loc._end.column,
       )
     );

let scope_to_str = (~sep="\n", scope) =>
  scope.bindings
  |> M.bindings
  |> List.map(((name, binding)) =>
       name ++ " -> " ++ string_of_binding(binding)
     )
  |> String.concat(sep);

let name_of_identifier = ((_, name)) => name;

let names_of_pattern = node => {
  let rec names_of_pattern' = (~shorthand=false, names, (_, node)) =>
    switch (node) {
    | P.Object({properties, _}) =>
      let on_property = names => (
        fun
        | P.Object.Property((_, {pattern, shorthand, _})) =>
          names_of_pattern'(~shorthand, names, pattern)
        | P.Object.RestProperty((_, {argument})) =>
          names_of_pattern'(names, argument)
      );

      List.fold_left(on_property, names, properties);
    | P.Array({elements, _}) =>
      let on_element = names => (
        fun
        | None => names
        | Some(P.Array.Element(node)) => names_of_pattern'(names, node)
        | Some(P.Array.RestElement((_, {argument}))) =>
          names_of_pattern'(names, argument)
      );

      List.fold_left(on_element, names, elements);
    | P.Assignment({left, _}) => names_of_pattern'(names, left)
    | P.Identifier({name, _}) => [(name, shorthand), ...names]
    | P.Expression(_) => names
    };
  names_of_pattern'([], node);
};

let export_binding = (name, remote, bindings) =>
  switch (M.get(name, bindings)) {
  | Some({typ: Argument, _}) => Error.ie("Cannot export Argument: " ++ name)
  | Some({exported: None, _} as binding) =>
    M.add(name, {...binding, exported: Some([remote])}, bindings)
  | Some({exported: Some(names), _} as binding) =>
    if (List.mem(remote, names)) {
      Error.ie @@ "Scope > Cannot export twice: " ++ name;
    } else {
      /* Flow parser handles this*/
      M.add(
        name,
        {...binding, exported: Some([remote, ...names])},
        bindings,
      );
    }
  | None => raise @@ ScopeError(PreviouslyUndefinedExport(name))
  };

let update_bindings = (loc, name, typ, shorthand, bindings: M.t(binding)) =>
  switch (M.get(name, bindings), typ) {
  | (None, _)
  | (Some({typ: Argument, _}), _)
  | (Some({typ: Function, _}), Var)
  | (Some({typ: Function, _}), Function)
  | (Some({typ: Var, _}), Var) =>
    M.add(name, {exported: None, loc, typ, shorthand}, bindings)
  | (Some({typ: Var, _}), Function) => bindings
  | (Some({loc: prev_loc, _}), _) =>
    raise @@ ScopeError(NamingCollision(name, loc, prev_loc))
  };

let names_of_node = ((_, node): S.t(Loc.t)) => {
  let type_of_kind = kind =>
    switch (kind) {
    | S.VariableDeclaration.Let => Let
    | S.VariableDeclaration.Const => Const
    | S.VariableDeclaration.Var => Var
    };

  let names_of_declarations = (kind, declarations) => {
    let typ = type_of_kind(kind);
    List.flatten @@
    List.map(
      ((_, {S.VariableDeclaration.Declarator.id, _})) =>
        List.map(
          ((name, shorthand)) => (name, typ, shorthand),
          names_of_pattern(id),
        ),
      declarations,
    );
  };

  switch (node) {
  | S.ImportDeclaration({
      importKind: S.ImportDeclaration.ImportValue,
      source: (_, {value: source, _}),
      specifiers,
      default,
    }) =>
    let names =
      switch (specifiers) {
      | None => []
      | Some(S.ImportDeclaration.ImportNamespaceSpecifier((_, name))) => [
          (name, Import({remote: None, source}), false),
        ]
      | Some(S.ImportDeclaration.ImportNamedSpecifiers(specifiers)) =>
        List.filter_map(
          ({S.ImportDeclaration.kind, local, remote}) =>
            switch (kind) {
            | Some(S.ImportDeclaration.ImportValue)
            | None =>
              let local =
                switch (local) {
                | Some(name) => name
                | None => remote
                };

              Some((
                local,
                Import({remote: Some(name_of_identifier(remote)), source}),
                false,
              ));
            | _ => None
            },
          specifiers,
        )
      };

    switch (default) {
    | None => names
    | Some(name) => [
        (name, Import({remote: Some("default"), source}), false),
        ...names,
      ]
    };
  | S.ClassDeclaration({id: Some(name), _}) => [(name, Class, false)]
  | S.FunctionDeclaration({id: Some(name), _}) => [(name, Function, false)]
  | S.VariableDeclaration({kind, declarations}) =>
    names_of_declarations(kind, declarations)
  | S.For({
      init: Some(S.For.InitDeclaration((_, {declarations, kind}))),
      _,
    }) =>
    names_of_declarations(kind, declarations)
  | S.ForIn({left: S.ForIn.LeftDeclaration((_, {declarations, kind})), _}) =>
    names_of_declarations(kind, declarations)
  | S.ForOf({left: S.ForOf.LeftDeclaration((_, {declarations, kind})), _}) =>
    names_of_declarations(kind, declarations)
  | _ => []
  };
};

let gather_bindings = (~init=None) => {
  let init =
    switch (init) {
    | Some(init) => init
    | None => M.empty
    };

  List.fold_left(
    (bindings, ((loc, name), typ, shorthand)) =>
      update_bindings(loc, name, typ, shorthand, bindings),
    init,
  );
};

let of_statement = (_, (_, stmt) as node, scope) => {
  let bindings =
    switch (stmt) {
    | S.For({
        init:
          Some(
            S.For.InitDeclaration((_, {kind: S.VariableDeclaration.Let, _})),
          ),
        _,
      })
    | S.For({
        init:
          Some(
            S.For.InitDeclaration((
              _,
              {kind: S.VariableDeclaration.Const, _},
            )),
          ),
        _,
      })
    | S.ForIn({
        left:
          S.ForIn.LeftDeclaration((_, {kind: S.VariableDeclaration.Let, _})),
        _,
      })
    | S.ForIn({
        left:
          S.ForIn.LeftDeclaration((
            _,
            {kind: S.VariableDeclaration.Const, _},
          )),
        _,
      })
    | S.ForOf({
        left:
          S.ForOf.LeftDeclaration((_, {kind: S.VariableDeclaration.Let, _})),
        _,
      })
    | S.ForOf({
        left:
          S.ForOf.LeftDeclaration((
            _,
            {kind: S.VariableDeclaration.Const, _},
          )),
        _,
      }) =>
      names_of_node(node) |> gather_bindings

    | _ => M.empty
    };

  if (bindings !== M.empty) {
    {bindings, parent: Some(scope)};
  } else {
    scope;
  };
};

let of_function_block = stmts => {
  let bindings = ref(M.empty);

  let add_bindings = node =>
    List.iter((((loc, name), typ, shorthand)) =>
      bindings := update_bindings(loc, name, typ, shorthand, bindings^)
    ) @@
    names_of_node(node);

  let exports = ref({has_default: false, batches: [], names: M.empty});

  /* TODO: rework */
  let future_exports = ref([]);

  let export_bindings = exports =>
    future_exports := [exports, ...future_exports^];

  let complete_exports = () =>
    future_exports^
    |> List.rev
    |> List.iter(e =>
         List.iter(
           ((name, remote)) => {
             bindings := export_binding(name, remote, bindings^);
             switch (M.get(name, bindings^)) {
             | None =>
               Error.ie("Binding should exist at this point: " ++ name)
             | Some(binding) =>
               exports :=
                 {
                   ...exports^,
                   names: M.add(remote, Own(name, binding), exports^.names),
                 }
             };
           },
           e,
         )
       );

  let add_reexports = source =>
    List.iter(
      (
        (
          _,
          {
            S.ExportNamedDeclaration.ExportSpecifier.local: (_, name),
            exported,
          },
        ),
      ) => {
      let exported =
        switch (exported) {
        | Some((_, name)) => name
        | None => name
        };

      exports :=
        {
          ...exports^,
          names:
            M.add(
              exported,
              ReExport({source, remote: Some(name)}),
              exports^.names,
            ),
        };
    });

  let add_batch = source =>
    exports := {...exports^, batches: [source, ...exports^.batches]};

  let level = ref(0);

  let enter_statement = (_ctx, _) => level := level^ + 1;

  let leave_statement = (_ctx, _) => level := level^ - 1;

  let visit_statement = (visit_ctx, (_, stmt) as node) =>
    switch (stmt) {
    | S.ImportDeclaration({importKind: S.ImportDeclaration.ImportValue, _}) =>
      add_bindings(node);
      Visit.Break;

    | S.ClassDeclaration(_) =>
      if (level^ == 1) {
        add_bindings(node);
      };
      Visit.Break;

    | S.FunctionDeclaration(_) =>
      add_bindings(node);
      Visit.Break;

    | S.VariableDeclaration({kind, _}) =>
      let () =
        switch (kind, level^) {
        | (S.VariableDeclaration.Let, 1)
        | (S.VariableDeclaration.Const, 1)
        | (S.VariableDeclaration.Var, _) => add_bindings(node)
        | _ => ()
        };
      Visit.Break;

    | S.For({
        init:
          Some(
            S.For.InitDeclaration((_, {kind: S.VariableDeclaration.Var, _})),
          ),
        _,
      })
    | S.ForIn({
        left:
          S.ForIn.LeftDeclaration((_, {kind: S.VariableDeclaration.Var, _})),
        _,
      })
    | S.ForOf({
        left:
          S.ForOf.LeftDeclaration((_, {kind: S.VariableDeclaration.Var, _})),
        _,
      }) =>
      add_bindings(node);
      Visit.Continue(visit_ctx);

    | S.ExportDefaultDeclaration({
        declaration: S.ExportDefaultDeclaration.Declaration(declaration),
        _,
      }) =>
      let names =
        List.map((((_, name), _, _)) => (name, "default")) @@
        names_of_node(declaration);

      exports := {...exports^, has_default: true};
      add_bindings(declaration);
      export_bindings(names);
      Visit.Break;

    | S.ExportDefaultDeclaration(_) =>
      exports := {...exports^, has_default: true};
      Visit.Break;

    /* export let x = 1; */
    /* export class X {}; */
    /* export function x() {}; */
    | S.ExportNamedDeclaration({
        exportKind: S.ExportValue,
        declaration: Some(declaration),
        source: None,
        _,
      }) =>
      let names =
        List.map((((_, name), _, _)) => (name, name)) @@
        names_of_node(declaration);

      add_bindings(declaration);
      export_bindings(names);
      Visit.Break;

    /* export {x, y as z}; */
    | S.ExportNamedDeclaration({
        exportKind: S.ExportValue,
        specifiers:
          Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
        source: None,
        _,
      }) =>
      let names =
        List.map(
          (
            (
              _,
              {
                S.ExportNamedDeclaration.ExportSpecifier.local: (_, local),
                exported,
              },
            ),
          ) => (
            local,
            switch (exported) {
            | Some((_, name)) => name
            | _ => local
            },
          ),
          specifiers,
        );

      export_bindings(names);
      Visit.Break;

    /* export {x, y as z} from './other'; */
    | S.ExportNamedDeclaration({
        exportKind: S.ExportValue,
        declaration: None,
        specifiers:
          Some(S.ExportNamedDeclaration.ExportSpecifiers(specifiers)),
        source: Some((_, {value: source, _})),
      }) =>
      add_reexports(source, specifiers);
      Visit.Break;

    | S.ExportNamedDeclaration({
        exportKind: S.ExportValue,
        declaration: None,
        specifiers:
          Some(
            S.ExportNamedDeclaration.ExportBatchSpecifier(
              _,
              Some((_, name)),
            ),
          ),
        source: Some((_, {value: source, _})),
      }) =>
      exports :=
        {
          ...exports^,
          names: M.add(name, ReExportNamespace(source), exports^.names),
        };
      Visit.Break;

    | S.ExportNamedDeclaration({
        exportKind: S.ExportValue,
        declaration: None,
        specifiers:
          Some(S.ExportNamedDeclaration.ExportBatchSpecifier(_, None)),
        source: Some((_, {value: source, _})),
      }) =>
      add_batch(source);
      Visit.Break;

    | _ => Visit.Continue(visit_ctx)
    };

  let visit_expression = (_, _) => Visit.Break;

  let handler = {
    ...Visit.default_visit_handler,
    visit_statement,
    visit_expression,
    enter_statement,
    leave_statement,
  };
  let () = Visit.visit(handler, ([], stmts, []));

  complete_exports();
  (bindings^, exports^);
};

let of_block = (parents, (_: Loc.t, {S.Block.body}) as block, scope) => {
  let bindings =
    switch (parents) {
    | []
    | [AstParentStack.Function(_), ..._] =>
      let (bindings, _) = of_function_block(body);
      bindings;
    | _ =>
      let init =
        switch (parents) {
        | [
            AstParentStack.Statement((
              _,
              S.Try({
                handler: Some((_, {S.Try.CatchClause.body, param})),
                _,
              }),
            )),
            ..._,
          ]
            when body == block =>
          names_of_pattern(param)
          |> List.map(((id, shorthand)) => (id, Let, shorthand))
          |> gather_bindings
        | _ => M.empty
        };

      body
      |> List.map(((_, stmt) as node) =>
           switch (stmt) {
           | S.ClassDeclaration(_)
           | S.VariableDeclaration({kind: S.VariableDeclaration.Let, _})
           | S.VariableDeclaration({kind: S.VariableDeclaration.Const, _}) =>
             names_of_node(node)
           | _ => []
           }
         )
      |> List.concat
      |> gather_bindings(~init=Some(init));
    };

  {bindings, parent: Some(scope)};
};

let of_function = (_, (_, {F.params: (_, {params, rest}), _}), scope) => {
  let bindings =
    gather_bindings @@
    List.map(((id, shorthand)) => (id, Argument, shorthand)) @@
    List.flatten @@
    List.append(
      List.map(names_of_pattern, params),
      switch (rest) {
      | Some((_, {F.RestElement.argument})) => [names_of_pattern(argument)]
      | None => []
      },
    );

  {bindings, parent: Some(scope)};
};

let of_program = stmts => {
  let (bindings, exports) = of_function_block(stmts);
  let scope = {bindings, parent: Some(empty)};
  let exports =
    if (exports.has_default && !M.mem("default", exports.names)) {
      {...exports, names: M.add("default", Default, exports.names)};
    } else {
      exports;
    };

  (scope, exports);
};

let rec get_binding = (name, {bindings, parent, _}) => {
  let binding = M.get(name, bindings);
  switch (binding, parent) {
  | (None, Some(parent)) => get_binding(name, parent)
  | _ => binding
  };
};

let has_binding = (name, scope) => get_binding(name, scope) !== None;

let bindings = scope => scope.bindings |> M.bindings;

let iter = (f, scope) => scope.bindings |> M.bindings |> List.iter(f);

let fold_left = (f, acc, scope) =>
  scope.bindings |> M.bindings |> List.fold_left(f, acc);
