module Error = Error;
module ReactJSX = ReactJSX;
module StripFlow = StripFlow;
module Class = Class;
module ObjectSpread = ObjectSpread;
module TranspilerRuntimeHelpers = TranspilerRuntimeHelpers;

/** Transpile Ast.program node using a list of transpilers */

let transpile = (transpilers, program) => {
  let context = Context.create();
  let program =
    List.fold_left(
      (program, transpile) => transpile(context, program),
      program,
      transpilers,
    );

  let dependencies = context.get_runtime_helpers();
  if (Context.DependencySet.is_empty(dependencies)) {
    program;
  } else {
    let (loc, stmts, comments) = program;
    (
      loc,
      List.append(
        dependencies
        |> Context.DependencySet.elements
        |> List.map(FastpackUtil.AstHelper.require_runtime),
        stmts,
      ),
      comments,
    );
  };
};

/** Transpile source code using a list of transpilers */

let transpile_source = (transpilers, source) => {
  let (program, _) = FastpackUtil.Parser.parse_source(source);
  FastpackUtil.Printer.print(transpile(transpilers, program));
};
