open Lwt.Infix
module FS = FastpackUtil.FS


let watch package_dir pack (cache : PackerUtil.Cache.t) start_time =
  let process = ref None in

  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  (* TODO: raise WatchCompleted ? *)
  (* TODO: handle SIGTERM *)
  let w,u = Lwt.wait () in
  Lwt_unix.on_signal
    Sys.sigint
    (fun _ -> Lwt.wakeup_exn u (Failure "SIGINT"))
  |> ignore;

  let%lwt () = pack cache start_time in
  let%lwt () = Lwt_io.(write stdout "Watching for changes ...\n") in
  let cmd = "watchman-wait -m 0 " ^ package_dir in
  let%lwt (started_process, ch_in, _) = FS.open_process cmd in
  process := Some started_process;

  let cache = cache.to_trusted () in
  let rec read_pack () =
    let%lwt line = Lwt_io.read_line_opt ch_in in
    match line with
    | None ->
      Lwt.return_unit
    | Some filename ->
      let filename = FS.abs_path package_dir filename in
      let%lwt () =
        match cache.invalidate filename with
        | false -> Lwt.return_unit
        | true ->
          let start_time = Unix.gettimeofday () in
          pack cache start_time
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
