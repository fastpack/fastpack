module Util = Util
module AstHelper = AstHelper
module AstMapper = AstMapper

module ReactJSX = ReactJSX
module StripFlow = StripFlow
module Class = Class
module ObjectSpread = ObjectSpread

(** Transpile Ast.program node using a list of transpilers *)
let transpile transpilers program =
  let context = Context.create () in
  let program = List.fold_left
      (fun program transpile -> transpile context program)
      program
      transpilers
  in
  if not (context.is_runtime_required ())
  then
    program
  else
    let loc, stmts, comments = program in
    (loc, AstHelper.require_runtime :: stmts, comments)


(** Transpile source code using a list of transpilers *)
let transpile_source transpilers source =
  let program, _ = Fastpack.Parser.parse_source source in
  Fastpack.Printer.print (transpile transpilers program)
