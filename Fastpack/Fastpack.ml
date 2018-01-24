
module Version = Version
module Error = Error
module Mode = PackerUtil.Mode
module Target = PackerUtil.Target
module Cache = PackerUtil.Cache
module Context = PackerUtil.Context
module RegularPacker = RegularPacker
module FlatPacker = FlatPacker


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
  transpile : string list option;
  postprocess : string list option;
}

let empty_options = {
    input = None;
    output = None;
    mode = None;
    target = None;
    cache = None;
    transpile = None;
    postprocess = None;
}

let default_options =
  {
    input = Some "index.js";
    output = Some "./bundle/bundle.js";
    mode = Some Production;
    target = Some Application;
    cache = Some Normal;
    transpile = None;
    postprocess = None;
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
    transpile = merge o1.transpile o2.transpile;
    postprocess = merge o1.postprocess o2.postprocess;
  }

let pack ~pack_f ~mode ~target ~transpile_f ~entry_filename ~package_dir channel =
  let ctx = { Context.
    entry_filename;
    package_dir;
    transpile = transpile_f;
    stack = [];
    current_filename = entry_filename;
    mode;
    target;
    resolver = NodeResolver.make ()
  }
  in
  pack_f ctx channel

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

let build_transpile_f { transpile; _ } =
  match transpile with
  | None | Some [] ->
    fun _ filename s ->
      Logs.debug (fun m -> m "No transpilers: %s" filename);
      s
  | Some patterns ->
    let open FastpackTranspiler in
    let transpilers = [
        StripFlow.transpile;
        ReactJSX.transpile;
        Class.transpile;
        ObjectSpread.transpile;
      ]
    in
    (* TODO: handle invalid regexp *)
    let regexps = List.map Str.regexp patterns in
    fun ctx filename source ->
      let filename = relative_name ctx filename in
      if List.exists (fun r -> Str.string_match r filename 0) regexps
      then transpile_source transpilers source
      else source


let prepare_and_pack cl_options =
  let%lwt current_dir = Lwt_unix.getcwd () in
  let start_dir =
    match cl_options.input with
    | Some filename -> FilePath.dirname @@ abs_path current_dir filename
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
      { cl_options with output = Some (abs_path current_dir path)}
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
    let entry_filename = abs_path package_dir input in
    let output_file =
      abs_path package_dir @@ FilePath.concat output "index.js"
    in
    let%lwt () = makedirs @@ FilePath.dirname output_file in
    let transpile_f = build_transpile_f options in
    let target =
      match options.target with
      | Some target -> target
      | None -> Error.ie "target is not set"
    in
    let%lwt mode, pack_f =
      match options.mode with
      | Some mode ->
        let%lwt pack_f =
          match mode with
          | Mode.Production ->
            Lwt.return @@ FlatPacker.pack ~cache:Cache.fake
          | Mode.Test
          | Mode.Development ->
            let cache_prefix =
              (** TODO: account for abs path on the package_dir *)
              Mode.to_string mode ^ "--" ^ Target.to_string target
            in
            let%lwt cache =
              match options.cache with
              | Some Cache.Normal ->
                Cache.create package_dir cache_prefix input
              | Some Cache.Ignore ->
                Lwt.return Cache.fake
              | None ->
                Error.ie "Cache strategy is not set"
            in
            Lwt.return @@ RegularPacker.pack ~cache
        in
        Lwt.return (mode, pack_f)
      | None ->
        Error.ie "mode is not set"
    in
    let pack_and_postprocess ch =
      let pack =
        pack ~pack_f ~mode ~target ~transpile_f ~entry_filename ~package_dir
      in
      match options.postprocess with
      | None | Some [] ->
        pack ch
      | Some processors ->
        (* pack to memory *)
        let bytes = Lwt_bytes.create 50000000 in
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
    let temp_file = Filename.temp_file "" ".bundle.js" in
    Lwt.finalize
      (fun () ->
        let%lwt ret =
          Lwt_io.with_file
            ~mode:Lwt_io.Output
            ~perm:0o640
            ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
            temp_file
            pack_and_postprocess
        in
        let%lwt () = Lwt_unix.rename temp_file output_file in
        Lwt.return ret
      )
      (fun () ->
         if%lwt Lwt_unix.file_exists temp_file
         then Lwt_unix.unlink temp_file
      )

  | _ ->
    Error.ie "input / output are not provided"


let pack_main options =
  Lwt_main.run (prepare_and_pack options)
