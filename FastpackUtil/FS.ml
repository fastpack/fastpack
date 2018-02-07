
let stat_option path =
  try%lwt
    let%lwt stat = Lwt_unix.stat path in
    Lwt.return_some stat
  with Unix.Unix_error _ ->
    Lwt.return_none

let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename

let relative_path dir filename =
    String.(
      sub
        filename
        (length dir + 1)
        (length filename - length dir - 1)
    )

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

let rec makedirs dir =
  match%lwt stat_option dir with
  | None ->
    let%lwt () = makedirs (FilePath.dirname dir) in
    Lwt_unix.mkdir dir 0o777
  | Some stat ->
    match stat.st_kind with
    | Lwt_unix.S_DIR -> Lwt.return_unit
    | _ ->
      Error.ie @@ Printf.sprintf "'%s' expected to be a directory" dir

let try_dir dir =
  try%lwt
    let%lwt stat = Lwt_unix.stat dir in
    match stat.st_kind with
    | Lwt_unix.S_DIR -> Lwt.return_some dir
    | _ -> Lwt.return_none
  with Unix.Unix_error _ ->
    Lwt.return_none
