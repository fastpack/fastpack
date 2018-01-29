module M = Map.Make(String)

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
  process : string -> string -> (string * string list) Lwt.t;
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

let empty s =
  s, []

let all_transpilers = FastpackTranspiler.[
  ReactJSX.transpile;
  StripFlow.transpile;
  Class.transpile;
  ObjectSpread.transpile;
]

let builtin source =
  (* TODO: handle TranspilerError *)
  Lwt.return (FastpackTranspiler.transpile_source all_transpilers source, [])

let node _s =
  failwith "Node preprocessor is not implemented"

let make configs =

  let processors = ref M.empty in

  let get_processors filename =
    match M.get filename !processors with
    | Some processors -> processors
    | None ->
      let p =
        configs
        |> List.filter_map
          (fun { pattern; processor; _ } ->
            match Re.exec_opt pattern filename with
            | None -> None
            | Some _ ->
              match processor with
              | Builtin -> Some builtin
              | Node _ -> failwith "Cannot build Node processor"
          )
      in
      processors := M.add filename p !processors;
      p
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

  { process }



