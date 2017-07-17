module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace

let transpile program patcher =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

  let rec handler =
    let visit_expression expr =
      List.fold_left (fun result {Visit. visit_expression; _} ->
          match result with
          | Visit.Break -> Visit.Break
          | Visit.Continue -> visit_expression expr
        ) Visit.Continue @@ handlers ()
    in
    let visit_statement stmt =
      List.fold_left (fun result {Visit. visit_statement; _} ->
          match result with
          | Visit.Break -> Visit.Break
          | Visit.Continue -> visit_statement stmt
        ) Visit.Continue @@ handlers ()
    in
    { Visit. visit_expression; visit_statement }
  and handlers _ = [
    Spread.get_handler handler patcher
  ]
  in
  Visit.visit handler program

let test source =
  let (program, _errors) = Parser_flow.program_file source None in
  let workspace = ref (Workspace.of_string source) in
  let to_string workspace =
    let ctx = Fastpack.Module.DependencyMap.empty in
    let bytes = ref @@ Lwt_bytes.create 65535 in
    let (_, ch) = Lwt_io.pipe ~out_buffer:(!bytes) () in
    Workspace.write ch workspace ctx
    >> Lwt.return
       @@ Lwt_bytes.to_string
       @@ Lwt_bytes.extract !bytes 0
       @@ Int64.to_int
       @@ Lwt_io.position ch
  in
  begin
    transpile program @@ Workspace.make_patcher workspace;
    Lwt_main.run (to_string !workspace)
  end
