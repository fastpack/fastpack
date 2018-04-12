open Lwt.Infix
module FS = FastpackUtil.FS
open PackerUtil
let debug = Logs.debug


let watch
    ~pack
    ~(cache : Cache.t)
    ~graph
    ~modules
    ~project_dir
    get_context
  =
  (* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * *)
  let w, u = Lwt.wait () in
  Lwt_unix.on_signal Sys.sigint (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;
  Lwt_unix.on_signal Sys.sigterm (fun _ -> Lwt.wakeup_exn u ExitOK) |> ignore;

  cache.setup_build_dependencies modules;

  let%lwt () = Lwt_io.(
      write stdout "Watching file changes (Ctrl+C to stop)\n"
    )
  in
  let process = ref None in
  let cmd = "watchman-wait -m 0 " ^ project_dir in
  let%lwt (started_process, ch_in, _) = FS.open_process cmd in
  process := Some started_process;

  let handle_error = function
    | PackError (ctx, error) ->
      let%lwt () =
        (string_of_error ctx error) ^ "\n" |> Lwt_io.(write stderr)
      in
      Lwt.return_none
    | exn ->
      raise exn
  in

  let report = Reporter.report_string ~cache:None ~mode:None in

  let pack cache ctx start_time =
    Lwt.catch
      (fun () ->
         let%lwt {Reporter. modules; _} = pack ~report ~cache ~ctx start_time in
         Lwt.return_some modules
      )
      handle_error
  in

  let get_context current_location =
    Lwt.catch
      (fun () -> get_context ~current_location () >>= Lwt.return_some)
      handle_error
  in

  let rec read_pack graph modules =
    let report_file_change filename =
      let message =
        FS.relative_path project_dir filename
        |> Printf.sprintf "Change detected: %s\n"
      in
      Lwt_io.(write stdout message)
    in
    let report_same_bundle ?(message="") start_time =
      let message =
        Printf.sprintf
          "Time taken: %.3f. Bundle is the same. %s\n"
          (Unix.gettimeofday () -. start_time)
          message
      in
      Lwt_io.(write stdout message)
    in
    let in_bundle filename =
      StringSet.mem filename modules
    in
    let%lwt line = Lwt_io.read_line_opt ch_in in
    match line with
    | None ->
      Lwt.return_unit
    | Some filename ->
      let start_time = Unix.gettimeofday () in
      let filename = FS.abs_path project_dir filename in
      let%lwt graph, modules =
        match cache.get_invalidated_modules filename with
        (* Something is changed in the dir, but we don't care *)
        | [] ->
          Lwt.return (graph, modules)
        (* Maybe a build dependency like .babelrc, need to check further *)
        | invalid_modules ->
          (* debug (fun x -> x "INVALID:\n%s" @@ String.concat "\n" files); *)
          let%lwt prev_entry, _ = cache.get_file_no_raise filename in
          cache.remove filename;
          let%lwt _, cached = cache.get_file_no_raise filename in
          if prev_entry.digest = "" (* the directory is changed *)
          then Lwt.return (graph, modules)
          else
            let%lwt () = report_file_change filename in
            match cached with
            | true ->
              let%lwt () = report_same_bundle start_time in
              Lwt.return (graph, modules)
            | false ->
              match List.filter in_bundle invalid_modules with
              (* all files which are invalidated by the change
               * aren't in the current bundle *)
              | [] ->
                let%lwt () =
                  report_same_bundle
                    ~message:("Previously cached file not in bundle. "
                              ^ "Maybe forgotten import?")
                    start_time
                in
                Lwt.return (graph, modules)
              (*
               * Exactly one file is changed in the bundle, safe to rebuild using
               * existing graph and not doing all the processing
               * We will re-read the target file (existing in the current bundle)
               * disabling the "trusted" cache. This will check all build
               * dependencies as well
               * *)
              | [module_location] ->
                let current_location =
                  match DependencyGraph.lookup_module graph module_location with
                  | Some m -> Some (m.Module.location)
                  | None -> Error.ie "Impossible state"
                in
                begin
                  match%lwt get_context current_location with
                  | None ->
                    Lwt.return (graph, modules)
                  | Some (ctx : Context.t) ->
                    match ctx.current_location with
                    | None ->
                      Error.ie "Impossible state: location is not resolved"
                    | Some location ->
                      DependencyGraph.remove_module graph location;
                      let ctx = { ctx with graph } in
                      let%lwt modules =
                        match%lwt pack cache ctx start_time with
                        | Some modules -> Lwt.return modules
                        | None -> Lwt.return modules
                      in
                      Lwt.return (ctx.graph, modules)
                end
              (*
               * Several files may be influenced by the build dependency
               * We'll rebuild the entire bundle using empty graph
               * and the main entry point
               * *)
              | _ ->
                match%lwt get_context None with
                | None ->
                  Lwt.return (graph, modules)
                | Some (ctx : Context.t) ->
                  let%lwt modules =
                    match%lwt pack cache ctx start_time with
                    | Some modules -> Lwt.return modules
                    | None -> Lwt.return modules
                  in
                  Lwt.return (ctx.graph, modules)
      in
      (read_pack [@tailcall]) graph modules
  in

  let finalize () =
    let () =
      match !process with
      | None -> ()
      | Some process -> process#terminate
    in
    Lwt.return_unit
  in
  Lwt.finalize (fun () -> read_pack graph modules <?> w) finalize
