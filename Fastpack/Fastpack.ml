
module Scope = Scope
module Parser = Parser
module Printer = Printer
module PackerUtil = PackerUtil
module Error = Error

module RegularPacker = RegularPacker

module StringSet = Set.Make(String)
open PackerUtil

type options = {
  input: string option;
  output: string option;
  flat : bool option;
  development: bool option;
  transpile_jsx : string list option;
  transpile_class : string list option;
  transpile_flow : string list option;
  transpile_object_spread : string list option;
}

let empty_options = {
    input = None;
    output = None;
    flat = None;
    development = None;
    transpile_jsx = None;
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
    transpile_jsx = None;
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
    transpile_jsx = merge o1.transpile_jsx o2.transpile_jsx;
    transpile_flow = merge o1.transpile_flow o2.transpile_flow;
    transpile_class = merge o1.transpile_class o2.transpile_class;
    transpile_object_spread = merge o1.transpile_object_spread o2.transpile_object_spread;
  }

let get_entry_point filename =
  let filename = FilePath.make_absolute (FileUtil.pwd ()) filename in
  (* TODO: how to identify the package dir? closest parent with package.json? Yes! *)
  let package_dir = FilePath.dirname filename in
  (filename, package_dir)

let pack pack_f transpile_f channel entry_filename =
  let (entry_filename, package_dir) = get_entry_point entry_filename in
  let ctx = {
    entry_filename;
    package_dir;
    transpile = transpile_f package_dir;
    stack = [];
    development = false;
  }
  in
  pack_f ctx channel

(* let prepare_and_pack cl_options = *)
(*   let%lwt current_dir = Lwt_unix.getcwd () in *)
(*   let abs_path filename = *)
(*     FilePath.reduce ~no_symlink:true *)
(*     @@ FilePath.make_absolute current_dir filename *)
(*   in *)
(*   let start_dir = *)
(*     match cl_options.input with *)
(*     | Some filename -> abs_path filename *)
(*     | None -> current_dir *)
(*   in *)
(*   let package_dir = *)
(*     match find_package_root start_dir with *)
(*     | Some dir -> dir *)
(*     | None -> start_dir *)
(*   in *)
(*   let package_json = FilePath.concat package_dir "package.json" in *)
(*   let%lwt package_json_options = *)
(*     if%lwt Lwt_unix.file_exists package_json then *)
(*       read_package_json_options package_json with *)
(*     else *)
(*       Lwt.return_none *)
(*   in *)
(*   let options = *)
(*     merge_options *)
(*       default_options *)
(*       (if package_json_options <> None *)
(*        then merge_options package_json_options cl_options *)
(*        else cl_options) *)
(*   in *)
(*   (1* find root directory *1) *)
(*   (1* if package.json exists parse it and merge options: *1) *)
(*   (1* default package.json command_line *1) *)
(*   (1* open file - create output channel *1) *)
(*   (1* create transpiling function *1) *)
(*   (1* create pack function *1) *)
(*   (1* run pack with parameters calculated *1) *)
(*   failwith "Not Implemented" *)

exception PackError = PackerUtil.PackError

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n%s"
    (PackerUtil.ctx_to_string ctx)
    (Error.to_string error)

let pack_main ?(transpile=(fun _ _ p -> p)) entry =
  Lwt_main.run (pack RegularPacker.pack transpile Lwt_io.stdout entry)
