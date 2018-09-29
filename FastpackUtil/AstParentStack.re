module Ast = Flow_parser.Ast;
module Loc = Flow_parser.Loc;
module S = Ast.Statement;
module E = Ast.Expression;
module F = Ast.Function;

type parent =
  | Statement(S.t(Loc.t))
  | Function((Loc.t, F.t(Loc.t)))
  | Block((Loc.t, S.Block.t(Loc.t)))
  | Expression(E.t(Loc.t));

let push_expression = (expr, stack) => [Expression(expr), ...stack];

let push_block = (block, stack) => [Block(block), ...stack];

let push_function = (func, stack) => [Function(func), ...stack];

let push_statement = (stmt, stack) => [Statement(stmt), ...stack];

let rec top_statement = stack =>
  switch (stack) {
  | [] => None
  | [Statement(stmt), ..._] => Some(stmt)
  | [_, ...tl] => top_statement(tl)
  };

let rec top_expression = stack =>
  switch (stack) {
  | [] => None
  | [Expression(expr), ..._] => Some(expr)
  | [_, ...tl] => top_expression(tl)
  };

let rec is_top_level = stack =>
  switch (stack) {
  | [] => true
  | [Expression(_), ...rest]
  | [Statement((_, S.Block(_))), ...rest]
  | [Block(_), ...rest] => is_top_level(rest)
  | _ => false
  };
