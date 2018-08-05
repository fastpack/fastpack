module StringSet = Set.Make(String)

type t = {
  graph : DependencyGraph.t;
  size : int;
}

type report = | JSON | Text

let report_string ?sendMessage ?(cache=None) ?(mode=None) start_time { graph; size } =
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
  let cache =
    match cache with
    | None -> ""
    | Some message -> Printf.sprintf "Cache: %s. " message
  in
  let mode =
    match mode with
    | None -> ""
    | Some mode -> PackerUtil.Mode.to_string mode |> Printf.sprintf "Mode: %s."
  in
  Printf.sprintf
    "Packed in %.3fs. Bundle: %s. Modules: %d. %s%s\n"
    (Unix.gettimeofday () -. start_time)
    pretty_size
    (DependencyGraph.length graph)
    cache
    mode
  |> (fun str ->
      let%lwt () = match sendMessage with
        | Some(sM) -> 
          let () = print_endline "sendMessage" in
          sM str
        | None -> Lwt.return ()
      in
      Lwt_io.write Lwt_io.stdout str
    )

let report_json ?sendMessage _start_time { graph; _ } =
  let open Yojson.Basic
  in
  let modulePaths =
    graph
    |> DependencyGraph.modules
    |> Sequence.map (fun (location_str, _) -> `String location_str)
    |> Sequence.sort ~cmp:Pervasives.compare
    |> Sequence.to_list
  in
    `Assoc [
      ("modulesPaths", `List modulePaths)
    ]
    |> to_string ~std:true
    |> (fun s -> s ^ "\n")
  |>  (fun str ->
      let%lwt () = match sendMessage with
        | Some(sM) -> 
          let () = print_endline "sendMessage" in
          sM str
        | None -> Lwt.return ()
      in
      Lwt_io.write Lwt_io.stdout str
    )

