module FS = FastpackUtil.FS

module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Dependency.compare
  end)

type state = Initial
           | Preprocessed
           | Analyzed

type file_location = {
  filename : string option;
  preprocessors: (string * string) list;
}

type location = Unknown
              | Runtime
              | EmptyModule
              | File of file_location


type t = {
  (** Opaque module id *)
  id : string;

  (** Absolute module filename *)
  location : location;

  (** List of resolved dependencies, populated for cached modules *)
  resolved_dependencies : (Dependency.t * location) list;

  (** If module is analyzed when packing *)
  state : state;

  (** EcmaScript Module *)
  es_module : bool;

  (** Module source along with transformations applied *)
  workspace : t DependencyMap.t Workspace.t;

  (** Module scope *)
  scope: FastpackUtil.Scope.t;

  (** Module exports *)
  exports: (string * string option * FastpackUtil.Scope.binding) list;
}

let debug = Logs.debug
(*
 * .js$ => <del>
 * / => $
 * node_modules => NM$
 * @ => AT$$
 * . => $$DOT$$
 * - => $$_$$
 * : => $$COLON$$
 * ! => $$B$$
 * ? => $$Q$$
 * = => $$E$$
 * *)

let location_to_string ?(base_dir=None) location =
  let filename_to_string filename =
    match base_dir with
    | None -> filename
    | Some base_dir ->
      match String.get filename 0 with
      | '/' -> FS.relative_path base_dir filename
      | _ -> filename
  in
  match location with
  | Unknown ->
    Error.ie "Should never happen: Unknown module in location_to_string"
  | File { filename; preprocessors } ->
    let preprocessors =
      preprocessors
      |> List.map
        (fun (p, opt) ->
          let p = filename_to_string p in
          if opt <> "" then p ^ "?" ^ opt else p
        )
      |> String.concat "!"
    in
    let filename =
      match filename with
      | Some filename -> filename_to_string filename
      | None -> ""
    in
    if preprocessors <> "" then preprocessors ^ "!" ^ filename else filename
  | EmptyModule ->
    "__empty_module__"
  | Runtime ->
    "__fastpack_runtime__"

module CM = Map.Make(Char)

let allowed_chars =
  CM.empty
  |> CM.add '@' "AT$$"
  |> CM.add ':' "$$COLON$$"
  |> CM.add '.' "DOT$$"
  |> CM.add '-' "$$_$$"
  |> CM.add '/' "$"
  |> CM.add '=' "$$E$$"
  |> CM.add '?' "$$Q$$"
  |> CM.add '!' "$$B$$"

let make_id base_dir location =
  match location with
  | Unknown ->
    Error.ie "Should never happen: Unknown module in make_id"
  | EmptyModule ->
    "builtin$$COLON$$__empty_module__"
  | Runtime ->
    "builtin$$COLON$$__fastpack_runtime__"
  | File _ ->
    let fix_chars s =
      let fix_char c =
        let code = Char.code c in
        if (code >= 97 && code <= 122) (* a - z *)
        || (code >= 65 && code <= 90) (* A - Z *)
        || (code >= 48 && code <= 57) (* 0 - 9*)
        || code = 36 (* $ *)
        || code = 95 (* _ *)
        then String.of_char c
        else
          match CM.get c allowed_chars with
          | Some s -> s
          | None -> Printf.sprintf "$$%d$$" code
      in
      s
      |> String.to_array
      |> Array.to_list
      |> List.map fix_char
      |> String.concat ""
    in
    let to_var_name s =
      match s with
      | "builtin" ->
        "builtin"
      | _ ->
        let suf = ".js" in
        String.(
          (if suffix ~suf s then sub s 0 (length s - length suf) else s)
          |> replace ~sub:"node_modules" ~by:"NM$"
          |> fix_chars
        )
    in
    location_to_string ~base_dir:(Some base_dir) location |> to_var_name


let resolved_file filename =
  File {filename = Some filename; preprocessors = []}
