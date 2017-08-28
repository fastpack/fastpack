module Util = Util
module Main = Main
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
  program

(** Transpile source code using a list of transpilers *)
let transpile_source transpilers source =
  let parse_options = Some Parser_env.({
      esproposal_class_instance_fields = true;
      esproposal_class_static_fields = true;
      esproposal_decorators = true;
      esproposal_export_star_as = true;
      types = true;
      use_strict = false;
    })
  in
  let (program, _errors) = Parser_flow.program source ~parse_options in
  let program = transpile transpilers program in
  Fastpack.Printer.print program
