(** source map v3 *)
module SourceMap = struct
  type t = {
    file : string option;
    source_root : string option;
    sources : string list;
    sources_content: string option list;
    names: string list;
    mappings: bytes
  }

  let of_json data =
    let open Yojson.Safe.Util in
    let file = member "file" data |> to_string_option in
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

module SourceMapGenerator = struct

  type pos = {
    gen_line : int;
    gen_column : int;
    src_line : int;
    src_column : int;
  }

  type t = {
    source_map : SourceMap.t;
    mutable pos : pos;
    mappings : Buffer.t;
  }

  let initial_pos = {
    gen_line = 1;
    gen_column = 0;
    src_line = 0;
    src_column = 0;
  }

  let create ?file ?source_root ?(sources=[]) ?(sources_content=[]) ?(names=[]) () = {
    source_map = {
      file;
      source_root;
      sources;
      sources_content;
      names;
      mappings = "";
    };
    pos = initial_pos;
    mappings = Buffer.create 42;
  }

  let to_source_map gen =
    { gen.source_map with mappings = Buffer.to_bytes gen.mappings }

  let add_mapping gen gen_line gen_column src_line src_column =
    let { gen_line = prev_gen_line; gen_column = prev_gen_column; _ } = gen.pos in

    let gen_line_diff = gen_line - prev_gen_line in
    if gen_line_diff > 0 then
      Buffer.add_string gen.mappings (String.make gen_line_diff ';')
    else if prev_gen_column > 0 then
      Buffer.add_char gen.mappings ',';

    let prev_gen_column = if gen_line_diff > 0 then 0 else prev_gen_column in

    if prev_gen_column = 0 then
      Base64VLQ.encode_int gen.mappings gen_column
    else
      Base64VLQ.encode_int gen.mappings (gen_column - prev_gen_column);

    Base64VLQ.encode_int gen.mappings 0;

    gen.pos <- { gen_line; gen_column; src_line; src_column; };

end
