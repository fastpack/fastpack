module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Dependency.compare
  end)

type t = {
  (** Opaque module id *)
  id : string;

  (** Absolute module filename *)
  filename : string;

  (** Original module source *)
  workspace : t DependencyMap.t Fastpack.Workspace.t option;
}

let make_id filename =
  let digest = Digest.string filename in
  Digest.to_hex digest

