
module M = Map.Make(String)
module Scope = FastpackUtil.Scope

type export = {
  export : Scope.export;
  parent_module : Module.t;
}

let make () =

  (* infra for unwrapping `export * from 'module';` statements *)
  let unwrapped_batches = ref M.empty in

  (* TODO: track cyclic dependencies *)
  let rec unwrap_batches dep_map (m : Module.t) =
    let decorate m exports =
      M.map (fun export -> { export; parent_module = m }) exports
    in
    List.fold_left
      (fun names batch_request ->
         let dep = {
           Module.Dependency.
           request = batch_request;
           requested_from = Location m.location
         }
         in
         match Module.DependencyMap.get dep dep_map with
         | Some m ->
           let batch_names = get_all_exports dep_map m in
           M.merge
             (fun key v1 v2 ->
                match v1, v2 with
                | Some _, Some _ ->
                  failwith ("Cannot export twice: " ^ key)
                | Some v, None | None, Some v ->
                  Some v
                | None, None ->
                  None
             )
             names
             batch_names
         | None ->
           failwith ("Cannot find module: " ^ batch_request)
      )
      (decorate m m.exports.names)
      m.exports.batches

  and get_all_exports dep_map (m : Module.t) =
    match M.get m.id !unwrapped_batches with
    | Some exports ->
      exports
    | None ->
      let m_unwrapped_batches = unwrap_batches dep_map m in
      unwrapped_batches := M.add m.id m_unwrapped_batches !unwrapped_batches;
      m_unwrapped_batches
  in
  get_all_exports

