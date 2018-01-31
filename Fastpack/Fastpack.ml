
module Version = Version
module Error = Error
module Mode = PackerUtil.Mode
module Target = PackerUtil.Target
module Cache = PackerUtil.Cache
module Context = PackerUtil.Context
module Preprocessor = Preprocessor
module Reporter = Reporter
module RegularPacker = RegularPacker
module FlatPacker = FlatPacker

module Stats = struct
  type t = JSON

  let to_string (t: t) =
    match t with
    | JSON -> "json"
end

open PackerUtil


exception PackError = PackerUtil.PackError

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n%s"
    (Context.to_string ctx)
    (Error.to_string ctx.package_dir error)

type options = {
  input : string option;
  output : string option;
  mode : Mode.t option;
  target : Target.t option;
  cache : Cache.strategy option;
  preprocess : Preprocessor.config list option;
  postprocess : string list option;
  stats : Stats.t option;
  watch : bool option;
}

let empty_options = {
    input = None;
    output = None;
    mode = None;
    target = None;
    cache = None;
    preprocess = None;
    postprocess = None;
    stats = None;
    watch = None;
}

let default_options =
  {
    input = Some "index.js";
    output = Some "./bundle";
    mode = Some Production;
    target = Some Application;
    cache = Some Normal;
    preprocess = None;
    postprocess = None;
    stats = None;
    watch = None;
  }

let merge_options o1 o2 =
  let merge v1 v2 =
    match v1, v2 with
    | Some _, Some v2 -> Some v2
    | Some value, None | None, Some value -> Some value
    | _ -> None
  in
  {
    input = merge o1.input o2.input;
    output = merge o1.output o2.output;
    mode = merge o1.mode o2.mode;
    target = merge o1.target o2.target;
    cache = merge o1.cache o2.cache;
    preprocess = merge o1.preprocess o2.preprocess;
    postprocess = merge o1.postprocess o2.postprocess;
    stats = merge o1.stats o2.stats;
    watch = merge o1.watch o2.watch;
  }

let pack ~pack_f ~cache ~mode ~target ~preprocessor ~entry_filename ~package_dir channel =
  let ctx = { Context.
    entry_filename;
    package_dir;
    stack = [];
    current_filename = entry_filename;
    mode;
    target;
    resolver = NodeResolver.make ();
    preprocessor
  }
  in
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

let prepare_and_pack cl_options start_time =
  let%lwt current_dir = Lwt_unix.getcwd () in
  let start_dir =
    match cl_options.input with
    | Some filename -> FilePath.dirname @@ FS.abs_path current_dir filename
    | None -> current_dir
  in
  let%lwt package_dir =
    match%lwt find_package_root start_dir with
    | Some dir -> Lwt.return dir
    | None -> Lwt.return start_dir
  in
  let package_json = FilePath.concat package_dir "package.json" in
  let%lwt package_json_options =
    if%lwt Lwt_unix.file_exists package_json then
      read_package_json_options package_json
    else
      Lwt.return_none
  in
  let options =
    match cl_options.output with
    | None -> cl_options
    | Some path ->
      { cl_options with output = Some (FS.abs_path current_dir path)}
  in
  let options =
    merge_options
      default_options
      (match package_json_options with
       | None -> options
       | Some package_json_options -> merge_options package_json_options options)
  in
  (* find root directory *)
  (* if package.json exists parse it and merge options: *)
  (* default package.json command_line *)
  (* open file - create output channel *)
  (* create transpiling function *)
  (* create pack function *)
  (* run pack with parameters calculated *)
  match options.input, options.output with
  | Some input, Some output ->
    let entry_filename = FS.abs_path package_dir input in
    let output_file =
      FS.abs_path package_dir @@ FilePath.concat output "index.js"
    in
    let%lwt () = makedirs @@ FilePath.dirname output_file in
    let%lwt preprocessor =
      match options.preprocess with
      | None -> Preprocessor.make []
      | Some preprocess -> Preprocessor.make preprocess
    in
    let target =
      match options.target with
      | Some target -> target
      | None -> Error.ie "target is not set"
    in
    let%lwt mode, cache, pack_f =
      match options.mode with
      | Some mode ->
        let%lwt cache, pack_f =
          match mode with
          | Mode.Production ->
            Lwt.return (Cache.fake (), FlatPacker.pack)
          | Mode.Test
          | Mode.Development ->
            let cache_prefix =
              (** TODO: account for abs path of the package_dir *)
              Mode.to_string mode ^ "--" ^ Target.to_string target
            in
            let%lwt cache =
              match options.cache with
              | Some Cache.Normal ->
                Cache.create package_dir cache_prefix input
              | Some Cache.Ignore ->
                Lwt.return @@ Cache.fake ()
              | None ->
                Error.ie "Cache strategy is not set"
            in
            Lwt.return (cache, RegularPacker.pack)
        in
        Lwt.return (mode, cache, pack_f)
      | None ->
        Error.ie "mode is not set"
    in
    let pack_postprocess cache ch =
      let pack =
        pack ~pack_f ~cache ~mode ~target ~preprocessor ~entry_filename ~package_dir
      in
      match options.postprocess with
      | None | Some [] ->
        pack ch
      | Some processors ->
        (* pack to memory *)
        let bytes = Lwt_bytes.create 50_000_000 in
        let mem_ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
        let%lwt ret = pack mem_ch in
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
        Lwt.return ret
    in
    let report =
      match options.stats with
      | Some JSON -> Reporter.report_json
      | None -> Reporter.report_string
    in
    let pack_postprocess_report cache start_time =
      let temp_file = Filename.temp_file "" ".bundle.js" in
      Lwt.finalize
        (fun () ->
          let%lwt stats =
            Lwt_io.with_file
              ~mode:Lwt_io.Output
              ~perm:0o640
              ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
              temp_file
              (pack_postprocess cache)
          in
          let%lwt () = Lwt_unix.rename temp_file output_file in
          let%lwt () = report start_time stats in
          Lwt.return_unit
        )
        (fun () ->
           if%lwt Lwt_unix.file_exists temp_file
           then Lwt_unix.unlink temp_file;
        )
    in
    Lwt.finalize
      (fun () ->
         match mode, options.watch with
         | Development, Some true ->
           Watcher.watch package_dir pack_postprocess_report cache start_time
         | _, Some true ->
           (* TODO: convert this into proper error*)
           failwith "Can only watch in development mode"
         | _, None
         | _, Some false ->
           pack_postprocess_report cache start_time
      )
      (fun () ->
         let%lwt () = cache.dump () in
         let () = preprocessor.Preprocessor.finalize () in
         Lwt.return_unit
      )

  | _ ->
    Error.ie "input / output are not provided"


let pack_main options start_time =
  Lwt_main.run (prepare_and_pack options start_time)
