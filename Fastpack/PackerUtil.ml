
module Mode = struct
  type t = Production | Development | Test

  let to_string m =
    match m with
    | Production -> "production"
    | Development -> "development"
    | Test -> "test"
end

module Target = struct
  type t = Application | EcmaScript6 | CommonJS

  let to_string (t : t) =
    match t with
    | Application -> "Application"
    | EcmaScript6 -> "EcmaScript 6 Module"
    | CommonJS -> "CommonJS Module"
end

module Context = struct
  type t = {
    entry_filename : string;
    package_dir : string;
    transpile : transpile;
    stack : Dependency.t list;
    mode : Mode.t;
    target : Target.t;
  }
  and transpile = t -> string -> string -> string

  let to_string { package_dir; stack; mode; _ } =
    Printf.sprintf "Working directory: %s\n" package_dir
    ^ Printf.sprintf "Mode: %s" (Mode.to_string mode)
    ^ "\nCall stack:\n"
    ^ String.concat "\t\n" @@ List.map Dependency.to_string stack
end



exception PackError of Context.t * Error.reason


let abs_path dir filename =
  FilePath.reduce ~no_symlink:true @@ FilePath.make_absolute dir filename

let relative_name {Context. package_dir; _} filename =
  String.(
    sub
      filename
      (length package_dir + 1)
      (length filename - length package_dir - 1)
  )

let read_module (ctx : Context.t) filename =
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

