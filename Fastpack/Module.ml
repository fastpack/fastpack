module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Dependency.compare
  end)

type state = Initial
           | Preprocessed
           | Analyzed

type t = {
  (** Opaque module id *)
  id : string;

  (** Absolute module filename *)
  filename : string;

  (** List of resolved dependencies, populated for cached modules *)
  resolved_dependencies : (Dependency.t * string) list;

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
 * *)

let make_id filename =
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

