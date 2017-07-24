module Visit = Fastpack.Visit

let rec transpile program scope patcher =

  let rec handler =
    let handlers () =
      List.map (fun f -> f handler transpile_source scope patcher)
      [
        Spread.get_handler;
        Flow.get_handler;
      ]
    in

    let and_result exec result =
      match exec, result with
      | Visit.Break, _ -> Visit.Break
      | _, Visit.Break  -> Visit.Break
      | _ -> Visit.Continue
    in

    let visit_expression expr =
      List.fold_left (fun result {Visit. visit_expression; _} ->
          and_result (visit_expression expr) result
        ) Visit.Continue @@ handlers ()
    in

    let visit_statement stmt =
      List.fold_left (fun result {Visit. visit_statement; _} ->
          and_result (visit_statement stmt) result
        ) Visit.Continue @@ handlers ()
    in

    let visit_function func =
      List.fold_left (fun result {Visit. visit_function; _} ->
          and_result (visit_function func) result
        ) Visit.Continue @@ handlers ()
    in

    let visit_pattern pattern =
      List.fold_left (fun result {Visit. visit_pattern; _} ->
          and_result (visit_pattern pattern) result
        ) Visit.Continue @@ handlers ()
    in


    {
      Visit.
      visit_expression;
      visit_statement;
      visit_function;
      visit_pattern;
    }

  in
  Visit.visit handler program

and transpile_source scope source =
  let module Workspace = Fastpack.Workspace in
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
    let patcher = Workspace.make_patcher workspace in
    transpile program scope patcher;
    Lwt_main.run (to_string !workspace)
  end
