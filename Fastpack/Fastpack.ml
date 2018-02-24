
module Version = Version
module Error = Error
module Cache = Cache
module Mode = PackerUtil.Mode
module Target = PackerUtil.Target
module Context = PackerUtil.Context
module Preprocessor = Preprocessor
module Reporter = Reporter
module RegularPacker = RegularPacker
module FlatPacker = FlatPacker


open PackerUtil

exception PackError = PackerUtil.PackError
exception ExitError = PackerUtil.ExitError
exception ExitOK = PackerUtil.ExitOK

(* TODO: this makes fpack_test happy, remove when fpack_test is removed *)
let string_of_error = PackerUtil.string_of_error

type options = {
  input : string;
  output : string;
  mode : Mode.t;
  target : Target.t;
  cache : Cache.strategy;
  preprocess : Preprocessor.config list;
  postprocess : string list;
  report : Reporter.report;
  watch : bool;
}

(* TODO: this function may not be needed when tests are ported to Jest *)
let pack ~pack_f ~cache ~mode ~target ~preprocessor ~entry_filename ~package_dir channel =
  let resolver = NodeResolver.make cache preprocessor in
  let%lwt entry_package =
    resolver.find_package package_dir entry_filename
  in
  let ctx = { Context.
    entry_location = None;
    package = Package.empty;
    package_dir;
    output_dir = "";
    stack = [];
    current_location = None;
    mode;
    target;
    resolver;
    preprocessor;
    graph = DependencyGraph.empty ();
  }
  in
  let%lwt entry_location, _ =
    resolve ctx entry_package {
      Dependency.
      request = entry_filename;
      requested_from_filename = package_dir;
    }
  in
  let ctx = {
    ctx with
    entry_location = Some entry_location;
    current_location = Some entry_location
  } in
  pack_f cache ctx channel

let find_package_root start_dir =
  let rec check_dir dir =
    match dir with
    | "/" -> Lwt.return_none
    | _ ->
      let package_json = FilePath.concat dir "package.json" in
      if%lwt Lwt_unix.file_exists package_json
      then Lwt.return_some dir
      else check_dir (FilePath.dirname dir)
  in
  check_dir start_dir

let read_package_json_options _ =
  Lwt.return_none

