module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace

let transpile program { Workspace. const; remove; _ } =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

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
              remove loc.start.offset 3;
              Visit.visit_expression handler argument
            | E.Object.Property p ->
              let (loc, _) = p in
              begin
                const loc.start.offset 0 "{";
                Visit.visit_object_property handler p;
                const loc._end.offset 0 "}"
              end
          )
      in

      if has_spread
        then begin
          const loc.start.offset 1 "Object.assign(";
          transpile_spread properties;
          const loc._end.offset (-1) ")";
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
