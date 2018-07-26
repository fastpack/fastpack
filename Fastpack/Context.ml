type t = {
  current_dir : string;
  project_package : Package.t;
  output_dir : string;
  output_file : string;
  entry_location : Module.location;
  current_location : Module.location;
  stack : Module.Dependency.t list;
  mode : Mode.t;
  target : Target.t;
  resolver : Resolver.t;
  preprocessor : Preprocessor.t;
  export_finder : ExportFinder.t;
  cache : Cache.t;
  graph : DependencyGraph.t;
}

let to_string { current_dir; stack; mode; current_location; _ } =
  let stack =
    stack
    |> List.map (Module.Dependency.to_string ~dir:(Some current_dir))
    |> String.concat "\t\n"
  in
  let location_str =
    Module.location_to_string ~base_dir:(Some current_dir) current_location
  in
  Printf.([
      sprintf "Project Directory: %s" current_dir;
      sprintf "Mode: %s" (Mode.to_string mode);
      "Call Stack:" ^ if stack <> ""
                      then sprintf "\n\t%s" stack
                      else " (empty)";
      sprintf "Processing Module: %s" location_str;
    ])
  |> List.fold_left
    (fun acc part -> if part <> "" then acc ^ part ^ "\n" else acc)
    ""

exception PackError of t * Error.reason
exception ExitError of string
exception ExitOK

let string_of_error ctx error =
  Printf.sprintf
    "\n%s\n"
    (Error.to_string ctx.current_dir error)
