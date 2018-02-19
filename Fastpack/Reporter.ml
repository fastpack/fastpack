module StringSet = Set.Make(String)
type t = {
  modules : StringSet.t;
  cache : bool;
  message : string;
  size : int;
}

let report_string start_time { modules; cache; message; size } =
  let pretty_size =
    Printf.(
      if size >= 1048576
      then sprintf "%.2fMb" (float_of_int size /. 1048576.0)
      else
        if size >= 1024
        then sprintf
            "%dKb"
            (float_of_int size /. 1024.0 +. 0.5 |> floor |> int_of_float)
        else sprintf "%db" size
    )
  in
  Printf.sprintf
    "Packed in %.3fs. Bundle: %s. Modules: %d. Cache: %s. %s\n"
    (Unix.gettimeofday () -. start_time)
    pretty_size
    (modules |> StringSet.elements |> List.length)
    (if cache then "yes" else "no")
    message
  |> Lwt_io.write Lwt_io.stdout

let report_json _start_time { modules; _ } =
  let open Yojson.Basic
  in
  let modulePaths = modules
    |> StringSet.elements
    |> List.map (fun d -> `String d)
  in
    `Assoc [
      ("modulesPaths", `List modulePaths)
    ]
    |> pretty_to_string
    |> (fun s -> s ^ "\n")
    |> Lwt_io.write Lwt_io.stdout

