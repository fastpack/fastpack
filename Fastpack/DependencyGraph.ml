type t = {
  modules : (string, Module.t) Hashtbl.t;
  dependencies : (string, (Dependency.t * Module.t option)) Hashtbl.t;
  dependents : (string, Module.t) Hashtbl.t;
}

let iter_modules iter graph =
  Hashtbl.iter iter graph.modules

let empty ?(size=200) () = {
  modules = Hashtbl.create size;
  dependencies = Hashtbl.create (size * 20);
  dependents = Hashtbl.create (size * 20);
}

let lookup table key =
  try Some (Hashtbl.find table key) with Not_found -> None

let lookup_module graph filename =
  lookup graph.modules filename

let lookup_dependencies graph (m : Module.t) =
  Hashtbl.find_all graph.dependencies m.filename

let add_module graph (m : Module.t) =
  Hashtbl.add graph.modules m.filename m

let add_dependency graph (m : Module.t) (dep : (Dependency.t * Module.t option)) =
  Hashtbl.add graph.dependencies m.filename dep;
  let (_, dep_module) = dep in
  match dep_module with
  | Some dep_module ->
    Hashtbl.add graph.dependents dep_module.filename m
  | _ ->
    ()
