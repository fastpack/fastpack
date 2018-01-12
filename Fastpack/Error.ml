module Loc = FlowParser.Loc

type reason =
  | CannotReadModule of string
  | CannotLeavePackageDir of string
  | CannotResolveModules of Dependency.t list
  | CannotParseFile of string * ((Loc.t * FlowParser.Parse_error.t) list)
  | NotImplemented of Loc.t option * string
  | CannotRenameModuleBinding of Loc.t * string * Dependency.t

let loc_to_string {Loc. start; _end; _} =
  Printf.sprintf "(%d:%d) - (%d:%d):"
    start.line start.column _end.line _end.column

let to_string package_dir error =
  match error with
  | CannotReadModule filename ->
    "Cannot read file: " ^ filename

  | CannotLeavePackageDir filename ->
    Printf.sprintf
      "%s is out of the working directory\n"
      filename

  | CannotResolveModules modules ->
    "Cannot resolve modules:\n\t"
    ^ (String.concat "\n\t"
       @@ List.map (Dependency.to_string ~dir:(Some package_dir)) modules)
    ^ "\n"

  | CannotParseFile (filename, errors) ->
    let format_error (loc, error) =
      loc_to_string loc ^ " " ^ FlowParser.Parse_error.PP.error error
    in
    Printf.sprintf
      "Parse Error\nFile: %s\n\t"
      (String.replace ~sub:(package_dir ^ "/") ~by:"" filename)
    ^ String.concat "\n\t" (List.map format_error errors)
    ^ "\n"

  | NotImplemented (some_loc, message) ->
    let loc =
      match some_loc with
      | Some loc -> loc_to_string loc ^ " "
      | None -> ""
    in
    loc ^ message

  | CannotRenameModuleBinding (loc, id, dep) ->
    Printf.sprintf "
Cannot rename module binding:
%s %s
Import Request: %s
Typically, it means that you are trying to use the name before importing it in
the code.
"
    (loc_to_string loc)
    id
    (Dependency.to_string ~dir:(Some package_dir) dep)

let ie = FastpackUtil.Error.ie
