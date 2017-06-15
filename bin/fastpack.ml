module Module = struct
  type t = {
    filename : string;
  }

end

module Dependency = struct
  type t = {
    request : string;
    source : string;
  }

  let from_program filename program =

    let module S = Spider_monkey_ast.Statement in
    let module E = Spider_monkey_ast.Expression in
    let module L = Spider_monkey_ast.Literal in

    let dependencies = ref [] in

    let find_import_statement (_, stmt) =
      match stmt with
      | S.ImportDeclaration {
          source = (_, { value = L.String request });
        } -> dependencies := { request; source = filename; }::!dependencies
      | _ -> ()
    in

    let find_require_expression (_, expr) = match expr with
      | E.Call {
          callee = (_, E.Identifier (_, "require"));
          arguments = [E.Expression (_, E.Literal { value = L.String request })]
        } -> dependencies := { request; source = filename; }::!dependencies
      | _ -> ()
    in

    let handler = {
      Fastpack_visit.
      visit_statement = find_import_statement;
      visit_expression = find_require_expression;
    } in

    Fastpack_visit.visit handler program;

    !dependencies

  let resolve request =
    let basedir = FilePath.dirname request.source in
    Fastpack_resolve.resolve request.request basedir

end

module DependencyGraph = struct
  type t = {
    modules : (string, Module.t) Hashtbl.t;
    dependencies : (string, (Dependency.t * Module.t option)) Hashtbl.t;
    dependents : (string, Module.t) Hashtbl.t;
  }

  let empty ?(size=200) = {
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
    | _ -> ()

end

let read_file file_name =
  Lwt_io.with_file ~mode:Lwt_io.Input file_name Lwt_io.read

let%lwt () =

  let graph = DependencyGraph.empty ~size:100 in

  let rec process (m : Module.t) =
    DependencyGraph.add_module graph m;
    print_endline (" *** Processing: " ^ m.filename);
    let%lwt src = read_file m.filename in
    let (ast, errors) = Parser_flow.program_file src None in
    let deps = Dependency.from_program m.filename ast in
    Lwt_list.iter_p (
      fun ({ Dependency. request } as req) ->
        (match%lwt Dependency.resolve req with
         | None ->
           print_endline ("REQUEST: " ^ request);
           print_endline "ERROR: cannot resolve";
           Lwt.return ()
         | Some r ->
           print_endline ("REQUEST: " ^ request);
           print_endline ("RESOLVE: " ^ r);
           match DependencyGraph.lookup_module graph r with
           | None -> process { Module. filename = r }
           | Some _ -> Lwt.return ()
        )
    ) deps
  in

  let pwd = FileUtil.pwd () in
  let entry = {
    Module.
    filename = FilePath.make_absolute pwd "./example/index.js"
  } in
  process entry;


