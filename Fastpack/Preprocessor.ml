module M = Map.Make(String)
module FS = FastpackUtil.FS

exception Error of string

type processor = Builtin | Node of string

type config = {
  pattern_s : string;
  pattern : Re.re;
  processors : string list;
}


type t = {
  get_processors : string -> string list;
  process : Module.location -> string option -> (string * string list * string list) Lwt.t;
  configs : config list;
  finalize : unit -> unit;
}

let debug = Logs.debug

let of_string s =
  let pattern_s, processors =
    match String.(s |> trim |> split_on_char ':') with
    | [] | [""] ->
      raise (Failure "Empty config")
    | pattern_s :: [] | pattern_s :: "" :: [] ->
      pattern_s, ["builtin"]
    | pattern_s :: rest ->
      let processors =
        String.(rest |> concat ":" |> split_on_char '!')
        |> List.filter_map
          (fun s ->
             let s = String.trim s in
             match s = "" with
             | true -> None
             | false ->
               match String.split_on_char '?' s  with
               | [] ->
                 raise (Failure "Empty processor")
               | processor :: [] ->
                 Some processor
               | "builtin" :: "" :: [] ->
                 Some "builtin"
               | processor :: opts :: [] when processor <> "builtin" ->
                 Some (processor ^ "?" ^ opts)
               | _ ->
                 raise (Failure "Incorrect preprocessor config")

          )
      in
      pattern_s, processors
  in
  let pattern =
    try
      Re_posix.compile_pat pattern_s
    with
    | Re_posix.Parse_error ->
      raise (Failure "Pattern regexp parse error. Use POSIX syntax")
  in
  { pattern_s; pattern; processors }


let to_string { pattern_s; processors; _ } =
  Printf.sprintf
    "%s:%s"
    pattern_s
    (String.concat "!" processors)


let all_transpilers = FastpackTranspiler.[
  ReactJSX.transpile;
  StripFlow.transpile;
  Class.transpile;
  ObjectSpread.transpile;
]

let builtin source =
  match source with
  | None ->
    Lwt.fail (Error "Builtin transpiler always expects source")
  | Some source ->
    try
      Lwt.return (FastpackTranspiler.transpile_source all_transpilers source, [], [])
    with
    | FastpackTranspiler.Error.TranspilerError err ->
      Lwt.fail (Error (FastpackTranspiler.Error.error_to_string err))
    | exn ->
      Lwt.fail exn

let empty = {
    get_processors = (fun _ -> []);
    process = (fun _ s -> Lwt.return (CCOpt.get_or ~default:"" s, [], []));
    configs = [];
    finalize = (fun () -> ())
  }

let transpile_all = {
    get_processors = (fun _ -> ["builtin"]);
    process = (fun _ s -> builtin s);
    configs = [];
    finalize = (fun () -> ())
  }

module NodeServer = struct

  let processes = ref []
  let fp_in_ch = ref Lwt_io.zero
  let fp_out_ch = ref Lwt_io.null

  let start output_dir =
    let module FS = FastpackUtil.FS in
    let fpack_binary_path =
      (* TODO: handle on Windows? *)
      (match Sys.argv.(0).[0] with
      | '/' | '.' -> Sys.argv.(0)
      | _ -> FileUtil.which Sys.argv.(0))
      |> FileUtil.readlink
      |> FS.abs_path (Unix.getcwd ())
    in
    let rec find_fpack_root dir =
      if dir = "/"
      then Error.ie "Cannot find fastpack package directory"
      else
      if%lwt Lwt_unix.file_exists @@ FilePath.concat dir "package.json"
      then Lwt.return dir
      else find_fpack_root (FilePath.dirname dir)
    in
    let%lwt fpack_root =
      find_fpack_root @@ FilePath.dirname fpack_binary_path
    in
    let cmd =
      Printf.sprintf "node %s %s"
        (List.fold_left FilePath.concat fpack_root ["node-service"; "index.js"])
        output_dir
    in
    let%lwt (process, ch_in, ch_out) = FS.open_process cmd in
    fp_in_ch := ch_in;
    fp_out_ch := ch_out;
    processes := [process];
    Lwt.return_unit

  let process output_dir loaders filename source =
    let%lwt () =
      if (List.length !processes) = 0 then start output_dir else Lwt.return_unit;
    in
    (* Do not pass binary data through the channel *)
    let source =
      match filename with
      | None -> source
      | Some filename ->
        if FS.is_text_file filename then source else None
    in
    let to_json_string s = `String s in
    let message =
      `Assoc [
        ("loaders", `List (List.map to_json_string loaders));
        ("filename", CCOpt.map_or ~default:(`Null) to_json_string filename);
        ("source", CCOpt.map_or ~default:(`Null) to_json_string source)
      ]
    in
    let%lwt () = Lwt_io.write !fp_out_ch (Yojson.to_string message ^ "\n") in
    let%lwt line = Lwt_io.read_line !fp_in_ch in
    let open Yojson.Safe.Util in
    let data = Yojson.Safe.from_string line in
    let source = member "source" data |> to_string_option in
    let dependencies =
      member "dependencies" data
      |> to_list
      |> List.map to_string_option
      |> List.filter_map (fun item -> item)
    in
    let files =
      member "files" data
      |> to_list
      |> List.map to_string_option
      |> List.filter_map (fun item -> item)
    in
    match source with
    | None ->
      let error = member "error" data |> member "message" |> to_string in
      Lwt.fail (Error error)
    | Some source ->
      debug (fun x -> x "SOURCE: %s" source);
      Lwt.return (source, dependencies, files)

  let finalize () =
    List.iter (fun p -> p#terminate) !processes

end

let make configs base_dir output_dir =

  let processors = ref M.empty in

  let get_processors filename =
    match M.get filename !processors with
    | Some processors -> processors
    | None ->
      let relname = FS.relative_path base_dir filename in
      let p =
        configs
        |> List.fold_left
          (fun acc { pattern; processors; _ } ->
            match Re.exec_opt pattern relname with
            | None -> acc
            | Some _ -> acc @ processors
          )
          []
        |> List.rev
      in
      processors := M.add filename p !processors;
      p
  in

  let process location source =
    match location with
    | Module.EmptyModule | Module.Runtime ->
      begin
        match source with
        | None ->
          Error.ie "Unexpeceted absence of source for builtin / empty module"
        | Some source ->
          Lwt.return (source, [], [])
      end
    | Module.File { filename; preprocessors } ->
      let rec make_chain preprocessors chain =
        match preprocessors with
        | [] -> chain
        | _ ->
          let loaders, rest =
            preprocessors
            |> List.take_drop_while (fun p -> p <> "builtin")
          in
          match loaders with
          | [] ->
            make_chain (List.tl rest) (builtin :: chain)
          | _ ->
            make_chain
              rest
              ((NodeServer.process output_dir loaders filename) :: chain)
      in
      let preprocessors =
        List.map
          (fun (p, opt) -> p ^ (if opt <> "" then "?" ^ opt else ""))
          preprocessors
      in
      let%lwt source, deps, files =
        Lwt_list.fold_left_s
          (fun (source, deps, files) process ->
            let%lwt source, more_deps, more_files = process source in
            Lwt.return (Some source, deps @ more_deps, files @ more_files)
          )
          (source, [], [])
          (make_chain preprocessors [])
      in
      match source with
      | None ->
        Error.ie "Unexpected absence of source after processing"
      | Some source ->
        Lwt.return (source, deps, files)
  in

  Lwt.return {
    get_processors;
    process;
    configs;
    finalize = NodeServer.finalize
  }
