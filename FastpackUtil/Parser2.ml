module Loc = FlowParser.Loc

let parse_options = Some FlowParser.Parser_env.({
    esproposal_optional_chaining = false;
    esproposal_class_instance_fields = true;
    esproposal_class_static_fields = true;
    esproposal_decorators = true;
    esproposal_export_star_as = true;
    types = true;
    use_strict = false;
  })

let format_error ~source ~errors =
  let lineno_width = 4 in
  let separator = "| " in
  let lines =
    String.lines source
    |> List.mapi (fun i line ->
        let lineno =
          String.pad ~side:`Left ~c:' ' lineno_width (string_of_int (i + 1))
        in
        lineno ^ separator ^ line
      )
    |> Array.of_list
  in
  let errors =
    errors
    |> List.map (fun ((loc : Loc.t), err) ->
        let line = lines.(loc.start.line - 1) in
        let pointer =
          String.pad ~side:`Left ~c:' '
            (lineno_width + String.length separator + loc.start.column + 1)
            "^"
        in
        line ^ "\n" ^ pointer ^ " " ^ FlowParser.Parse_error.PP.error err
      )
    |> String.concat "\n"
  in
  "Parse Errors:\n" ^ errors

let get_suggestion location_str =
  let ext = location_str |> String.split_on_char '.' |> List.rev in
  match ext with
  | [] -> None
  | "css" :: _ ->
    Some (
      "Looks like you are trying to parse the CSS file. "
      ^ "Try to preprocess them like this:\n"
      ^ "  --preprocess='\\.css$:style-loader!css-loader'"
    )
  | _ ->
    None

let parse ~location_str source =
  Run.(withContext ("Parsing " ^ location_str) (
    try
      return (FlowParser.Parser_flow.program source ~parse_options)
    with
    | FlowParser.Parse_error.Error errors ->
      match get_suggestion location_str with
      | Some suggestion ->
        with_suggestion suggestion (error "Parse Error")
      | None ->
        error (format_error ~source ~errors)
  ))

