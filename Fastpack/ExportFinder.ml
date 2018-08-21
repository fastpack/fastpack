
module M = Map.Make(String)
module Scope = FastpackUtil.Scope

type export = {
  export : Scope.export;
  parent_module : Module.t;
}

type all_exports = {
  has_cjs : bool;
  exports : export M.t;
}

type export_exists = Yes (* truly exists in ESM *)
                   | Maybe (* there are some re-exports from the CJS *)
                   | No (* does not exist in ESM *)

type t = {
  get_all : Module.t Module.DependencyMap.t -> Module.t -> all_exports;
  exists : Module.t Module.DependencyMap.t -> Module.t -> string -> export_exists;
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
      (fun { exports; has_cjs } batch_request ->
         let dep = {
           Module.Dependency.
           request = batch_request;
           requested_from = m.location
         }
         in
         match Module.DependencyMap.get dep dep_map with
         | Some m ->
           begin
             match m.Module.module_type with
             | Module.ESM ->
               let {
                 has_cjs = batch_has_cjs;
                 exports = batch_exports
               } = get_all dep_map m in
               let exports =
                 M.merge
                   (fun key v1 v2 ->
                      match v1, v2 with
                      | Some v1, Some v2 ->
                        if key = "default"
                        then Some v1
                        else
                          (* TODO: define proper error here *)
                          failwith ("ExportFinder > Cannot export twice: " ^ key ^ ". Module 1: " ^ (Module.location_to_string v1.parent_module.location) ^ ". Module 2: " ^ (Module.location_to_string v2.parent_module.location))
                      | Some v, None | None, Some v ->
                        Some v
                      | None, None ->
                        None
                   )
                   exports
                   batch_exports
               in
               { exports; has_cjs = has_cjs || batch_has_cjs}
             | _ ->
               {exports; has_cjs = true}
           end
         | None ->
           failwith ("Cannot find module: " ^ batch_request)
      )
      { exports = decorate m m.exports.names; has_cjs = m.module_type <> Module.ESM }
      m.exports.batches

  and get_all dep_map (m : Module.t) =
    match M.get m.id !unwrapped_batches with
    | Some exports ->
      exports
    | None ->
      let m_unwrapped_batches = unwrap_batches dep_map m in
      unwrapped_batches := M.add m.id m_unwrapped_batches !unwrapped_batches;
      m_unwrapped_batches
  in
  let exists dep_map m name =
    let { exports; has_cjs } = get_all dep_map m in
    match M.get name exports with
    | Some _ -> Yes
    | None -> if has_cjs then Maybe else No
  in
  { get_all; exists }

