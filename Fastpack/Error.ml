
type reason =
  | CannotReadModule of string
  | CannotLeavePackageDir of string
  | CannotResolveModule of Dependency.t
  | ParserError of string * ((Loc.t * Parse_error.t) list)

let to_string error =
  match error with
  | CannotReadModule _ -> "CannotReadModule"
  | CannotLeavePackageDir _ -> "CannotLeavePackageDir"
  | CannotResolveModule _ -> "CannotResolveModule"
  | ParserError (filename, errors) ->
    let format_error (loc, error) =
      let format_location {Loc. start; _end; _} =
        Printf.sprintf "(%d:%d) - (%d:%d):"
          start.line start.column _end.line _end.column
      in
      format_location loc ^ " " ^ Parse_error.PP.error error
    in
    Printf.sprintf "Parse Error\nFile: %s\n\t" filename
    ^ String.concat "\n\t" (List.map format_error errors)
