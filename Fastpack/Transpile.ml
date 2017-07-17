let transpile program workspace =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

  let add_patch offset_start offset_end patch =
    workspace := Workspace.patch !workspace {
      Workspace.
      patch;
      offset_start;
      offset_end;
    }
  in

  let const s _ = s in

  let visit_expression ((loc: Loc.t), expr) =
    let _ = match expr with
    | E.Object _ ->
      add_patch loc.start.offset loc.start.offset @@ const "Object.assign(";
      add_patch loc._end.offset loc._end.offset @@ const ")";
    | _ -> ();
    in Visit.GoDeep
  in

  let visit_statement (_, _) = Visit.GoDeep in

  let handler = {
    Visit.
    visit_statement;
    visit_expression;
  } in
  Visit.visit handler program

let test source =
  let (program, _errors) = Parser_flow.program_file source None in
  let workspace = ref (Workspace.of_string source) in
  let to_string workspace =
    let ctx = Module.DependencyMap.empty in
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
    transpile program workspace;
    Lwt_main.run (to_string !workspace)
  end
