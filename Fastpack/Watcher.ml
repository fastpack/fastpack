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
  let cache = { cache with trusted = true } in
  let rec read_pack graph =
    let report_file_change ctx filename =
      let message =
        relative_name ctx filename
        |> Printf.sprintf "Change detected: %s\n"
      in
      Lwt_io.(write stdout message)
    in
    let report_same_bundle ?(message="") start_time =
      let message =
        Printf.sprintf
          "Time taken: %.3f. Bundle is the same. %s\n"
          (Unix.gettimeofday () -. start_time)
          message
      in
      Lwt_io.(write stdout message)
    in
    let%lwt line = Lwt_io.read_line_opt ch_in in
    match line with
    | None ->
      Lwt.return_unit
    | Some filename ->
      let start_time = Unix.gettimeofday () in
      let filename = FS.abs_path package_dir filename in
      let%lwt graph =
        (* TODO: cache.invalidate should return:
         * None - if file not in cache
         * Some [] - if this is a module
         * Some [modules] - if this is a build dependency
         * *)
        match cache.get_potentially_invalid filename, graph with
        | [], _ ->
          Lwt.return graph
        | _, None ->
          let ctx = {(get_context ()) with graph = DependencyGraph.empty ()} in
          let%lwt () = report_file_change ctx filename in
          let%lwt m = read_module ~ignore_trusted:true ctx cache filename in
          if m.cached then begin
            let%lwt () = report_same_bundle start_time in
            Lwt.return graph
          end
          else begin
            let%lwt () = pack cache ctx start_time in
            Lwt.return_some ctx.graph
          end
        | files, Some graph ->
          let%lwt () = report_file_change (get_context ()) filename in
          let files =
            List.filter
              (fun fn -> DependencyGraph.lookup_module graph fn <> None)
              files
          in
          match files with
          | [] ->
            let%lwt () =
              report_same_bundle
                ~message:("Previously seen file. Maybe forgotten import?")
                start_time
            in
            Lwt.return_some graph
          | [filename] ->
            let ctx = get_context () in
            let%lwt m = read_module ~ignore_trusted:true ctx cache filename in
            if m.cached then begin
              let%lwt () = report_same_bundle start_time in
              Lwt.return_some graph
            end
            else begin
              DependencyGraph.remove_module graph filename;
              let ctx = { ctx with graph; current_filename = filename } in
              let%lwt () = pack cache ctx start_time in
              Lwt.return_some ctx.graph
            end
          | _ ->
            let ctx = {(get_context ()) with graph = DependencyGraph.empty ()} in
            let%lwt m = read_module ~ignore_trusted:true ctx cache filename in
            if m.Module.cached then Lwt.return_some graph
            else begin
              let%lwt () = pack cache ctx start_time in
              Lwt.return_some ctx.graph
            end
      in
      (read_pack [@tailcall]) graph
  in

  let finalize () =
    let () =
      match !process with
      | None -> ()
      | Some process -> process#terminate
    in
    Lwt.return_unit
  in
  Lwt.finalize (fun () -> read_pack (Some ctx.graph) <?> w) finalize
