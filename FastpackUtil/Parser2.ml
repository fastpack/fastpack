
let parse_options = Some FlowParser.Parser_env.({
    esproposal_optional_chaining = false;
    esproposal_class_instance_fields = true;
    esproposal_class_static_fields = true;
    esproposal_decorators = true;
    esproposal_export_star_as = true;
    types = true;
    use_strict = false;
  })

let formatError errs =
  errs
  |> List.map (fun (_, err) -> FlowParser.Parse_error.PP.error err)
  |> String.concat "\n"

let parse ~location_str source =
  let open Run.Syntax in
  Run.withContext ("Parsing " ^ location_str) (
    try
      return (FlowParser.Parser_flow.program source ~parse_options)
    with
    | FlowParser.Parse_error.Error args ->
      error (formatError args)
  )

