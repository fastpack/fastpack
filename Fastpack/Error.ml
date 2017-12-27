module Loc = FlowParser.Loc

type reason =
  | CannotReadModule of string
  | CannotLeavePackageDir of string
  | CannotResolveModules of Dependency.t list
  | CannotParseFile of string * ((Loc.t * FlowParser.Parse_error.t) list)

let to_string error =
  match error with
  | CannotReadModule filename -> "CannotReadModule: " ^ filename
  | CannotLeavePackageDir _ -> "CannotLeavePackageDir"
  | CannotResolveModules modules ->
    "Cannot resolve modules:\n"
    ^ String.concat "\n\t" (List.map Dependency.to_string modules)
  | CannotParseFile (filename, errors) ->
    let format_error (loc, error) =
      let format_location {Loc. start; _end; _} =
        Printf.sprintf "(%d:%d) - (%d:%d):"
          start.line start.column _end.line _end.column
      in
      format_location loc ^ " " ^ FlowParser.Parse_error.PP.error error
    in
    Printf.sprintf "Parse Error\nFile: %s\n\t" filename
    ^ String.concat "\n\t" (List.map format_error errors)
