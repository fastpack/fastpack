module Loc = FlowParser.Loc
module Scope = FastpackUtil.Scope

type color = Cyan | Red | Black | White;;

let print_with_color str col = 
  let col = match col with 
    | Cyan -> 36 
    | Red -> 31
    | Black -> 30
    | White -> 37
  in
  "\\033[0;" ^ (string_of_int col) ^ "m" ^ str ^ "\\033[0m";;

let get_codeframe (loc:Loc.t) lines = 
  let startLine = max 0 (loc.start.line - 3) in
  let endLine = min (List.length lines) (loc._end.line + 1) in
  let codeframe = (List.filter_map (fun (i,line) -> 
      if startLine <= i  && i <= endLine then 
        Some (i, line) 
      else None
    ) lines) 
  in
  let formatted = List.map (fun (i, line) -> (
        if loc.start.line <= i && i <= loc._end.line then 
          let error_substring = String.sub line (loc.start.column) (loc._end.column - loc.start.column) in
          let colored_error = print_with_color error_substring Red in
          let colored_line = String.replace ~sub:error_substring ~by: colored_error line in
          (print_with_color (string_of_int i) Red) ^ " │ " ^ colored_line  
        else
          (string_of_int i) ^ " │ " ^ line 
      )) codeframe in 
  String.concat "\n" formatted


let split_with_lineno str = 
  let lines = (String.split_on_char '\n' str) in
  lines |> List.mapi (fun i line -> (i + 1, line))

type reason =
  | CannotReadModule of string
  | CannotLeavePackageDir of string
  | CannotResolveModule of (string * Module.Dependency.t)
  | CannotParseFile of string * ((Loc.t * FlowParser.Parse_error.t) list) * string
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

  | CannotParseFile (location_str, errors, source) ->
    let lines = split_with_lineno source in
    let format_error (loc, error) = 
      let error_desc = FlowParser.Parse_error.PP.error error in 
      "--------------------\n"
      ^ error_desc ^ " at " ^ (loc_to_string loc)
      ^ "\n\n"
      ^ (get_codeframe loc lines)
    in
    print_with_color "Parse Error\n" Red 
    ^ print_with_color (location_str ^ "\n\n") Cyan
    ^ (String.concat "\n\n" (List.map format_error errors))
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


