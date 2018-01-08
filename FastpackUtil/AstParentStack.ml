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

let push_statement stmt stack =
  (Statement stmt) :: stack

let rec top_statement stack =
  match stack with
  | [] -> None
  | (Statement stmt) :: _ -> Some stmt
  | _ :: tl -> top_statement tl

let rec top_expression stack =
  match stack with
  | [] -> None
  | (Expression expr) :: _ -> Some expr
  | _ :: tl -> top_expression tl
