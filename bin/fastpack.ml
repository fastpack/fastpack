module Dependency = struct
  type t = {
    request : string;
    source : string;
  }

  let from_program filename program =
    let dependencies = ref [] in
    let visit_statement (_, stmt) = match stmt with
      | Spider_monkey_ast.Statement.ImportDeclaration { source = (_, { value; raw }); _ } ->
        (match value with
         | Spider_monkey_ast.Literal.String request ->
           dependencies := { request; source = filename }::!dependencies
         | _ -> ())
      | _ -> () in
    let handler = {
      Fastpack_visit.default_visit_handler with
      visit_statement = visit_statement;
    } in
    Fastpack_visit.visit handler program;
    !dependencies

end

let read_file file_name =
  Lwt_io.with_file ~mode:Lwt_io.Input file_name Lwt_io.read

let%lwt () =
  let pwd = FileUtil.pwd () in
  let filename = FilePath.make_absolute pwd "./example/index.js" in
  let%lwt src = read_file filename in
  let (ast, errors) = Parser_flow.program_file src None in
  let res = Fastpack_printer.print ast in
  let deps = Dependency.from_program filename ast in
  Lwt_list.iter_s (fun ({ Dependency. request } as req) ->
      print_endline ("Request: " ^ request);
      (match%lwt Fastpack_resolve.resolve req.request (FilePath.dirname filename) with
       | None -> Lwt.return @@ print_endline "Error: cannot resolve"
       | Some r -> Lwt.return @@ print_endline ("Resolve: " ^ r))
    ) deps