let prepare_and_pack options start_time =
  let%lwt current_dir = Lwt_unix.getcwd () in
  let%lwt package_dir =
    match%lwt find_package_root current_dir with
    | Some dir -> Lwt.return dir
    | None -> Lwt.return current_dir
  in
  let entry_filename = FS.abs_path current_dir options.input in
  let output_dir = FS.abs_path current_dir options.output in
  let output_file = FilePath.concat output_dir "index.js" in
  let%lwt () = makedirs output_dir in
  let%lwt preprocessor =
    Preprocessor.make
      options.preprocess
      package_dir
      output_dir
  in
  let%lwt cache, cache_report, pack_f =
    match options.mode with
    | Mode.Production ->
      let%lwt cache = Cache.(create Memory) in
      Lwt.return (cache, None, FlatPacker.pack)
    | Mode.Test
    | Mode.Development ->
      let%lwt cache, cache_report =
        match options.cache with
        | Cache.Use ->
          let short_filename =
            entry_filename
            |> FS.relative_path package_dir
            |> String.replace ~sub:"/" ~by:"__"
            |> String.replace ~sub:"." ~by:"___"
          in
          let filename =
            String.concat "-" [
              short_filename;
              Target.to_string options.target;
              package_dir |> Digest.string |> Digest.to_hex;
              Version.github_commit
            ]
          in
          let node_modules = FilePath.concat package_dir "node_modules" in
          let%lwt dir =
            match%lwt FS.try_dir node_modules with
            | Some dir ->
              FilePath.concat (FilePath.concat dir ".cache") "fpack"
              |> Lwt.return
            | None ->
              FilePath.concat (FilePath.concat package_dir ".cache") "fpack"
              |> Lwt.return
          in
          let%lwt () = FS.makedirs dir in
          let cache_filename = FilePath.concat dir filename in
          let%lwt cache = Cache.(create (Persistent cache_filename)) in
          Lwt.return (cache, Some (if cache.starts_empty then "empty" else "used"))
        | Cache.Disable ->
          let%lwt cache = Cache.(create Memory) in
          Lwt.return (cache, Some "disabled")
      in
      Lwt.return (cache, cache_report, RegularPacker.pack)
  in
  let get_context current_filename =
    let resolver = NodeResolver.make cache preprocessor in
    let%lwt entry_package =
      resolver.find_package package_dir entry_filename
    in
    let%lwt package = resolver.find_package package_dir current_filename in
    let ctx = {
      Context.
      entry_location = None;
      current_location = None;
      package_dir;
      output_dir;
      package;
      stack = [];
      mode = options.mode;
      target = options.target;
      resolver;
      preprocessor;
      graph = DependencyGraph.empty ()
    }
    in
    let%lwt entry_location, _ =
      resolve ctx entry_package {
        Dependency.
        request = entry_filename;
        requested_from_filename = package_dir;
      }
    in
    let%lwt current_location, _ =
      resolve ctx package {
        Dependency.
        request = current_filename;
        requested_from_filename = package_dir;
      }
    in
    Lwt.return {
      ctx with
      entry_location = Some entry_location;
      current_location = Some current_location;
    }
  in
  let pack_postprocess cache ctx ch =
    match options.postprocess with
    | [] ->
      pack_f cache ctx ch
    | processors ->
      (* pack to memory *)
      let bytes = Lwt_bytes.create 50_000_000 in
      let mem_ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
      let%lwt ret = pack_f cache ctx mem_ch in
      let%lwt data =
        Lwt_list.fold_left_s
          (fun data cmd ->
            let (stdin, stdout) = Unix.pipe () in
            let%lwt () =
              Lwt_process.(
                pwrite
                  ~env:(Unix.environment ())
                  ~stdout:(`FD_move stdout)
                  (shell cmd)
                  data
              )
            in
            let stdin_ch = Lwt_io.of_unix_fd ~mode:Lwt_io.Input stdin in
            Lwt_io.read stdin_ch
          )
          (Lwt_io.position mem_ch
           |> Int64.to_int
           |> Lwt_bytes.extract bytes 0
           |> Lwt_bytes.to_string)
          processors
      in
      let%lwt () = Lwt_io.write ch data in
      Lwt.return { ret with size = String.length data }
  in
  let report =
    match options.report with
    | JSON -> Reporter.report_json
    | Text -> Reporter.report_string ~cache:cache_report ~mode:(Some options.mode)
  in
  let pack_postprocess_report cache ctx start_time =
    let temp_file = Filename.temp_file "" ".bundle.js" in
    Lwt.finalize
      (fun () ->
        let%lwt stats =
          Lwt_io.with_file
            ~mode:Lwt_io.Output
            ~perm:0o640
            ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
            temp_file
            (pack_postprocess cache ctx)
        in
        let%lwt () = Lwt_unix.rename temp_file output_file in
        let%lwt () = report start_time stats in
        Lwt.return stats
      )
      (fun () ->
         if%lwt Lwt_unix.file_exists temp_file
         then Lwt_unix.unlink temp_file;
      )
  in
  let%lwt ctx = get_context entry_filename in
  let init_run () =
    Lwt.catch
      (fun () -> pack_postprocess_report cache ctx start_time)
      (function
       | PackError (ctx, error) ->
         raise (ExitError (string_of_error ctx error))
       | exn ->
         raise exn
      )
  in
  Lwt.finalize
    (fun () ->
       let%lwt {Reporter. modules; _} = init_run () in
       match options.watch with
       | false ->
         Lwt.return_unit
       | true ->
         match options.mode with
         | Development ->
           Watcher.watch
             pack_postprocess_report
             cache
             ctx.graph
             modules
             package_dir
             entry_filename
             get_context
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
