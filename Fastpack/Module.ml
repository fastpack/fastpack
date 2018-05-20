module M = Map.Make(String)
module StringSet = Set.Make(String)
module FS = FastpackUtil.FS


type state = Initial
           | Preprocessed
           | Analyzed

type file_location = {
  filename : string option;
  preprocessors: (string * string) list;
} [@@deriving show {with_path = false}]

type location = Main of string list
              | Runtime
              | EmptyModule
              | File of file_location
              [@@deriving show{with_path = false}]

type module_type = | CJS | CJS_esModule | ESM



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
  | Main _ ->
    "$fp$main"
  | File { filename; preprocessors; _ } ->
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
    "$fp$empty"
  | Runtime ->
    "$fp$runtime"

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
  | Main _ ->
    "$fp$main"
  | EmptyModule ->
    "$fp$empty"
  | Runtime ->
    "$fp$runtime"
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

let is_internal request =
  request = "$fp$empty" || request = "$fp$runtime" || request = "$fp$main"

let resolved_file2 ?(preprocessors=[]) filename =
  match filename with
  | Some "$fp$empty" -> EmptyModule
  | Some "$fp$runtime" -> Runtime
  | _ -> File { filename; preprocessors }

let resolved_file filename =
  File {
    filename = Some filename;
    preprocessors = [];
  }

module Dependency = struct
  type t = {
    (** Original request to a dependency *)
    request : string;

    (** The filename this dependency was requested from *)
    requested_from : location;
  }

  let compare = Pervasives.compare


  let to_string ?(dir=None) { request; requested_from } =
    let requested_from =
      location_to_string ~base_dir:dir requested_from
      |> Printf.sprintf " from module: %s"
    in
    Printf.sprintf "'%s'%s" request requested_from
end

module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Pervasives.compare
  end)

module LocationSet = Set.Make(struct
    let compare = Pervasives.compare
    type t = location
  end)

type t = {
  (** Opaque module id *)
  id : string;

  (** Absolute module filename *)
  location : location;

  package : Package.t;

  (** List of resolved dependencies, populated for cached modules *)
  resolved_dependencies : (Dependency.t * location) list;

  (** Mapping of filename to digest *)
  build_dependencies : string M.t;

  (** If module is analyzed when packing *)
  state : state;

  (** CJS / CSJ with __esModule flag / EcmaScript *)
  module_type : module_type;

  (** "side-effect" files to be emitted with module *)
  files : (string * string) list;

  (** Module source along with transformations applied *)
  workspace : (t * t DependencyMap.t) Workspace.t;

  (** Module scope *)
  scope: FastpackUtil.Scope.t;

  (** Module exports *)
  exports: FastpackUtil.Scope.exports;
}
