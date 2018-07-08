module FS = FastpackUtil.FS

module Version = Version
module Error = Error
module Cache = Cache
module Mode = Mode
module Target = Target
module Context = Context
module Module = Module
module Resolver = Resolver
module Preprocessor = Preprocessor
module Reporter = Reporter
module Watcher = Watcher


exception PackError = Context.PackError
exception ExitError = Context.ExitError
exception ExitOK = Context.ExitOK

type options = {
  entry_points : string list;
  output_directory : string;
  output_filename : string;
  mode : Mode.t;
  mock : (string * Resolver.Mock.t) list;
  node_modules_paths : string list;
  resolve_extension : string list;
  target : Target.t;
  cache : Cache.strategy;
  preprocess : Preprocessor.config list;
  postprocess : string list;
  report : Reporter.report;
  watch : bool;
}

let prepare_and_pack options start_time =
  let%lwt current_dir = Lwt_unix.getcwd () in

  (* entry points *)
  let%lwt entry_points =
    options.entry_points
    |> Lwt_list.map_p
      (fun entry_point ->
        let abs_path = FS.abs_path current_dir entry_point in
        match%lwt FS.stat_option abs_path with
        | Some { st_kind = Unix.S_REG; _ } ->
          Lwt.return ("./" ^ (FS.relative_path current_dir abs_path))
        | _ ->
          Lwt.return entry_point
      )
  in
  let entry_location = Module.Main entry_points in

  (* output directory & output filename *)
  let output_dir, output_file =
    let output_dir = FS.abs_path current_dir options.output_directory in
    let output_file = FS.abs_path output_dir options.output_filename in
    let output_file_parent_dir = FilePath.dirname output_file in
    if output_dir = output_file_parent_dir
    || FilePath.is_updir output_dir output_file_parent_dir
    then
      (output_dir, output_file)
    else
      let error =
        "Output filename must be a subpath of output directory.\n" ^
        "Output directory:\n  " ^ output_dir ^ "\n" ^
        "Output filename:\n  " ^ output_file ^ "\n"
      in
      raise (ExitError error)
  in
  (* TODO: the next line may not belong here *)
  (* TODO: also cleanup the directory before emitting, maybe? *)
  let%lwt () = FS.makedirs output_dir in

  (* preprocessor *)
  let%lwt preprocessor =
    Preprocessor.make
      options.preprocess
      current_dir
      output_dir
  in


  (* cache & cache reporting *)
  let%lwt cache, cache_report =
    match options.cache with
    | Cache.Use ->
      let filename =
        String.concat "-" [
          current_dir |> Digest.string |> Digest.to_hex;
          Version.github_commit
        ]
      in
      let node_modules = FilePath.concat current_dir "node_modules" in
      let%lwt dir =
        match%lwt FS.try_dir node_modules with
        | Some dir ->
          FilePath.concat (FilePath.concat dir ".cache") "fpack"
          |> Lwt.return
        | None ->
          FilePath.concat (FilePath.concat current_dir ".cache") "fpack"
          |> Lwt.return
      in
      let%lwt () = FS.makedirs dir in
      let cache_filename = FilePath.concat dir filename in
      let%lwt cache = Cache.(create (Persistent cache_filename)) in
      Lwt.return (cache, if cache.starts_empty then "empty" else "used")
    | Cache.Disable ->
      let%lwt cache = Cache.(create Memory) in
      Lwt.return (cache, "disabled")
  in

  (* main package.json *)
  let%lwt project_package, _ =
    cache.find_package_for_filename current_dir (FilePath.concat current_dir "package.json")
  in

  (* make sure resolve extensions all start with '.'*)
  let extensions =
    options.resolve_extension
    |> List.filter (fun ext -> String.trim ext <> "")
    |> List.map (fun ext -> match String.get ext 0 with | '.' -> ext | _ -> "." ^ ext)
  in

  let {Reporter. report_ok; report_error } = Reporter.make options.report in
  let run ~current_location ~graph ~initial ~start_time =
    let message =
      if initial
      then Printf.sprintf " Cache: %s. Mode: %s." cache_report (Mode.to_string options.mode)
      else ""
    in
    let resolver =
      Resolver.make
        ~current_dir
        ~mock:(options.mock)
        ~node_modules_paths:(options.node_modules_paths)
        ~extensions
        ~preprocessor
        ~cache
    in
    let ctx = {
      Context.
      current_dir;
      project_package;
      output_dir;
      output_file;
      entry_location;
      current_location = CCOpt.get_or ~default:entry_location current_location;
      stack = [];
      mode = options.mode;
      target = options.target;
      resolver;
      preprocessor;
      export_finder = ExportFinder.make ();
      graph = CCOpt.get_or ~default:(DependencyGraph.empty ()) graph;
      cache
    }
    in
    Lwt.catch
      (fun () ->
        let%lwt () = GraphBuilder.build ctx in
        let%lwt emitted_modules, files =
          match options.mode with
          | Mode.Production -> failwith "Not impl"
          | Mode.Test
          | Mode.Development ->
            ScopedEmitter.emit ctx
        in
        let ctx = { ctx with graph = DependencyGraph.cleanup ctx.graph emitted_modules; } in
        let%lwt () = report_ok ~message:(Some message) ~start_time ~ctx ~files in
        Lwt.return_ok ctx
      )
      (function
        | PackError (ctx, error) ->
          let%lwt () = report_error ~ctx ~error in
          if initial then raise (ExitError "") else Lwt.return_error ctx
        | exn -> raise exn
      )
  in
  Lwt.finalize
    (fun () ->
       match%lwt run ~graph:None ~current_location:None ~initial:true ~start_time with
       | Error _ -> raise (ExitError "")
       | Ok ctx ->
         match options.watch with
         | false ->
           Lwt.return_unit
         | true ->
           match options.mode with
           | Development ->
             Watcher.watch ~ctx ~run
           | _ ->
             (* TODO: noop warning*)
             Lwt.return_unit
    )
    (fun () ->
       let%lwt () = cache.dump () in
       let () = preprocessor.Preprocessor.finalize () in
       Lwt.return_unit
    )

let pack_main options start_time =
  Lwt_main.run (prepare_and_pack options start_time)
