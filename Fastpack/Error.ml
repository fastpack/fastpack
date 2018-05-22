module Loc = FlowParser.Loc
module Scope = FastpackUtil.Scope

type reason =
  | CannotReadModule of string
  | CannotLeavePackageDir of string
  | CannotResolveModule of (string * Module.Dependency.t)
  | CannotParseFile of string * ((Loc.t * FlowParser.Parse_error.t) list)
  | NotImplemented of Loc.t option * string
  | CannotRenameModuleBinding of Loc.t * string * Module.Dependency.t
  | DependencyCycle of string list
  | CannotFindExportedName of string * string
  | ScopeError of Scope.reason
  | PreprocessorError of string
  | UnhandledCondition of string
  | CliArgumentError of string

let loc_to_string {Loc. start; _end; _} =
  Printf.sprintf "(%d:%d) - (%d:%d):"
    start.line start.column _end.line _end.column

let to_string package_dir error =
  match error with
  | UnhandledCondition message ->
    message

  | CliArgumentError message ->
    "CLI argument error: " ^ message

  | CannotReadModule filename ->
    "Cannot read file: " ^ filename

  | CannotLeavePackageDir filename ->
    Printf.sprintf
      "%s is out of the working directory\n"
      filename

  | CannotResolveModule (path, dep) ->
    let dep_str = Module.Dependency.to_string ~dir:(Some package_dir) dep in
    Printf.sprintf
      "\n%s\nWhile processing dependency request:\n\t%s\n"
      path
      dep_str

  | CannotParseFile (location_str, errors) ->
    let format_error (loc, error) =
      loc_to_string loc ^ " " ^ FlowParser.Parse_error.PP.error error
    in
    Printf.sprintf
      "Parse Error\nFile: %s\n\t"
      (String.replace ~sub:(package_dir ^ "/") ~by:"" location_str)
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
    (Module.Dependency.to_string ~dir:(Some package_dir) dep)

  | DependencyCycle filenames ->
    Printf.sprintf "Dependency cycle detected:\n\t%s\n"
    @@ String.concat "\n\t"
    @@ List.map
      (fun filename -> String.replace ~sub:(package_dir ^ "/") ~by:"" filename)
      filenames

  | CannotFindExportedName (name, location_str) ->
    Printf.sprintf
      "Cannot find exported name '%s' in module '%s'\n"
      name
      location_str

  | ScopeError reason ->
    Scope.error_to_string reason

  | PreprocessorError error ->
    error

let ie = FastpackUtil.Error.ie
