
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


let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename

let relative_name { package_dir; _} filename =
  String.(
    sub
      filename
      (length package_dir + 1)
      (length filename - length package_dir - 1)
  )

let read_module ctx filename =
  let filename = abs_path ctx.package_dir filename in

  if not (FilePath.is_subdir filename ctx.package_dir)
  then raise (PackError (ctx, CannotLeavePackageDir filename));

  let%lwt id, source =
    match Str.string_match (Str.regexp "^builtin:") filename 0 with
    | true ->
      (* TODO: handle builtins *)
      Lwt.return (filename, "")
    | false ->
      let%lwt source =
        try%lwt
          Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
        with Unix.Unix_error _ ->
          raise (PackError (ctx, CannotReadModule filename))
      in
      Lwt.return (Module.make_id (relative_name ctx filename), source)
  in
  Lwt.return {
    Module.
    id;
    filename = filename;
    workspace = Workspace.of_string source;
    scope = FastpackUtil.Scope.empty;
  }

let ie s = failwith ("Internal Error: " ^ s)
