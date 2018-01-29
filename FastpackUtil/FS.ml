
let stat_option path =
  try%lwt
    let%lwt stat = Lwt_unix.stat path in
    Lwt.return_some stat
  with Unix.Unix_error _ ->
    Lwt.return_none

let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename
