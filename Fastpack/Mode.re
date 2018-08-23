module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module P = Ast.Pattern;
module L = Ast.Literal;

module Visit = FastpackUtil.Visit;

type t =
  | Production
  | Development
  | Test;

let to_string = m =>
  switch (m) {
  | Production => "production"
  | Development => "development"
  | Test => "test"
  };

let rec is_matched = (expr, mode) =>
  switch (expr) {
  | (_, E.Logical({operator: E.Logical.Or, left, _})) =>
    is_matched(left, mode)

  | (
      _,
      E.Binary({
        left: (_, E.Literal({value: L.String(value), _})),
        right: (
          _,
          E.Member({
            _object: (
              _,
              E.Member({
                _object: (_, E.Identifier((_, "process"))),
                property: E.Member.PropertyIdentifier((_, "env")),
                computed: false,
                _,
              }),
            ),
            property: E.Member.PropertyIdentifier((_, "NODE_ENV")),
            computed: false,
            _,
          }),
        ),
        operator,
      }),
    )
  | (
      _,
      E.Binary({
        left: (
          _,
          E.Member({
            _object: (
              _,
              E.Member({
                _object: (_, E.Identifier((_, "process"))),
                property: E.Member.PropertyIdentifier((_, "env")),
                computed: false,
                _,
              }),
            ),
            property: E.Member.PropertyIdentifier((_, "NODE_ENV")),
            computed: false,
            _,
          }),
        ),
        right: (_, E.Literal({value: L.String(value), _})),
        operator,
      }),
    ) =>
    switch (operator) {
    | E.Binary.Equal
    | E.Binary.StrictEqual => Some(value == to_string(mode))
    | E.Binary.NotEqual
    | E.Binary.StrictNotEqual => Some(value != to_string(mode))
    | _ => None
    }
  | _ => None
  };

let patch_statement =
    (
      {Workspace.remove, patch_loc, _},
      mode,
      {Visit.parents, _} as visit_ctx,
      (stmt_loc, _),
    ) =>
  switch (parents) {
  | [
      Visit.APS.Statement((
        loc,
        S.If({test, consequent: (consequent_loc, _), alternate}),
      )),
      ..._,
    ] =>
    switch (is_matched(test, mode)) {
    | None => Visit.Continue(visit_ctx)
    | Some(is_matched) =>
      if (consequent_loc == stmt_loc) {
        is_matched ?
          /* patch test & alternate */
          {
            remove(
              loc.Loc.start.offset,
              consequent_loc.Loc.start.offset - loc.Loc.start.offset,
            );
            switch (alternate) {
            | None => ()
            | Some((alternate_loc, _)) =>
              remove(
                consequent_loc.Loc._end.offset,
                alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset,
              )
            };
            Visit.Continue(visit_ctx);
          } :
          {
            /* patch test & consequent */

            let () =
              switch (alternate) {
              | None => patch_loc(loc, "{}")
              | Some((alternate_loc, _)) =>
                remove(
                  loc.Loc.start.offset,
                  alternate_loc.Loc.start.offset - loc.Loc.start.offset,
                )
              };

            Visit.Break;
          };
      } else if (!is_matched) {
        Visit.Continue(visit_ctx);
      } else {
        Visit.Break;
      }
    }
  | _ => Visit.Continue(visit_ctx)
  };

let patch_expression =
    (
      {Workspace.remove, patch_loc, _},
      mode,
      {Visit.parents, _} as visit_ctx,
      (expr_loc, expr),
    ) =>
  switch (parents) {
  | [
      Visit.APS.Expression((
        loc,
        E.Conditional({
          test,
          consequent: (consequent_loc, _),
          alternate: (alternate_loc, _),
        }),
      )),
      ..._,
    ] =>
    switch (is_matched(test, mode)) {
    | None => Visit.Continue(visit_ctx)
    | Some(is_matched) =>
      if (consequent_loc == expr_loc) {
        is_matched ?
          /* patch test & alternate */
          {
            remove(
              loc.Loc.start.offset,
              consequent_loc.Loc.start.offset - loc.Loc.start.offset,
            );
            remove(
              consequent_loc.Loc._end.offset,
              alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset,
            );
            Visit.Continue(visit_ctx);
          } :
          {
            /* patch test & consequent */

            remove(
              loc.Loc.start.offset,
              alternate_loc.Loc.start.offset - loc.Loc.start.offset,
            );
            Visit.Break;
          };
      } else if (!is_matched) {
        Visit.Continue(visit_ctx);
      } else {
        Visit.Break;
      }
    }

  | _ =>
    switch (expr) {
    | E.Member({
        _object: (
          _,
          E.Member({
            _object: (_, E.Identifier((_, "process"))),
            property: E.Member.PropertyIdentifier((_, "env")),
            computed: false,
            _,
          }),
        ),
        property: E.Member.PropertyIdentifier((_, "NODE_ENV")),
        computed: false,
        _,
      }) =>
      patch_loc(expr_loc) @@ "\"" ++ to_string(mode) ++ "\"";
      Visit.Break;
    | _ => Visit.Continue(visit_ctx)
    }
  };
