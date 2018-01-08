module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S= Ast.Statement
module E = Ast.Expression
module F = Ast.Function

type parent = Statement of Loc.t S.t
            | Function of (Loc.t * Loc.t F.t)
            | Block of (Loc.t * Loc.t S.Block.t)
            | Expression of Loc.t E.t

let push_expression expr stack =
  (Expression expr) :: stack

let push_block block stack =
  (Block block) :: stack

let push_function func stack =
  (Function func) :: stack

let push_statement ((_, stmt) as statement) stack =
  match stmt with
  | S.Block _ -> stack
  | _ -> (Statement statement) :: stack
