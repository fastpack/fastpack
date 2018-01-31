let watch pack cache start_time =
  let%lwt () = Lwt_io.(write stdout "Watching..") in
  pack cache start_time
