module Loc = FlowParser.Loc
module Scope = FastpackUtil.Scope

(* 
  assoc list of nodejs libs and their mock implementations
  as listed on: https://github.com/webpack/node-libs-browser
*)
let nodelibs = [
  "assert", "defunctzombie/commonjs-assert";
  "buffer", "feross/buffer";
  "console","Raynos/console-browserify";
  "constants","juliangruber/constants-browserify";
  "crypto","crypto-browserify/crypto-browserify";
  "domain","bevry/domain-browser";
  "events","Gozala/events";
  "http","jhiesey/stream-http";
  "https","substack/https-browserify";
  "os","CoderPuppy/os-browserify";
  "path","substack/path-browserify";
  "process","shtylman/node-process";
  "punycode","bestiejs/punycode.js";
  "querystring","mike-spainhower/querystring";
  "stream","stream";
  "string_decoder","rvagg/string_decoder";
  "sys","defunctzombie/node-util";
  "timers","jryans/timers-browserify";
  "tty","substack/tty-browserify";
  "url","defunctzombie/node-url";
  "util","defunctzombie/node-util";
  "vm","substack/vm-browserify";
  "zlib","devongovett/browserify-zlib";
] 

type color = Cyan | Red | Black | White;;
type font = Regular | Bold;;

let print_with_color ?font:(font=Regular) str col = 
  let col = match col with 
    | Cyan -> "36"
    | Red -> "31"
    | Black -> "30"
    | White -> "37"
  in
  let f = match font with 
    | Regular -> "0"
    | Bold -> "1"
  in
  "\027[" ^ f ^ ";" ^ col ^ "m" ^ str ^ "\027[0m"

let get_codeframe ?(isTTY=false) (loc: Loc.t) lines = 
  let startLine = max 0 (loc.start.line - 2) in
  let endLine = min (List.length lines) (loc._end.line + 1) in
  let codeframe = List.filter_map (fun (i, line) -> 
      if startLine <= i  && i <= endLine then 
        Some (i, line) 
      else None
    ) lines
  in
  let maxLineNo = List.fold_left (fun n (i, _) -> max n i) 0 lines in
  let maxDigits = String.length (string_of_int maxLineNo) in
  let formatted = List.map (fun (i, line) -> 
      let isErrorLine = loc.start.line <= i && i <= loc._end.line in
      let lineNo = String.pad maxDigits (string_of_int i) in
      match isErrorLine, isTTY with
      | false, _ -> lineNo ^ " │ " ^ line 
      | true, false -> 
        let offset, length = (loc.start.column + 1), (loc._end.column - loc.start.column) in
        let whitespaceBeforeBar = String.repeat " " (maxDigits + 1) in
        let whitespaceAfterBar = String.repeat " " offset in
        let carets = String.repeat "^" length in
        lineNo ^ " │ " ^ line ^ "\n" ^ whitespaceBeforeBar ^ "│" ^ whitespaceAfterBar ^ carets
      | true, true -> 
        let error_substring = FastpackUtil.UTF8.sub line (loc.start.column) (loc._end.column - loc.start.column) in
        let colored_error = print_with_color error_substring Red in
        let colored_line = String.replace ~sub:error_substring ~by: colored_error line in
        (print_with_color lineNo Red) ^ " │ " ^ colored_line  
    ) codeframe in 
  String.concat "\n" formatted
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

  | CannotResolveModule (_, dep) ->
    let dep_str = Module.Dependency.to_string ~dir:(Some package_dir) dep in
    let error_msg = "Cannot resolve request for " ^ dep_str in
    (match List.assoc_opt dep.request nodelibs with
     | None -> error_msg ^ "\n"
     | Some mock -> String.concat "\n" [
         error_msg;
         "This looks like base node.js library and unlikely is required in the browser environment.";
         "If you still want to use it, here is the suggested command line option:";
         (Printf.sprintf "--mock %s:%s" dep.request mock);
       ]
    )

  | CannotParseFile (location_str, errors, source) ->
    let isTTY = FastpackUtil.FS.isatty Unix.stderr in
    let lines = String.split_on_char '\n' source
                |> List.mapi (fun i line -> (i + 1, line)) in
    let format_error isTTY (loc, error) = 
      let error_desc = FlowParser.Parse_error.PP.error error in 
      String.concat "\n" [
        "--------------------";
        error_desc ^ " at " ^ (loc_to_string loc);
        "";
        (get_codeframe ~isTTY loc lines);
        ""; 
      ]
    in
    let (error_title, location) = 
      if isTTY then
        (print_with_color "Parse Error\n" Red, 
         print_with_color ~font:Bold location_str Cyan)
      else 
        ("Parse Error\n", location_str) 
    in
    String.concat "\n" [
      error_title ^ location;
      "";
      String.concat "\n" (List.map (format_error isTTY) errors);
      ""; 
    ]

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


