module Util = Util
module Main = Main
module AstMapper = AstMapper

module ReactJSX = ReactJSX
module ObjectSpread = ObjectSpread

(** Transpile Ast.program node using a list of transpilers *)
let transpile transpilers program =
  let context = Context.create () in
  let program = List.fold_left
      (fun program transpile -> transpile context program)
      program
      transpilers
  in
  program

(** Transpile source code using a list of transpilers *)
let transpile_source transpilers source =
  let (program, _errors) = Parser_flow.program_file source None in
  let program = transpile transpilers program in
  Fastpack.Printer.print program
