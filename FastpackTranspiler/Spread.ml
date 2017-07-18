module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace

let get_handler handler { Workspace. const; remove; _ } =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in

  let visit_expression ((loc: Loc.t), expr) =
    match expr with
    | E.Object { properties } ->
      let has_spread = List.exists (fun prop -> match prop with
          | E.Object.SpreadProperty _ -> true
          | _ -> false
        ) properties
      in

      if has_spread
      then
        begin
        const loc.start.offset 1 "Object.assign(";
        List.iter
          (fun prop ->
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
              end)
          properties;
        const loc._end.offset (-1) ")";
        Visit.Break
        end
      else
        Visit.Continue
    | _ -> Visit.Continue;
  in

  let visit_statement (_, _) = Visit.Continue

  in {
    Visit.
    visit_statement;
    visit_expression;
  }
