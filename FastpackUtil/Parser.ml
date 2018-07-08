
let parse_source source =
  let parse_options = Some Flow_parser.Parser_env.({
      esproposal_nullish_coalescing = false; (* TODO: what's this? *)
      esproposal_optional_chaining = false;
      esproposal_class_instance_fields = true;
      esproposal_class_static_fields = true;
      esproposal_decorators = true;
      esproposal_export_star_as = true;
      types = true;
      use_strict = false;
    })
  in
  Flow_parser.Parser_flow.program source ~parse_options
