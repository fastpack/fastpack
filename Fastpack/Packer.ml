module StringSet = Set.Make(String)

type pack_error_reason =
  | InvalidEntryPoint of string

exception PackError of pack_error_reason

let read_file file_name =
  Lwt_io.with_file ~mode:Lwt_io.Input file_name Lwt_io.read

let emit out graph entry =
  let emit bytes = Lwt_io.write out bytes in
  let rec emit_module ?(seen=StringSet.empty) m =
    if StringSet.mem m.Module.id seen
    then Lwt.return seen
    else
      let seen = StringSet.add m.Module.id seen in
      let Some workspace = m.Module.workspace in
      let ctx = Module.DependencyMap.empty in
      let dependencies = DependencyGraph.lookup_dependencies graph m in
      let%lwt (ctx, seen) = Lwt_list.fold_left_s
          (fun (ctx, seen) (dep, Some m) ->
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
  let%lwt source = read_file m.filename in
  let (workspace, dependencies) = Analyze.analyze m.id m.filename source in
  let m = { m with workspace = Some workspace } in
  DependencyGraph.add_module graph m;
  let%lwt () = Lwt_list.iter_p (
      fun ({ Dependency. request } as req) ->
        (match%lwt Dependency.resolve req with
         | None ->
           Lwt_io.write Lwt_io.stderr ("ERROR: cannot resolve: " ^ request ^ "\n");
         | Some resolved ->
           let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
             | None ->
               let id = Module.make_id resolved in
               let m = { Module. id = id; filename = resolved; workspace = None } in
               process graph m
             | Some m ->
               Lwt.return m
           in
           DependencyGraph.add_dependency graph m (req, Some dep_module);
           Lwt.return_unit
        )
    ) dependencies in
  Lwt.return m

let check_entry filename =
  let pwd = FileUtil.pwd () in
  let filename = FilePath.make_absolute pwd filename in
  try%lwt
    let%lwt _ = Lwt_unix.stat filename in
    Lwt.return filename
  with Unix.Unix_error _ ->
    raise (PackError (InvalidEntryPoint filename))

let pack entry_filename =
  let graph = DependencyGraph.empty () in
  let%lwt entry_filename = check_entry entry_filename in
  let entry = {
    Module.
    id = Module.make_id entry_filename;
    filename = entry_filename;
    workspace = None;
  } in
  let%lwt entry = process graph entry in
  let%lwt () = emit Lwt_io.stdout graph entry in
  Lwt.return_unit

let pack_main entry =
  Lwt_main.run (pack entry)
