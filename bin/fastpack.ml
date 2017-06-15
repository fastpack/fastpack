module Dependency = struct
  type t = {
    request : string
  }

  let from_program filename program =
    let dependencies = Hashtbl.create 10 in
    let visiter = {
      Fastpack_visit.default_visit_handler with
      visit_statement = fun (_, stmt) -> (match stmt with
          | Spider_monkey_ast.Statement.ImportDeclaration { source = (_, { value; raw }); _ } ->
            (match value with
             | Spider_monkey_ast.Literal.String request ->
               Hashtbl.add dependencies request { request }
             | _ -> ());
            ()
          | _ -> ())
    } in
    Fastpack_visit.visit visiter program;
    dependencies

end

let read_file file_name =
  Lwt_io.with_file ~mode:Lwt_io.Input file_name Lwt_io.read

let%lwt () =
  let%lwt src = read_file "./example/index.js" in
  let (ast, errors) = Parser_flow.program_file src None in
  let res = Fastpack_printer.print ast in
  let deps = Dependency.from_program ast in
  Hashtbl.iter (fun k v -> print_endline k) deps;
  Lwt_io.print res
