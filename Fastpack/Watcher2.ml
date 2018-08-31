let rebuild ~(changed_files: string list) ~pack prev_result =
  let start_time = Unix.gettimeofday () in
  match prev_result with
  | Error _ctx -> failwith "not implemented"
  | Ok (ctx: Context.t) ->
    List.iter ctx.cache.remove changed_files;
    match DependencyGraph.get_modules_by_filenames ctx.graph changed_files with
    | [] -> Lwt.return_ok ctx
    | m :: [] ->
      DependencyGraph.remove_module ctx.graph  m;
      pack ~current_location:(Some m.Module.location) ~graph:(Some ctx.graph) ~initial:false ~start_time
    | _ ->
      pack ~current_location:None ~graph:None ~initial:false ~start_time
