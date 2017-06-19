module StringSet = Set.Make(String)

module Dependency = struct
  type t = {
    (** Original request to a dependency *)
    request : string;
    (** The filename this dependency was requested from *)
    requested_from_filename : string;
  }

  let resolve request =
    let basedir = FilePath.dirname request.requested_from_filename in
    FastpackResolver.resolve request.request basedir

  let compare a b = compare
      (a.request, a.requested_from_filename)
      (b.request, b.requested_from_filename)
end

module DependencyMap = Map.Make(struct
    type t = Dependency.t
    let compare = Dependency.compare
  end)

module Module = struct
  type t = {
    (** Opaque module id *)
    id : string;

    (** Absolute module filename *)
    filename : string;

    (** Original module source *)
    workspace : t DependencyMap.t Fastpack_workspace.t option;
  }

  let make_id filename =
    let digest = Digest.string filename in
    Digest.to_hex digest

end

module DependencyGraph = struct
  type t = {
    modules : (string, Module.t) Hashtbl.t;
    dependencies : (string, (Dependency.t * Module.t option)) Hashtbl.t;
    dependents : (string, Module.t) Hashtbl.t;
  }

  let iter_modules iter graph =
    Hashtbl.iter iter graph.modules

  let empty ?(size=200) () = {
    modules = Hashtbl.create size;
    dependencies = Hashtbl.create (size * 20);
    dependents = Hashtbl.create (size * 20);
  }

  let lookup table key =
    try Some (Hashtbl.find table key) with Not_found -> None

  let lookup_module graph filename =
    lookup graph.modules filename

  let lookup_dependencies graph (m : Module.t) =
    Hashtbl.find_all graph.dependencies m.filename

  let add_module graph (m : Module.t) =
    Hashtbl.add graph.modules m.filename m

  let add_dependency graph (m : Module.t) (dep : (Dependency.t * Module.t option)) =
    Hashtbl.add graph.dependencies m.filename dep;
    let (_, dep_module) = dep in
    match dep_module with
    | Some dep_module ->
      Hashtbl.add graph.dependents dep_module.filename m
    | _ ->
      ()

end


module Fastpack_analyze = struct

  let analyze id filename source =
    let (program, _errors) = Parser_flow.program_file source None in

    let module S = Spider_monkey_ast.Statement in
    let module E = Spider_monkey_ast.Expression in
    let module L = Spider_monkey_ast.Literal in

    let dependencies = ref [] in
    let dependency_id = ref 0 in
    let workspace = ref (Fastpack_workspace.of_string source) in

    let dependency_to_module_id ctx dep =
      try
        let m = DependencyMap.find dep ctx in
        m.Module.id
      with |
        Not_found -> "fastpack/not_found"
    in

    let visit_import_declaration ((loc: Loc.t), stmt) =
      match stmt with
      | S.ImportDeclaration {
          source = (_, { value = L.String request });
        } ->
        let rewrite_import = {
          Fastpack_workspace.
          patch = (fun ctx -> "OKOKOK");
          offset_start = loc.start.offset;
          offset_end = loc._end.offset;
        } in
        workspace := Fastpack_workspace.patch !workspace rewrite_import;
        dependency_id := !dependency_id + 1;
        dependencies := {
          Dependency.
          request;
          requested_from_filename = filename;
        }::!dependencies
      | _ -> ()
    in

    let visit_require_call (loc, expr) =
      match expr with
      | E.Call {
          callee = (_, E.Identifier (_, "require"));
          arguments = [E.Expression (_, E.Literal { value = L.String request })]
        } ->
        let dep = {
          Dependency.
          request;
          requested_from_filename = filename;
        } in
        dependency_id := !dependency_id + 1;
        dependencies := dep::!dependencies;
        let rewrite_require = {
          Fastpack_workspace.
          patch = (fun ctx ->
              let module_id = dependency_to_module_id ctx dep in
              Printf.sprintf "__fastpack_require__(\"%s\") // \"%s\" " module_id dep.request
            );
          offset_start = loc.Loc.start.offset;
          offset_end = loc.Loc._end.offset;
        } in
        workspace := Fastpack_workspace.patch !workspace rewrite_require;
      | _ ->
        ()
    in

    let handler = {
      Fastpack_visit.
      visit_statement = visit_import_declaration;
      visit_expression = visit_require_call;
    } in

    Fastpack_visit.visit handler program;

    (!workspace, !dependencies)

end

let read_file file_name =
  Lwt_io.with_file ~mode:Lwt_io.Input file_name Lwt_io.read

let emit_bundle out graph entry =
  let emit bytes = Lwt_io.write out bytes in
  let rec emit_module ?(seen=StringSet.empty) m =
    if StringSet.mem m.Module.id seen
    then Lwt.return seen
    else
      let seen = StringSet.add m.Module.id seen in
      let Some workspace = m.Module.workspace in
      let ctx = DependencyMap.empty in
      let dependencies = DependencyGraph.lookup_dependencies graph m in
      let%lwt (ctx, seen) = Lwt_list.fold_left_s
          (fun (ctx, seen) (dep, Some m) ->
             let%lwt seen = emit_module ~seen:seen m in
             let ctx = DependencyMap.add dep m ctx in
             Lwt.return (ctx, seen))
          (ctx, seen)
          dependencies
      in
      let source = Fastpack_workspace.to_string workspace ctx in
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

let%lwt () =

  let graph = DependencyGraph.empty () in

  let rec process (m : Module.t) =
    let%lwt source = read_file m.filename in
    let (workspace, dependencies) = Fastpack_analyze.analyze m.id m.filename source in
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
                 process m
               | Some m ->
                 Lwt.return m
             in
             DependencyGraph.add_dependency graph m (req, Some dep_module);
             Lwt.return_unit
          )
      ) dependencies in
    Lwt.return m
  in

  let pwd = FileUtil.pwd () in
  let entry_filename = FilePath.make_absolute pwd "./example/index.js" in
  let entry = {
    Module.
    id = Module.make_id entry_filename;
    filename = entry_filename;
    workspace = None;
  } in
  let%lwt entry = process entry in
  emit_bundle Lwt_io.stdout graph entry
