module M = Map.Make(String)

exception Error of string

type option_value = Boolean of bool
                  | Number of float
                  | String of string

type processor = Builtin | Node of string

type config = {
  pattern_s : string;
  pattern : Re.re;
  processors : string list;
}

type process_f = string -> string * string list

type t = {
  get_processors : string -> string list;
  process : string -> string -> (string * string list) Lwt.t;
  configs : config list;
  finalize : unit -> unit;
}

let config_re = Re_posix.compile_pat "^([^:]+)(:([a-zA-Z_][^?]+)(\\?(.*))?)?$"

let of_string s =
  let pattern_s, processors =
    match String.(s |> trim |> split_on_char ':') with
    | [] | [""] ->
      raise (Failure "Empty config")
    | pattern_s :: "" :: [] ->
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
    try
      Lwt.return (FastpackTranspiler.transpile_source all_transpilers source, [])
    with
    | FastpackTranspiler.Error.TranspilerError err ->
      Lwt.fail (Error (FastpackTranspiler.Error.error_to_string err))
    | exn ->
      Lwt.fail exn

let empty = {
    get_processors = (fun _ -> []);
    process = (fun _ s -> Lwt.return (s, []));
    configs = [];
    finalize = (fun () -> ())
  }

let transpile_all = {
    get_processors = (fun _ -> []);
    process = (fun _ s -> builtin s);
    configs = [];
    finalize = (fun () -> ())
  }

module NodeServer = struct

  let processes = ref []
  let fp_in_ch = ref Lwt_io.zero
  let fp_out_ch = ref Lwt_io.null

  let start () =
    let module FS = FastpackUtil.FS in
    let fpack_binary_path =
      (* TODO: how to handle it on Windows? *)
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
      Printf.sprintf "node %s"
      @@ List.fold_left FilePath.concat fpack_root ["node-service"; "index.js"]
    in
    let%lwt (process, ch_in, ch_out) = FS.open_process cmd in
    fp_in_ch := ch_in;
    fp_out_ch := ch_out;
    processes := [process];
    Lwt.return_unit

  let process loader options source =
    let%lwt () =
      if (List.length !processes) = 0 then start () else Lwt.return_unit;
    in
    let options =
      options
      |> M.bindings
      |> List.map
        (fun (key, value) ->
           key,
           match value with
           | Boolean value -> `Bool value
           | Number value -> `Float value
           | String value -> `String value
        )
    in
    let message =
      `Assoc [
        ("loader", `String loader);
        ("params", `Assoc options);
        ("source", `String source)
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
    match source with
    | None -> failwith "node error received"
    | Some source -> Lwt.return (source, dependencies)

  let finalize () =
    List.iter (fun p -> p#terminate) !processes

end

let make configs =

  let processors = ref M.empty in

  let get_processors filename =
    match M.get filename !processors with
    | Some processors -> processors
    | None ->
      let p =
        configs
        |> List.fold_left
          (fun acc { pattern; processors; _ } ->
            match Re.exec_opt pattern filename with
            | None -> acc
            | Some _ -> acc @ processors
          )
          []
      in
      processors := M.add filename p !processors;
      p
  in

  let process _filename _source =
    failwith "not implemented"
    (* let%lwt source, build_dependencies = *)
    (*   Lwt_list.fold_left_s *)
    (*     (fun (source, dependencies) processor -> *)
    (*        let%lwt (source, new_dependencies) = processor source in *)
    (*        Lwt.return (source, dependencies @ new_dependencies) *)
    (*     ) *)
    (*     (source, []) *)
    (*     (get_processors filename) *)
    (* in *)
    (* Lwt.return (source, build_dependencies) *)
  in

  Lwt.return { get_processors; process; configs; finalize = NodeServer.finalize }



