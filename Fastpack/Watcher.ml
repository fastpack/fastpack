let watch pack start_time =
  let%lwt () = Lwt_io.(write stdout "Watching..") in
  pack start_time
