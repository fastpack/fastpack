type t;

type output = {
  source: string,
  parsedSource: option(Flow_parser.Flow_ast.program(Flow_parser.Loc.t, Flow_parser.Loc.t)),
  warnings: list(string),
  dependencies: list(string),
  files: list(string),
};


exception Error(string);
let make: (
  ~project_root: string,
  ~current_dir: string,
  ~output_dir: string,
  unit
  ) => Lwt.t(t);

let run: (Module.location, option(string), t) => Lwt.t(output)

let finalize: t => Lwt.t(unit);
