let watch pack start_time =
  let%lwt () = Lwt_io.(write stdout "Watching...\n") in
  pack start_time
