type report = | JSON | Text


type file = {
  name : string;
  size : int;
}

module Text = struct

  let report_ok ?(message=None) ~(start_time : float)  ~(ctx : Context.t) ~(files : file list) =
    (* TODO: fix next line when we report multiple files *)
    let { size; _ } = List.hd files in
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
      "Packed in %.3fs. Bundle: %s. Modules: %d. %s\n"
      (Unix.gettimeofday () -. start_time)
      pretty_size
      (DependencyGraph.length ctx.graph)
      (CCOpt.get_or ~default:"" message)
    |> Lwt_io.write Lwt_io.stdout

  let report_error ~(ctx : Context.t) ~(error: Error.reason) =
    let error_msg = Context.string_of_error ctx error in
    Lwt_io.write Lwt_io.stderr error_msg

end

module JSON = struct
  let report_ok ?(message=None) ~(start_time : float)  ~(ctx : Context.t) ~(files : file list) =
    let open Yojson.Basic in
    let files =
      files
      |> List.map (fun { name; size } -> `Assoc [
          ("name", `String name);
          ("size", `Int size)
        ])
    in
    let modules =
      ctx.graph
      |> DependencyGraph.modules
      |> Sequence.map (fun (location, _) -> `String (Module.location_to_string location))
      |> Sequence.sort ~cmp:Pervasives.compare
      |> Sequence.to_list
    in
    let message =
      match message with
      | None -> `Null
      | Some message -> `String message
    in
    `Assoc [
      ("time", `Float (Unix.gettimeofday () -. start_time));
      ("files", `List files);
      ("modules", `List modules);
      ("message", message)
    ]
    |> to_string ~std:true
    |> (fun s -> s ^ "\n")
    |> Lwt_io.write Lwt_io.stdout

  let report_error ~(ctx : Context.t) ~(error: Error.reason) =
    let open Yojson.Basic in
    `Assoc [
      ("error", `String (Context.string_of_error ctx error))
    ]
    |> to_string ~std:true
    |> (fun s -> s ^ "\n")
    |> Lwt_io.write Lwt_io.stderr
end

type t = {
  report_ok : ?message:string option
    -> start_time:float
    -> ctx:Context.t
    -> files:file list
    -> unit Lwt.t;
  report_error : ctx:Context.t -> error:Error.reason -> unit Lwt.t;
}

let make (report : report ) =
  match report with
  | JSON -> JSON.{report_ok; report_error}
  | Text -> Text.{report_ok; report_error}

