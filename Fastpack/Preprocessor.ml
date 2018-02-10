module M = Map.Make(String)

exception Error of string

type option_value = Boolean of bool
                  | Number of float
                  | String of string

type processor = Builtin | Node of string

type config = {
  pattern_s : string;
  pattern : Re.re;
  processor : processor;
  options : option_value M.t;
}

type process_f = string -> string * string list

type t = {
  get_processors : string -> (string * string) list;
  process : string -> string -> (string * string list) Lwt.t;
  configs : config list;
  finalize : unit -> unit;
}

let config_re = Re_posix.compile_pat "^([^:]+)(:([a-zA-Z_][^?]+)(\\?(.*))?)?$"

let of_string s =
  let pattern_s, processor, options =
    match Re.exec_opt config_re @@ String.trim s with
    | None ->
      raise (Failure "Incorrect config")
    | Some groups ->
      let parts = Re.Group.all groups in
      String.trim parts.(1), String.trim parts.(3), String.trim parts.(5)
  in
  let processor = if processor = "" then "builtin" else processor in
  let pattern =
    try
      Re_posix.compile_pat pattern_s
    with
    | Re_posix.Parse_error ->
      raise (Failure "Pattern regexp parse error. Use POSIX syntax")
  in
  if processor = "builtin" && options <> ""
  then raise (Failure "'builtin' processor does not expect any options (yet!)");
  let processor =
    match processor with
    | "builtin" -> Builtin
    | _ -> Node processor
  in
  let option_value_of_string s =
    match s with
    | "" | "true" -> Boolean true
    | "false" -> Boolean false
    | _ ->
      try
        Number (float_of_string s)
      with
      | Failure _ ->
        String s
  in
  let options =
    options
    |> String.split_on_char '&'
    |> List.filter_map
      (fun s -> if s = "" then None else Some (String.split_on_char '=' s))
    |> List.map
      (fun parts ->
         List.hd parts,
         List.tl parts |> String.concat "" |> option_value_of_string
      )
    |> List.fold_left (fun opts (k, v) -> M.add k v opts) M.empty
  in
  { pattern_s; pattern; processor; options }

let to_string { pattern_s; processor; options; _ } =
  let option_value_to_string opt =
    match opt with
    | Boolean true -> "true"
    | Boolean false -> "false"
    | Number n -> string_of_float n
    | String s -> s
  in
  let options =
    options
    |> M.bindings
    |> List.map (fun (k, v) -> k ^ "=" ^ option_value_to_string v)
    |> String.concat ""
  in
  let processor =
    match processor with
    | Builtin -> "builtin"
    | Node name -> name
  in
  Printf.sprintf
    "%s:%s%s"
    pattern_s
    processor
    (if options <> "" then "?" ^ options else "")


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

  let _processors = ref M.empty in

  let get_processors _filename =
    failwith "reimplement"
    (* match M.get filename !processors with *)
    (* | Some processors -> processors *)
    (* | None -> *)
    (*   let p = *)
    (*     configs *)
    (*     |> List.filter_map *)
    (*       (fun { pattern; processor; options; _ } -> *)
    (*         match Re.exec_opt pattern filename with *)
    (*         | None -> None *)
    (*         | Some _ -> *)
    (*           match processor with *)
    (*           | Builtin -> Some builtin *)
    (*           | Node loader -> Some (NodeServer.process loader options) *)
    (*       ) *)
    (*   in *)
    (*   processors := M.add filename p !processors; *)
    (*   p *)
  in

  let process filename source =
    let%lwt source, build_dependencies =
      Lwt_list.fold_left_s
        (fun (source, dependencies) processor ->
           let%lwt (source, new_dependencies) = processor source in
           Lwt.return (source, dependencies @ new_dependencies)
        )
        (source, [])
        (get_processors filename)
    in
    Lwt.return (source, build_dependencies)
  in

  Lwt.return { get_processors; process; configs; finalize = NodeServer.finalize }



