
module Error = Error
module Mode = PackerUtil.Mode
module Target = PackerUtil.Target
module Cache = PackerUtil.Cache
module Context = PackerUtil.Context
module RegularPacker = RegularPacker
module FlatPacker = FlatPacker


open PackerUtil

module Bundle = struct
  type t = Regular | Flat

  let to_string bundle =
    match bundle with
    | Regular -> "Regular"
    | Flat -> "Flat"
end


exception PackError = PackerUtil.PackError

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n%s"
    (Context.to_string ctx)
    (Error.to_string ctx.package_dir error)

type options = {
  input : string option;
  output : string option;
  bundle : Bundle.t option;
  mode : Mode.t option;
  target : Target.t option;
  cache : Cache.strategy option;
  transpile_react_jsx : string list option;
  transpile_class : string list option;
  transpile_flow : string list option;
  transpile_object_spread : string list option;
}

let empty_options = {
    input = None;
    output = None;
    bundle = None;
    mode = None;
    target = None;
    cache = None;
    transpile_react_jsx = None;
    transpile_class = None;
    transpile_flow = None;
    transpile_object_spread = None;
}

let default_options =
  {
    input = Some "index.js";
    output = Some "./bundle/bundle.js";
    bundle = Some Bundle.Regular;
    mode = Some Production;
    target = Some Application;
    cache = Some Normal;
    transpile_react_jsx = None;
    transpile_class = None;
    transpile_flow = None;
    transpile_object_spread = None;
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
    bundle = merge o1.bundle o2.bundle;
    mode = merge o1.mode o2.mode;
    target = merge o1.target o2.target;
    cache = merge o1.cache o2.cache;
    transpile_react_jsx = merge o1.transpile_react_jsx o2.transpile_react_jsx;
    transpile_flow = merge o1.transpile_flow o2.transpile_flow;
    transpile_class = merge o1.transpile_class o2.transpile_class;
    transpile_object_spread = merge o1.transpile_object_spread o2.transpile_object_spread;
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

let build_transpile_f
    { transpile_react_jsx; transpile_class;
      transpile_flow; transpile_object_spread; _ } =
  let react_jsx = CCOpt.get_or ~default:[] transpile_react_jsx in
  let object_spread = CCOpt.get_or ~default:[] transpile_object_spread in
  let cls = CCOpt.get_or ~default:[] transpile_class in
  let flow = CCOpt.get_or ~default:[] transpile_flow in
  match react_jsx, object_spread, cls, flow with
  | [], [], [], [] ->
    fun _ filename s ->
      Logs.debug (fun m -> m "No transpilers: %s" filename);
      s
  | _ ->
    let react_jsx = List.map Str.regexp react_jsx in
    let object_spread = List.map Str.regexp object_spread in
    let cls = List.map Str.regexp cls in
    let flow = List.map Str.regexp flow in
    let test regexps filename transpiler =
      if List.exists (fun r -> Str.string_match r filename 0) regexps
      then [transpiler]
      else []
    in
    fun ctx filename source ->
      let open FastpackTranspiler in
      let filename = relative_name ctx filename in
      let transpilers =
        List.flatten [
          test flow filename StripFlow.transpile;
          test react_jsx filename ReactJSX.transpile;
          test cls filename Class.transpile;
          test object_spread filename ObjectSpread.transpile;
        ]
      in
      match transpilers with
      | [] ->
        Logs.debug (fun m -> m "Transpilers didn't match: %s" filename);
        source
      | _ ->
        Logs.debug (fun m -> m "Transpilers %d: %s" (List.length transpilers) filename);
        transpile_source transpilers source


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
    let output_file = abs_path package_dir output in
    let%lwt () = makedirs @@ FilePath.dirname output_file in
    let transpile_f = build_transpile_f options in
    let mode =
      match options.mode with
      | Some mode -> mode
      | None -> Error.ie "mode is not set"
    in
    let target =
      match options.target with
      | Some target -> target
      | None -> Error.ie "target is not set"
    in
    let%lwt pack_f =
      match options.bundle with
      | Some Bundle.Regular ->
        let cache_prefix = (Mode.to_string mode) in
        let%lwt cache =
          match options.cache with
          | Some Cache.Normal ->
            Cache.create package_dir cache_prefix input
          | Some Cache.Purge ->
            Cache.purge package_dir cache_prefix input
          | Some Cache.Ignore ->
            Lwt.return Cache.fake
          | None ->
            Error.ie "Cache strategy is not set"
        in
        Lwt.return
        @@ RegularPacker.pack ~cache:cache
      | Some Bundle.Flat ->
        Lwt.return
        @@ FlatPacker.pack ~cache:Cache.fake
      | None -> Error.ie "Unexpected Packer"
    in
    let temp_file = Filename.temp_file "" ".bundle.js" in
    Lwt.finalize
      (fun () ->
        let%lwt _ =
          Lwt_io.with_file
            ~mode:Lwt_io.Output
            ~perm:0o640
            ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
            temp_file
          @@ pack ~pack_f ~mode ~target ~transpile_f ~entry_filename ~package_dir
        in
        Lwt_unix.rename temp_file output_file
      )
      (fun () ->
         if%lwt Lwt_unix.file_exists temp_file
         then Lwt_unix.unlink temp_file
      )

  | _ ->
    Error.ie "input / output are not provided"


let pack_main options =
  Lwt_main.run (prepare_and_pack options)
