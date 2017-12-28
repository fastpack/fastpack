
module Scope = Scope
module Parser = Parser
module Printer = Printer
module PackerUtil = PackerUtil
module Error = Error

module RegularPacker = RegularPacker

module StringSet = Set.Make(String)
open PackerUtil

let get_entry_point filename =
  let filename = FilePath.make_absolute (FileUtil.pwd ()) filename in
  (* TODO: how to identify the package dir? closest parent with package.json? Yes! *)
  let package_dir = FilePath.dirname filename in
  (filename, package_dir)

let pack pack transpile channel entry_filename =
  let (entry_filename, package_dir) = get_entry_point entry_filename in
  let ctx = {
    entry_filename;
    package_dir;
    transpile = transpile package_dir;
    stack = [];
    mode = Production;
    out = channel;
  }
  in
  pack ctx

let pack_main ?(transpile=(fun _ _ p -> p)) entry =
  Lwt_main.run (pack RegularPacker.pack transpile Lwt_io.stdout entry)
