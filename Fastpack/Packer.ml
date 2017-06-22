module StringSet = Set.Make(String)

type pack_error_reason =
  | CannotReadModule of string

exception PackError of pack_error_reason

let read_module filename =
  let%lwt source =
    try%lwt
      Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
    with Unix.Unix_error _ ->
      raise (PackError (CannotReadModule filename))
  in
  Lwt.return {
    Module.
    id = Module.make_id filename;
    filename = filename;
    workspace = Workspace.of_string source;
  }

let read_entry_module filename =
  let pwd = FileUtil.pwd () in
  let filename = FilePath.make_absolute pwd filename in
  read_module filename

let emit out graph entry =
  let emit bytes = Lwt_io.write out bytes in
  let rec emit_module ?(seen=StringSet.empty) m =
    if StringSet.mem m.Module.id seen
    then Lwt.return seen
    else
      let seen = StringSet.add m.Module.id seen in
      let workspace = m.Module.workspace in
      let ctx = Module.DependencyMap.empty in
      let dependencies = DependencyGraph.lookup_dependencies graph m in
      let%lwt (ctx, seen) = Lwt_list.fold_left_s
          (fun (ctx, seen) (dep, m) ->
             match m with
             | None ->
               (* TODO: emit stub module for the missing dep *)
               Lwt.return (ctx, seen)
             | Some m ->
               let%lwt seen = emit_module ~seen:seen m in
               let ctx = Module.DependencyMap.add dep m ctx in
               Lwt.return (ctx, seen))
          (ctx, seen)
          dependencies
      in
      let source = Workspace.to_string workspace ctx in
      let%lwt () = emit @@ Printf.sprintf "
\"%s\": function(module, exports, __fastpack_require__) {
%s
},
      " m.id source in
      Lwt.return seen
  in

  let%lwt () = emit "{\n" in
  let%lwt _ = emit_module entry in
  let%lwt () = emit "\n}" in
  Lwt.return_unit


let rec process graph (m : Module.t) =
  let source = m.Module.workspace.Workspace.value in
  let (workspace, dependencies) = Analyze.analyze m.id m.filename source in
  let m = { m with workspace = workspace } in
  DependencyGraph.add_module graph m;
  let%lwt () = Lwt_list.iter_p (
      fun ({ Dependency. request } as req) ->
        (match%lwt Dependency.resolve req with
         | None ->
           Lwt_io.write Lwt_io.stderr ("ERROR: cannot resolve: " ^ request ^ "\n");
         | Some resolved ->
           let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
             | None ->
               let%lwt m = read_module resolved in
               process graph m
             | Some m ->
               Lwt.return m
           in
           DependencyGraph.add_dependency graph m (req, Some dep_module);
           Lwt.return_unit
        )
    ) dependencies in
  Lwt.return m

let pack entry_filename =
  let graph = DependencyGraph.empty () in
  let%lwt entry = read_entry_module entry_filename in
  let%lwt entry = process graph entry in
  let%lwt () = emit Lwt_io.stdout graph entry in
  Lwt.return_unit

let pack_main entry =
  Lwt_main.run (pack entry)
