module M = Map.Make(String)
module StringSet = Set.Make(String)
exception Cycle of string list

type t = {
  modules : (Module.location, Module.t) Hashtbl.t;
  static_dependencies : (Module.location, (Module.Dependency.t * Module.location)) Hashtbl.t;
  dynamic_dependencies : (Module.location, (Module.Dependency.t * Module.location)) Hashtbl.t;
  files : (string, Module.t) Hashtbl.t;
}

let empty ?(size=5000) () = {
  modules = Hashtbl.create size;
  static_dependencies = Hashtbl.create (size * 20);
  dynamic_dependencies = Hashtbl.create (size * 20);
  files = Hashtbl.create (size * 5);
}


let lookup table key =
  Hashtbl.find_opt table key

let lookup_module graph location =
  lookup graph.modules location

let lookup_dependencies ~kind graph (m : Module.t) =
  let dependencies =
    match kind with
    | `Static -> Hashtbl.find_all graph.static_dependencies m.location
    | `Dynamic -> Hashtbl.find_all graph.dynamic_dependencies m.location
    | `All ->
      (Hashtbl.find_all graph.static_dependencies m.location)
      @ (Hashtbl.find_all graph.dynamic_dependencies m.location)
  in
  List.map
    (fun (dep, location) -> (dep, lookup_module graph location))
    dependencies

let to_dependency_map graph =
  let to_pairs =
    Hashtbl.map_list (fun _ (dep, location) ->
        match lookup_module graph location with
        | None -> failwith "not good at all, unknown location"
        | Some m -> (dep, m)
      )
  in
  List.fold_left
    (fun dep_map (dep, m) -> Module.DependencyMap.add dep m dep_map)
    Module.DependencyMap.empty
    (to_pairs graph.static_dependencies @ to_pairs graph.dynamic_dependencies)


let add_module graph (m : Module.t) =
  match Hashtbl.find_all graph.modules m.location with
  | [] ->
    Hashtbl.add graph.modules m.location m;
    List.iter
      (fun filename -> Hashtbl.add graph.files filename m)
      (M.bindings m.build_dependencies |> List.map (fun (k, _) -> k))
  | _ :: [] ->
    Hashtbl.remove graph.modules m.location;
    Hashtbl.add graph.modules m.location m
  | _ ->
    failwith "DependencyGraph: cannot add more modules"

let add_dependency ~kind graph (m : Module.t) (dep : (Module.Dependency.t * Module.location)) =
  let dependencies =
    match kind with
    | `Static -> graph.static_dependencies
    | `Dynamic -> graph.dynamic_dependencies
  in
  Hashtbl.add dependencies m.location dep

let remove_module graph (m : Module.t) =
  let remove k v =
    if Module.equal_location k m.location then None else Some v
  in
  let remove_files _ m' =
    if Module.equal_location m.location m'.Module.location
    then None
    else Some m
  in
  Hashtbl.filter_map_inplace remove graph.modules;
  Hashtbl.filter_map_inplace remove graph.static_dependencies;
  Hashtbl.filter_map_inplace remove graph.dynamic_dependencies;
  Hashtbl.filter_map_inplace remove_files graph.files

let get_modules_by_filenames graph filenames =
  List.fold_left
    (fun modules filename ->
       List.fold_left
         (fun modules m -> M.add m.Module.id m modules)
         modules
         (Hashtbl.find_all graph.files filename)
    )
    M.empty
    filenames
  |> M.bindings
  |> List.map snd

(* TODO: make emitted_modules be LocationSet *)
let cleanup graph emitted_modules =
  let keep location value =
    if Module.LocationSet.mem location emitted_modules
    then Some value
    else None
  in
  let () = Hashtbl.filter_map_inplace keep graph.modules in
  let () = Hashtbl.filter_map_inplace keep graph.static_dependencies in
  let () = Hashtbl.filter_map_inplace keep graph.dynamic_dependencies in
  let () = Hashtbl.filter_map_inplace (fun _ m -> keep m.Module.location m) graph.files in
  graph

let length graph =
  Hashtbl.length graph.modules

let modules graph =
  Hashtbl.to_seq graph.modules

let get_static_chain graph entry =
  let modules = ref [] in
  let seen_globally = ref (StringSet.empty) in
  let add_module (m : Module.t) =
    let location_str = Module.location_to_string m.location in
    modules := m :: !modules;
    seen_globally := StringSet.add location_str !seen_globally
  in
  let check_module (m : Module.t) =
    let location_str = Module.location_to_string m.location in
    StringSet.mem location_str !seen_globally
  in
  let rec sort seen (m : Module.t) =
    let location_str = Module.location_to_string m.location in
    match List.mem location_str seen with
    | true ->
      (* let prev_m = *)
      (*   match lookup_module graph (List.hd seen) with *)
      (*   | Some prev_m -> prev_m *)
      (*   | None -> Error.ie "DependencyGraph.sort - imporssible state" *)
      (* in *)
      begin
        match m.module_type with
        | Module.ESM | Module.CJS_esModule -> ()
        | Module.CJS -> raise (Cycle (location_str :: seen))
      end
    | false ->
      match check_module m with
      | true -> ()
      | false ->
        let sort' = sort (location_str :: seen) in
        let () =
          List.iter
            sort'
            (List.filter_map (fun (_, m) -> m) (lookup_dependencies ~kind:`Static graph m))
        in
          add_module m;
  in
  begin
    sort [] entry;
    List.rev !modules
  end
