
let stat_option path =
  try%lwt
    let%lwt stat = Lwt_unix.stat path in
    Lwt.return_some stat
  with Unix.Unix_error _ ->
    Lwt.return_none

let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename

let open_process cmd =
  (* TODO: handle Unix_error *)
  let (fp_in, process_out) = Unix.pipe () in
  let (process_in, fp_out) = Unix.pipe () in
  let fp_in_ch = Lwt_io.of_unix_fd ~mode:Lwt_io.Input fp_in in
  let fp_out_ch = Lwt_io.of_unix_fd ~mode:Lwt_io.Output fp_out in
  let process =
    Lwt_process.(
      open_process_none
        ~env:(Unix.environment ())
        ~stdin:(`FD_move process_in)
        ~stdout:(`FD_move process_out)
        (shell cmd)
    )
  in
  Lwt.return (process, fp_in_ch, fp_out_ch)
