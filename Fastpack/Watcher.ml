open Lwt.Infix
module FS = FastpackUtil.FS
open PackerUtil


let watch pack (cache : Cache.t) get_context start_time =
  let ctx = get_context () in
  let {Context. package_dir; _ } = ctx in
  let process = ref None in

  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  (* TODO: raise WatchCompleted ? *)
  (* TODO: handle SIGTERM *)
  let w, u = Lwt.wait () in
  Lwt_unix.on_signal
    Sys.sigint
    (fun _ -> Lwt.wakeup_exn u (Failure "SIGINT"))
  |> ignore;

  let%lwt () = pack cache ctx start_time in
  (* TODO: in case if pack fails graph should be empty and cache is not trusted *)
  let graph = ctx.graph in
  let%lwt () = Lwt_io.(write stdout "Watching file changes ...\n") in
  let cmd = "watchman-wait -m 0 " ^ package_dir in
  let%lwt (started_process, ch_in, _) = FS.open_process cmd in
  process := Some started_process;

  (*
   * if file is not in cache - no rebuild
   * get all files it invalidates (including itself)
   * if graph is empty (last build was not successful):
   *    re-read main file, ignoring the trusted cache
   *    if file is still cached - no action
   *    otherwise rebuild the entire bundle as usual
   * if graph is not empty (last build was successful):
   *    filter out all invalidated files against the graph (by existance in it)
   *    if nothing remains - no action
   *    otherwise:
   *      re-read the main file ignoring trusted - if it is still cached - no action
   *      if one file remains - rebuild using this file as an entry point and the graph
   *      otherwise rebuild as usual with an empty graph
   *
   * *)
  let cache = cache.to_trusted () in
  let rec read_pack () =
    let%lwt line = Lwt_io.read_line_opt ch_in in
    match line with
    | None ->
      Lwt.return_unit
    | Some filename ->
      let filename = FS.abs_path package_dir filename in
      let%lwt () =
        (* TODO: cache.invalidate should return:
         * None - if file not in cache
         * Some [] - if this is a module
         * Some [modules] - if this is a build dependency
         * *)
        match cache.invalidate filename with
        | false -> Lwt.return_unit
        | true ->
          match DependencyGraph.lookup_module graph filename with
          | None -> Lwt.return_unit
          | Some _ ->
            let start_time = Unix.gettimeofday () in
            DependencyGraph.remove_module graph filename;
            let ctx = { (get_context ()) with graph; current_filename = filename } in
            pack cache ctx start_time
      in
      (read_pack [@tailcall]) ()
  in

  let finalize () =
    let () =
      match !process with
      | None -> ()
      | Some process -> process#terminate
    in
    Lwt.return_unit
  in
  Lwt.finalize (fun () -> read_pack () <?> w) finalize
