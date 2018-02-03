open Lwt.Infix
module FS = FastpackUtil.FS
open PackerUtil


let watch pack (cache : Cache.t) graph modules get_context =
  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  let w, u = Lwt.wait () in
  Lwt_unix.on_signal Sys.sigint (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;
  Lwt_unix.on_signal Sys.sigterm (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;

  let%lwt () = Lwt_io.(
      write stdout "Watching file changes (Ctrl+C to stop)\n"
    )
  in
  let process = ref None in
  let { Context. package_dir; _ } = get_context () in
  let cmd = "watchman-wait -m 0 " ^ package_dir in
  let%lwt (started_process, ch_in, _) = FS.open_process cmd in
  process := Some started_process;

  let pack cache ctx start_time =
    Lwt.catch
      (fun () ->
         let%lwt {Reporter. modules; _} = pack cache ctx start_time in
         Lwt.return_some modules
      )
      (function
       | PackError (ctx, error) ->
         let%lwt () =
           (string_of_error ctx error) ^ "\n" |> Lwt_io.(write stderr)
         in
         Lwt.return_none
       | exn ->
         raise exn
      )
  in

  let rec read_pack graph modules =
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
    let in_bundle filename =
      StringSet.mem filename modules
    in
    let%lwt line = Lwt_io.read_line_opt ch_in in
    match line with
    | None ->
      Lwt.return_unit
    | Some filename ->
      let start_time = Unix.gettimeofday () in
      let filename = FS.abs_path package_dir filename in
      let%lwt graph, modules =
        match cache.get_potentially_invalid filename, in_bundle filename with
        (* Something is changed in the dir, but we don't care *)
        | [], false ->
          Lwt.return (graph, modules)
        (* Weird bug, should never happen, emitted last time, but unknown in cache*)
        | [], true ->
          Error.ie ("File is in bundle, but unknown in cache: " ^ filename)
        (* Maybe a build dependency like .babelrc, need to check further *)
        | files, _ ->
          let%lwt () = report_file_change (get_context ()) filename in
          match List.filter in_bundle files with
          (* all files which are invalidated by the change
           * aren't in the current bundle *)
          | [] ->
            cache.remove filename;
            let%lwt () =
              report_same_bundle
                ~message:("Previously cached file not in bundle. Maybe forgotten import?")
                start_time
            in
            Lwt.return (graph, modules)
          (*
           * Exactly one file is changed in the bundle, safe to rebuild using
           * existing graph and not doing all the processing
           * We will re-read the target file (existing in the current bundle)
           * disabling the "trusted" cache. This will check all build
           * dependencies as well
           * *)
          | [filename] ->
            let ctx = get_context () in
            let%lwt m = read_module ~ignore_trusted:true ctx cache filename in
            if m.cached
            then
              let%lwt () = report_same_bundle start_time in
              Lwt.return (graph, modules)
            else begin
              DependencyGraph.remove_module graph filename;
              let ctx = { ctx with graph; current_filename = filename } in
              let%lwt modules =
                match%lwt pack cache ctx start_time with
                | Some modules -> Lwt.return modules
                | None -> Lwt.return modules
              in
              Lwt.return (ctx.graph, modules)
            end
          (*
           * Several files may be influenced by the build dependency
           * We'll rebuild the entire bundle using empty graph
           * and the main entry point
           * *)
          | _ ->
            let ctx =
              {(get_context ()) with graph = DependencyGraph.empty ()} 
            in
            let%lwt m = read_module ~ignore_trusted:true ctx cache filename in
            if m.Module.cached
            then
              Lwt.return (graph, modules)
            else
              let%lwt modules =
                match%lwt pack cache ctx start_time with
                | Some modules -> Lwt.return modules
                | None -> Lwt.return modules
              in
              Lwt.return (ctx.graph, modules)
      in
      (read_pack [@tailcall]) graph modules
  in

  let finalize () =
    let () =
      match !process with
      | None -> ()
      | Some process -> process#terminate
    in
    Lwt.return_unit
  in
  Lwt.finalize (fun () -> read_pack graph modules <?> w) finalize
