module StringSet = Set.Make(String)
exception Cycle of string list
let debug = Logs.debug

type t = {
  modules : (string, Module.t) Hashtbl.t;
  dependencies : (string, (Dependency.t * Module.location option)) Hashtbl.t;
}

let iter_modules iter graph =
  Hashtbl.iter iter graph.modules

let get_modules graph =
  Hashtbl.keys_list graph.modules

let empty ?(size=5000) () = {
  modules = Hashtbl.create size;
  dependencies = Hashtbl.create (size * 20);
}

let lookup table key =
  Hashtbl.find_opt table key

let lookup_module graph location_str =
  lookup graph.modules location_str

let lookup_dependencies graph (m : Module.t) =
  let location_str = Module.location_to_string m.location in
  List.map
    (fun (dep, some_filename) ->
      match some_filename with
      | None -> (dep, None)
      | Some location ->
        let location_str = Module.location_to_string location in
        (dep, lookup_module graph location_str)
    )
    (Hashtbl.find_all graph.dependencies location_str)

let add_module graph (m : Module.t) =
  let location_str = Module.location_to_string m.location in
  Hashtbl.remove graph.modules location_str;
  Hashtbl.add graph.modules location_str m

let add_dependency graph (m : Module.t) (dep : (Dependency.t * Module.location option)) =
  let location_str = Module.location_to_string m.location in
  Hashtbl.add graph.dependencies location_str dep

let remove_module graph location =
  let location_str = Module.location_to_string location in
  Hashtbl.remove graph.modules location_str;
  List.iter
    (fun _ -> Hashtbl.remove graph.dependencies location_str)
    (Hashtbl.find_all graph.dependencies location_str)


let sort graph entry =
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
            (List.filter_map (fun (_, m) -> m) (lookup_dependencies graph m))
        in
          add_module m;
  in
  begin
    sort [] entry;
    List.rev !modules
  end
