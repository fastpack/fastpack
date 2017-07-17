let transpile program workspace =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

  let add_patch offset_start offset_end patch =
    begin
      workspace := Workspace.patch !workspace {
        Workspace.
        patch;
        offset_start;
        offset_end;
      }
    end
  in

  let const s _ = s in
  let remove = const "" in

  let rec visit_expression ((loc: Loc.t), expr) =
    match expr with
    | E.Object { properties } ->
      let has_spread = List.exists (fun prop -> match prop with
          | E.Object.SpreadProperty _ -> true
          | _ -> false
        ) properties
      in

      let transpile_spread =
        List.iter (fun prop ->
            match prop with
            | E.Object.SpreadProperty (loc, {argument}) ->
              add_patch loc.start.offset (loc.start.offset + 3) remove;
              Visit.visit_expression handler argument
            | E.Object.Property p ->
              let (loc, _) = p in
              begin
                add_patch loc.start.offset loc.start.offset @@ const "{";
                Visit.visit_object_property handler p;
                add_patch loc._end.offset loc._end.offset @@ const "}"
              end
          )
      in

      if has_spread
        then begin
          add_patch loc.start.offset (loc.start.offset + 1) @@ const "Object.assign(";
          transpile_spread properties;
          add_patch (loc._end.offset - 1) loc._end.offset @@ const ")";
          Visit.GoRight
        end
        else
          Visit.GoDeep
    | _ ->
      Visit.GoDeep;

  and visit_statement (_, _) = Visit.GoDeep

  and handler = {
    Visit.
    visit_statement;
    visit_expression;
  }
  in
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
