type t = {
  modules : string list;
  cache : bool;
  message : string;
}

let report_string start_time { modules; cache; message } =
  Printf.sprintf
    "Packed in %.3fs. Number of modules: %d. Cache: %s. %s\n"
    (Unix.gettimeofday () -. start_time)
    (List.length modules)
    (if cache then "yes" else "no")
    message
  |> Lwt_io.write Lwt_io.stdout

let report_json _start_time { modules; _ } =
  let open Yojson.Basic
  in
  let modulePaths = modules
    |> List.map (fun d -> `String d)
  in
    `Assoc [
      ("modulesPaths", `List modulePaths)
    ]
    |> pretty_to_string
    |> Lwt_io.write Lwt_io.stdout

