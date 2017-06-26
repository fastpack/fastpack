(** source map v3 *)
module SourceMap = struct
  type t = {
    file : string;
    source_root : string option;
    sources : string list;
    sources_content: string option list;
    names: string list;
    mappings: string
  }

  let of_json data =
    let open Yojson.Safe.Util in
    let file = member "file" data |> to_string in
    let source_root = member "sourceRoot" data |> to_string_option in
    let sources = member "sources" data |> to_list |> List.map to_string in
    let sources_content = member "sourcesContent" data |> to_list |> List.map to_string_option in
    let names = member "namaes" data |> to_list |> List.map to_string in
    let mappings = member "namaes" data |> to_string in
    { file; source_root; sources; sources_content; names; mappings }
end

(** source map index, a concatenation of several source maps *)
module SourceMapIndex = struct

  type offset = {
    line : int;
    column: int;
  }

  type section = {
    offset : offset;
    map : SourceMap.t;
  }

  type t = {
    file : string;
    sections : section list;
  }

  let offset_of_json data =
    let open Yojson.Safe.Util in
    let line = member "line" data |> to_int in
    let column = member "column" data |> to_int in
    { line; column; }

  let section_of_json data =
    let open Yojson.Safe.Util in
    let offset = member "offset" data |> offset_of_json in
    let map = member "map" data |> SourceMap.of_json in
    { offset; map }

  let of_json data =
    let open Yojson.Safe.Util in
    let file =
      member "file" data
      |> to_string
    in
    let sections =
      member "sections" data
      |> to_list
      |> List.map (fun item -> section_of_json item)
    in
    { file; sections; }

end
