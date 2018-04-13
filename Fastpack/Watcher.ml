open Lwt.Infix
module FS = FastpackUtil.FS
open PackerUtil
let debug = Logs.debug


let watch
    ~pack
    ~(cache : Cache.t)
    ~graph
    ~project_dir
    get_context
  =
  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  let w, u = Lwt.wait () in
  Lwt_unix.on_signal Sys.sigint (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;
  Lwt_unix.on_signal Sys.sigterm (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;

  (* graph *)
  (* |> DependencyGraph.map_modules (fun location_str _ -> location_str) *)
  (* |> StringSet.of_list *)
  (* |> cache.setup_build_dependencies; *)

  let%lwt () = Lwt_io.(
      write stdout "Watching file changes (Ctrl+C to stop)\n"
    )
  in
  let process = ref None in
  let cmd = "watchman-wait -m 0 " ^ project_dir in
  let%lwt (started_process, ch_in, _) = FS.open_process cmd in
  process := Some started_process;

  let handle_error = function
    | PackError (ctx, error) ->
      let%lwt () =
        (string_of_error ctx error) ^ "\n" |> Lwt_io.(write stderr)
      in
      Lwt.return_none
    | exn ->
      raise exn
  in

  let report = Reporter.report_string ~cache:None ~mode:None in

  let pack cache ctx start_time =
    Lwt.catch
      (fun () ->
         let%lwt {Reporter. graph; _} = pack ~report ~cache ~ctx start_time in
         Lwt.return_some graph
      )
      handle_error
  in

  let rec read_pack graph =
    let report_file_change filename =
      let message =
        FS.relative_path project_dir filename
        |> Printf.sprintf "Change detected: %s\n"
      in
      Lwt_io.(write stdout message)
    in
    let _report_same_bundle ?(message="") start_time =
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
      let filename = FS.abs_path project_dir filename in
      cache.remove filename;
      let%lwt graph  =
        match DependencyGraph.get_modules_by_filename graph filename with
        (* Something is changed in the dir, but we don't care *)
        | [] ->
          Lwt.return graph
        (* Maybe a build dependency like .babelrc, need to check further *)
        | [m] ->
          begin
            let%lwt () = report_file_change filename in
            let%lwt (ctx : Context.t) =
              get_context (Some m.location)
            in
            DependencyGraph.remove_module graph m;
            let ctx = { ctx with graph } in
            match%lwt pack cache ctx start_time with
            | Some graph ->
              Lwt.return graph
            | None ->
              DependencyGraph.add_module graph m;
              Lwt.return graph
          end
        | _ ->
          let%lwt () = report_file_change filename in
          let%lwt ( ctx : Context.t) = get_context None in
          match%lwt pack cache ctx start_time with
          | Some graph -> Lwt.return graph
          | None -> Lwt.return graph
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
  Lwt.finalize (fun () -> read_pack graph <?> w) finalize
