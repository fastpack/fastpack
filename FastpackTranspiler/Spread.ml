module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Spider_monkey_ast.Statement
module E = Spider_monkey_ast.Expression
module L = Spider_monkey_ast.Literal
module P = Spider_monkey_ast.Pattern

type pattern_action = Drop of string list * string list
                    | Nop

let get_handler handler { Workspace. sub_loc; patch; remove; patch_loc; _ } =

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

  let process_pattern ({ properties; _ } : P.Object.t) =
    match properties with
    | (P.Object.RestProperty (_, {argument}))::[] ->
      begin
        match argument with
        | _, (P.Identifier {name = (loc, _); _}) ->
          Drop ([sub_loc loc], [])
        | _ -> Nop
      end
    | _ -> Nop
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
       *
          let {
            x: { a: xa, [d]: f, ...asdf },
            y: { ...d },
            ...g
          } = complex;
          let { x: {a: xa, [d]: f, asdf }, y: {d}, g} = Object.assign(
                complex,
                {x: Object.assign(complex.x, {asdf: removeProps(complex.x, ["a", d])})},
                {y: Object.assign(complex.y, {d: removeProps(complex.y, [])})}
                {g: removeProps(complex, ["g"])}
          )
          *)
      List.iter
        (fun declarator ->
          let (_, { S.VariableDeclaration.Declarator. id; _ }) = declarator in
          let loc, p = id in
          let has_rest = match p with
            | P.Object pattern -> pattern_has_rest pattern
            | _ -> false
          in
          if has_rest then
          begin
            print_endline "Yes rest";
            let action = match id with
              | (_, P.Object pattern) -> process_pattern pattern
              | _ -> Nop
            in
            match action with
            | Drop (name::[], _) -> patch_loc loc name
            | _ -> ()
          end
          else
            Visit.visit_variable_declarator handler declarator
        )
        declarations;
      Visit.Break
    | _ -> Visit.Continue
  in {
    Visit.
    visit_statement;
    visit_expression;
  }
