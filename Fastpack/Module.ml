module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Dependency.compare
  end)

type t = {
  (** Opaque module id *)
  id : string;

  (** Absolute module filename *)
  filename : string;

  (** Module source along with transformations applied *)
  workspace : t DependencyMap.t Workspace.t;

  (** Module scope *)
  scope: FastpackUtil.Scope.t;
}

(*
 * .js$ => <del>
 * / => $
 * node_modules => NM$
 * @ => AT$$
 * . => $$DOT$$
 * - => $$_$$
 * *)

let make_id filename =
  let suf = ".js" in
  String.(
    (if suffix ~suf filename
     then sub filename 0 (length filename - length suf)
     else filename)
    |> replace ~sub:"node_modules" ~by:"NM$"
    |> replace ~sub:"@" ~by:"AT$$"
    |> replace ~sub:"." ~by:"DOT$$"
    |> replace ~sub:"-" ~by:"$$_$$"
    |> replace ~sub:"/" ~by:"$"
  )

