
module PackerUtil = PackerUtil
module Error = Error
module RegularPacker = RegularPacker

module StringSet = Set.Make(String)
open PackerUtil

exception PackError = PackerUtil.PackError

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n%s"
    (PackerUtil.ctx_to_string ctx)
    (Error.to_string error)

type options = {
  input: string option;
  output: string option;
  flat : bool option;
  development: bool option;
  transpile_react_jsx : string list option;
  transpile_class : string list option;
  transpile_flow : string list option;
  transpile_object_spread : string list option;
}

let empty_options = {
    input = None;
    output = None;
    flat = None;
    development = None;
    transpile_react_jsx = None;
    transpile_class = None;
    transpile_flow = None;
    transpile_object_spread = None;
}

let default_options =
  {
    input = Some "index.js";
    output = Some "./bundle/bundle.js";
    flat = Some false;
    development = Some false;
    transpile_react_jsx = None;
    transpile_class = None;
    transpile_flow = None;
    transpile_object_spread = None;
  }

let merge_options o1 o2 =
  let merge_bool b1 b2 =
    match b1, b2 with
    | Some b1, Some b2 -> Some (b1 || b2)
    | Some value, None | None, Some value -> Some value
    | _ -> None
  in
  let merge v1 v2 =
    match v1, v2 with
    | Some _, Some v2 -> Some v2
    | Some value, None | None, Some value -> Some value
    | _ -> None
  in
  {
    input = merge o1.input o2.input;
    output = merge o1.output o2.output;
    flat = merge_bool o1.flat o2.flat;
    development = merge_bool o1.development o2.development;
    transpile_react_jsx = merge o1.transpile_react_jsx o2.transpile_react_jsx;
    transpile_flow = merge o1.transpile_flow o2.transpile_flow;
    transpile_class = merge o1.transpile_class o2.transpile_class;
    transpile_object_spread = merge o1.transpile_object_spread o2.transpile_object_spread;
  }

let pack pack_f transpile_f entry_filename package_dir channel =
  let ctx = {
    entry_filename;
    package_dir;
    transpile = transpile_f package_dir;
    stack = [];
    development = false;
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

let rec makedirs dir =
  match%lwt FastpackResolver.stat_option dir with
  | None ->
    let%lwt () = makedirs (FilePath.dirname dir) in
    Lwt_unix.mkdir dir 0o777
  | Some stat ->
    match stat.st_kind with
    | Lwt_unix.S_DIR -> Lwt.return_unit
    | _ -> failwith (dir ^ "is not a directory")

let prepare_and_pack cl_options =
  let%lwt current_dir = Lwt_unix.getcwd () in
  let abs_path dir filename =
    FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename
  in
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
    merge_options
      default_options
      (match package_json_options with
       | None -> cl_options
       | Some package_json_options -> merge_options package_json_options cl_options)
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
    let transpile_f = fun _ _ s -> s in
    let pack_f = RegularPacker.pack in
    let run =
      pack pack_f transpile_f entry_filename package_dir
    in
    Lwt_io.(with_file
              ~mode:Output
              ~perm:0o640
              ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
              output_file
              run)
  | _ ->
    failwith "Input / Output are not provided. Should not happen"


let pack_main options =
  Lwt_main.run (prepare_and_pack options)
