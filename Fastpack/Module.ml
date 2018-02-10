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
 * *)

let make_id base_dir location =
  match location with
  | Unknown ->
    Error.ie "Should never happen: Unknown module in make_id"
  | EmptyModule ->
    "builtin$$COLON$$__empty_module__"
  | Runtime ->
    "builtin$$COLON$$__fastpack_runtime__"
  | File { filename; preprocessors } ->
    let fix_filename filename =
      let filename = FS.relative_path base_dir filename in
      let suf = ".js" in
      String.(
        (if suffix ~suf filename
         then sub filename 0 (length filename - length suf)
         else filename)
        |> replace ~sub:"node_modules" ~by:"NM$"
        |> replace ~sub:"@" ~by:"AT$$"
        |> replace ~sub:":" ~by:"$$COLON$$"
        |> replace ~sub:"." ~by:"DOT$$"
        |> replace ~sub:"-" ~by:"$$_$$"
        |> replace ~sub:"/" ~by:"$"
      )
    in
    let filename =
      match filename with
      | Some filename -> fix_filename filename
      | None -> ""
    in
    let preprocessors =
      preprocessors
      |> List.map
        (fun (p, opt) ->
           let p = fix_filename p in
           if opt <> "" then p ^ "$$Q$$" ^ opt else p
        )
      |> String.concat "$$B$$"
    in
    if preprocessors <> ""
    then preprocessors ^ "$$B$$" ^ filename
    else filename

let location_to_string location =
  match location with
  | Unknown ->
    Error.ie "Should never happen: Unknown module in location_to_string"
  | File { filename; preprocessors } ->
    let preprocessors =
      preprocessors
      |> List.map (fun (p, opt) -> if opt <> "" then p ^ "?" ^ opt else p)
      |> String.concat "!"
    in
    let filename = CCOpt.get_or ~default:"" filename in
    if preprocessors <> ""
    then preprocessors ^ "!" ^ filename
    else filename
  | EmptyModule ->
    "__empty_module__"
  | Runtime ->
    "__fastpack_runtime__"

let resolved_file filename =
  File {filename = Some filename; preprocessors = []}
