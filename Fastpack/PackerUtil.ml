
type ctx = {
  entry_filename : string;
  package_dir : string;
  transpile : string -> string -> string;
  stack : Dependency.t list;
  development : bool;
}


let ctx_to_string { package_dir; stack; development; _ } =
  Printf.sprintf "Working directory: %s\n" package_dir
  ^ Printf.sprintf "Mode: %s" (if development then "development" else "production")
  ^ "\nCall stack:\n"
  ^ String.concat "\t\n" @@ List.map Dependency.to_string stack


exception PackError of ctx * Error.reason


let read_module ctx filename =
  (* TODO: uncomment this when the main directory will be set to the correct value *)
  (* if not (FilePath.is_subdir filename ctx.package_dir) *)
  (* then raise (PackError (ctx, CannotLeavePackageDir filename)); *)
  let%lwt source =
    match Str.string_match (Str.regexp "^builtin:") filename 0 with
    | true ->
      Lwt.return ""
    | false ->
      try%lwt
        Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
      with Unix.Unix_error _ ->
        raise (PackError (ctx, CannotReadModule filename))
  in
  Lwt.return {
    Module.
    (* TODO: make more descriptive module id *)
    id = Module.make_id (FilePath.basename filename) filename;
    filename = filename;
    workspace = Workspace.of_string source;
    scope = Scope.empty;
  }
