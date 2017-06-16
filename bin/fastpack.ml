module Module = struct
  type t = {
    (** Absolute module filename *)
    filename : string;
    (** Original module source *)
    workspace : Fastpack_workspace.t option;
  }

end

module Dependency = struct
  type t = {
    (** Original request to a dependency *)
    request : string;
    (** The filename this dependency was requested from *)
    requested_from_filename : string;
  }

  let resolve request =
    let basedir = FilePath.dirname request.requested_from_filename in
    Fastpack_resolve.resolve request.request basedir

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

  let analyze filename source =
    let (program, _errors) = Parser_flow.program_file source None in

    let module S = Spider_monkey_ast.Statement in
    let module E = Spider_monkey_ast.Expression in
    let module L = Spider_monkey_ast.Literal in

    let dependencies = ref [] in
    let workspace = ref (Fastpack_workspace.of_string source) in

    let visit_import_declaration ((loc: Loc.t), stmt) =
      match stmt with
      | S.ImportDeclaration {
          source = (_, { value = L.String request });
        } ->
        let rewrite_import = {
          Fastpack_workspace.
          patch = "OKOKOK";
          offset_start = loc.start.offset;
          offset_end = loc._end.offset;
        } in
        workspace := Fastpack_workspace.patch !workspace rewrite_import;
        dependencies := {
          Dependency.
          request;
          requested_from_filename = filename;
        }::!dependencies
      | _ -> ()
    in

    let visit_require_call (_, expr) =
      match expr with
      | E.Call {
          callee = (_, E.Identifier (_, "require"));
          arguments = [E.Expression (_, E.Literal { value = L.String request })]
        } ->
        dependencies := {
          Dependency.
          request;
          requested_from_filename = filename;
        }::!dependencies
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

let%lwt () =

  let graph = DependencyGraph.empty () in

  let rec process (m : Module.t) =
    let%lwt source = read_file m.filename in
    let (workspace, dependencies) = Fastpack_analyze.analyze m.filename source in
    DependencyGraph.add_module graph { m with workspace = Some workspace };
    Lwt_list.iter_p (
      fun ({ Dependency. request } as req) ->
        (match%lwt Dependency.resolve req with
         | None ->
           print_endline ("ERROR: cannot resolve: " ^ request);
           Lwt.return_unit
         | Some r ->
           match DependencyGraph.lookup_module graph r with
           | None ->
             let m = { Module. filename = r; workspace = None } in
             process m
           | Some _ ->
             Lwt.return_unit
        )
    ) dependencies
  in

  let pwd = FileUtil.pwd () in
  let entry = {
    Module.
    filename = FilePath.make_absolute pwd "./example/index.js";
    workspace = None;
  } in
  let%lwt () = process entry in
  let () = DependencyGraph.iter_modules (fun _k m ->
      if m.filename = "/Users/andreypopp/Workspace/fastpack/example/index.js"
      then
        match m.workspace with
        | Some workspace ->
          print_endline ("*** " ^ m.filename ^ " ***");
          print_endline (Fastpack_workspace.to_string workspace)
        | None ->
          ()
      else ()
    ) graph in
  Lwt.return_unit;


