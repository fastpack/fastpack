module Loc = FlowParser.Loc;

let ie = FastpackUtil.Error.ie;

type error = (Loc.t, string);
exception TranspilerError(error);

let loc_to_string = ({Loc.start, _end, _}) =>
  Printf.sprintf(
    "(%d:%d) - (%d:%d):",
    start.line,
    start.column,
    _end.line,
    _end.column,
  );

let error_to_string = ((loc, message)) =>
  Printf.sprintf("%s %s", loc_to_string(loc), message);
