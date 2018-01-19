module StringSet = Set.Make(String)
type t = {
  modules : (string, Module.t) Hashtbl.t;
  dependencies : (string, (Dependency.t * Module.t option)) Hashtbl.t;
  dependents : (string, Module.t) Hashtbl.t;
}

let iter_modules iter graph =
  Hashtbl.iter iter graph.modules

let empty ?(size=2000) () = {
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

exception Cycle of string list

let sort graph entry =
  let modules = ref [] in
  let seen_globally = ref (StringSet.empty) in
  let add_module m =
    modules := m :: !modules;
    seen_globally := StringSet.add m.Module.filename !seen_globally
  in
  let check_module m =
    StringSet.mem m.Module.filename !seen_globally
  in
  let rec sort seen m =
    match List.mem m.Module.filename seen with
    | true ->
      let prev_m =
        match lookup_module graph (List.hd seen) with
        | Some prev_m -> prev_m
        | None -> Error.ie "DependencyGraph.sort - imporssible state"
      in
      if m.Module.es_module && prev_m.Module.es_module
      then ()
      else
        let filenames = m.Module.filename :: seen in
        raise (Cycle filenames)
    | false ->
      match check_module m with
      | true -> ()
      | false ->
        let sort' = sort (m.Module.filename :: seen) in
        let () =
          List.iter
            sort'
            (List.filter_map (fun (_, m) -> m) (lookup_dependencies graph m))
        in
          add_module m;
  in
  begin
    sort [] entry;
    List.rev !modules
  end
