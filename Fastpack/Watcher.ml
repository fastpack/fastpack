open Lwt.Infix
module FS = FastpackUtil.FS
module M = Map.Make(String)
let debug = Logs.debug

let collect_links current_dir =
  let node_modules = FilePath.concat current_dir "node_modules" in
  let%lwt dirs =
    match%lwt FS.stat_option node_modules with
    |Some { st_kind = Unix.S_DIR; _ } ->
      Lwt_unix.files_of_directory node_modules |> Lwt_stream.to_list
    | _ -> Lwt.return []
  in
  let%lwt links =
    Lwt_list.filter_map_s
      (fun dir ->
         let dir = FS.abs_path node_modules dir in
         try%lwt
           let%lwt link = Lwt_unix.readlink dir in
           Lwt.return_some (dir, FS.abs_path node_modules link)
         with
         | Unix.Unix_error (Unix.EINVAL, _, _) -> Lwt.return_none
      )
      (List.filter (fun d -> d <> "." && d <> "..") dirs)
  in
  List.fold_left (fun map (link, path) -> M.add path link map) M.empty links
  |> Lwt.return

let common_root paths =
  match paths with
  | [] -> failwith "Cannot operate on empty paths list"
  | path :: [] ->
    path
  | _ ->
    let path_parts =
      paths
      |> List.map (String.split_on_char '/')
      |> List.sort (fun p1 p2 -> compare (List.length p1) (List.length p2))
    in
    let pattern = List.hd path_parts in
    let rest = List.tl path_parts in
    let rec common_root' pattern found rest =
      match pattern with
      | [] -> found
      | part :: _ ->
        match List.exists (fun parts -> List.hd parts <> part) rest with
        | true -> found
        | false ->
          common_root' (List.tl pattern) (part :: found) (List.(map tl rest))
    in
    common_root' pattern [] rest
    |> List.rev
    |> String.concat "/"


let start_watchman root =
  let subscription =  Printf.sprintf "s-%f" (Unix.gettimeofday ()) in
  let subscribe_message =
    `List [
      `String "subscribe";
      `String root;
      `String subscription;
      `Assoc [("fields", `List [`String "name"])]
    ] |> Yojson.to_string
  in
  let cmd = "watchman --no-save-state -j --no-pretty -p" in
  let%lwt (started_process, ch_in, ch_out) = FS.open_process cmd in
  let%lwt () = Lwt_io.write ch_out (subscribe_message ^ "\n") in
  let%lwt _ = Lwt_io.read_line ch_in in
  (* TODO: validate answer *)
  (*{"version":"4.9.0","subscribe":"mysubscriptionname","clock":"c:1523968199:68646:1:95"}*)
  (* this line is ignored, receiving possible files *)
  let%lwt _ = Lwt_io.read_line ch_in in
  Lwt.return (started_process, ch_in)

let ask_watchman ch =
  match%lwt Lwt_io.read_line_opt ch with
  | None -> Lwt.return_none
  | Some line ->
    let open Yojson.Safe.Util in
    let data = Yojson.Safe.from_string line in
    let root = member "root" data |> to_string in
    let files =
      member "files" data
      |> to_list
      |> List.map to_string
      |> List.map (fun filename -> FS.abs_path root filename)
    in
    Lwt.return_some files



let watch
    ~pack
    ~(cache : Cache.t)
    ~graph
    ~current_dir
    get_context
  =
  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  let w, u = Lwt.wait () in
  Lwt_unix.on_signal Sys.sigint (fun _ -> Lwt.wakeup_exn u Context.ExitOK) |> ignore;
  Lwt_unix.on_signal Sys.sigterm (fun _ -> Lwt.wakeup_exn u Context.ExitOK) |> ignore;

  let process = ref None in
  let%lwt link_map = collect_links current_dir in
  let link_paths =
    link_map
    |> M.bindings
    |> List.map fst
    |> List.sort (fun s1 s2 -> Pervasives.compare (String.length s1) (String.length s2))
    |> List.rev
  in
  let common_root = common_root (current_dir :: link_paths) in
  let common_root = if common_root <> "" then common_root else current_dir in
  let%lwt (started_process, ch_in) = start_watchman common_root in
  process := Some started_process;
  let%lwt () = Lwt_io.(
      write stdout "Watching file changes (Ctrl+C to stop)\n"
    )
  in

  let rec find_linked_path filename = function
    | [] -> filename
    | path :: paths ->
      match FilePath.is_subdir filename path with
      | false -> find_linked_path filename paths
      | true ->
        let relative = FilePath.make_relative path filename in
        match M.get path link_map with
        | Some base_path -> FS.abs_path base_path relative
        | None -> failwith ("Path not found in the links map: " ^ path)
  in

  let handle_error = function
    | Context.PackError (ctx, error) ->
      let%lwt () =
        (Context.string_of_error ctx error) ^ "\n" |> Lwt_io.(write stderr)
      in
      Lwt.return_none
    | exn ->
      raise exn
  in

  let report = Reporter.report_string ~cache:None ~mode:None in

  let pack ctx start_time =
    Lwt.catch
      (fun () ->
         let%lwt {Reporter. graph; _} = pack ~report ~ctx start_time in
         Lwt.return_some graph
      )
      handle_error
  in

  let rec read_pack graph =
    match%lwt ask_watchman ch_in with
    | None ->
      Lwt.return_unit
    | Some filenames ->
      let start_time = Unix.gettimeofday () in
      let filenames =
        List.map (fun filename -> find_linked_path filename link_paths) filenames
      in
      List.iter cache.remove filenames;
      let%lwt graph  =
        match DependencyGraph.get_modules_by_filenames graph filenames with
        (* Something is changed in the dir, but we don't care *)
        | [] ->
          Lwt.return graph
        (* Maybe a build dependency like .babelrc, need to check further *)
        | [m] ->
          begin
            let%lwt (ctx : Context.t) =
              get_context (Some m.location)
            in
            DependencyGraph.remove_module graph m;
            let ctx = { ctx with graph } in
            match%lwt pack ctx start_time with
            | Some graph ->
              Lwt.return graph
            | None ->
              DependencyGraph.add_module graph m;
              Lwt.return graph
          end
        | _ ->
          let%lwt ( ctx : Context.t) = get_context None in
          match%lwt pack ctx start_time with
          | Some graph -> Lwt.return graph
          | None -> Lwt.return graph
      in
      (read_pack [@tailcall]) graph
  in

  let finalize () =
    let () =
      match !process with
      | None -> ()
      | Some process -> process#terminate
    in
    Lwt.return_unit
  in
  Lwt.finalize (fun () -> read_pack graph <?> w) finalize
