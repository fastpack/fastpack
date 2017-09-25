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
  scope: Scope.t;
}

let make_id filename =
  let digest = Digest.string filename in
  Digest.to_hex digest

