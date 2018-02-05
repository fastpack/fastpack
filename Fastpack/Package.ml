type t = {
  filename : string option;
  entry_point : string;
}

let empty = {
  filename = None;
  entry_point = "index.js";
}

let of_file filename =
  let%lwt data = Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read in
  let data = Yojson.Safe.from_string data in
  let open Yojson.Safe.Util in
  let main = member "main" data |> to_string_option in
  let module_ = member "module" data |> to_string_option in
  let entry_point =
    match module_, main with
    | Some module_, _ -> module_
    | None, Some main -> main
    | None, None -> "index.js"
  in
  Lwt.return {filename = Some filename; entry_point}

let create filename data =
  let data = Yojson.Safe.from_string data in
  let open Yojson.Safe.Util in
  let main = member "main" data |> to_string_option in
  let module_ = member "module" data |> to_string_option in
  let entry_point =
    match module_, main with
    | Some module_, _ -> module_
    | None, Some main -> main
    | None, None -> "index.js"
  in
  {filename = Some filename; entry_point}
