module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace

let get_handler handler { Workspace. patch; remove; _ } =
  let module S = Spider_monkey_ast.Statement in
  let module E = Spider_monkey_ast.Expression in
  let module L = Spider_monkey_ast.Literal in
  let module P = Spider_monkey_ast.Pattern in

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
        patch loc.start.offset 1 "Object.assign(";
        Visit.visit_list
          handler
          (fun handler prop ->
            match prop with
            | E.Object.SpreadProperty (loc, {argument}) ->
              remove loc.start.offset 3;
              Visit.visit_expression handler argument
            | E.Object.Property p ->
              let (loc, _) = p in
              begin
                patch loc.start.offset 0 "{";
                Visit.visit_object_property handler p;
                patch loc._end.offset 0 "}"
              end)
          properties;
        patch loc._end.offset (-1) ")";
        Visit.Break
        end
      else
        Visit.Continue

    | _ -> Visit.Continue;
  in

  let rec pattern_has_rest ({ properties; _ } : P.Object.t)  = List.exists
    (fun prop -> match prop with
      | P.Object.RestProperty _ -> true
      | P.Object.Property (_, { pattern = (_, P.Object pattern); _}) ->
        pattern_has_rest pattern
      | P.Object.Property _ -> false
    ) properties
  in

  let visit_statement (_, stmt) =
    match stmt with
    | S.VariableDeclaration { declarations; _ } ->
      (* - source[start:end] - no
       * - Spider_monkey_ast - documentation ?
       *   https://github.com/facebook/flow/blob/v0.42/src/parser/spider_monkey_ast.ml
       * var {x, ...y} = z;
       * var {x, y} = Object.assign(z, {y: removeProps(z, ['x'])});
       * try {...} catch({x, ...y}) {}
       * try {...} catch($$fp$$) {var {x, y} = Object.assign($$fp$$, {y: removeProps(z, ['x'])});}
       * *)
      let has_rest = List.exists
        (fun (_, { S.VariableDeclaration.Declarator. id; _ }) ->
          match id with
          | (_, P.Object pattern) -> pattern_has_rest pattern
          | _ -> false
        )
        declarations
      in
      if has_rest then
        begin
          print_endline "Yes rest";
          Visit.Continue
        end
      else
        begin
          print_endline "No rest";
          Visit.Continue
        end
    | _ -> Visit.Continue
  in {
    Visit.
    visit_statement;
    visit_expression;
  }
