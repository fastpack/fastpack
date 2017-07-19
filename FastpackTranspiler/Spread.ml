module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Spider_monkey_ast.Statement
module E = Spider_monkey_ast.Expression
module L = Spider_monkey_ast.Literal
module P = Spider_monkey_ast.Pattern

type pattern_action = Drop
                    | Remove of (int * int) list

let get_handler handler { Workspace. sub; sub_loc; patch; remove; patch_loc; _ } =

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

  let rec pattern_action object_name (object_pattern: P.Object.t) =
    let (remove_keys : string list ref) = ref [] in
    let (assignments : string list ref) = ref [] in
    let property_action prop =
      match prop with
      | P.Object.Property (_, {key; pattern=(_, pattern); _}) ->
        begin
          match key with
          | P.Object.Property.Identifier (_, name) ->
            remove_keys := !remove_keys @ ["\"" ^ name ^ "\""];
            begin
            match pattern with
              | P.Object pattern ->
                let action, _assignments =
                  pattern_action (object_name ^ "." ^ name) pattern
                in
                begin
                  assignments := !assignments @ _assignments;
                  action
                end
              | _ -> Remove []
            end;
          | _ -> Remove [];
        end

      | P.Object.RestProperty (_, {argument = (loc, _)}) ->
        assignments :=
          !assignments
          @ [Printf.sprintf "%s = $fpack.removeProps(%s, [%s])"
              (sub_loc loc) object_name (String.concat "," !remove_keys)
            ];
        Drop
    in
    let {P.Object. properties; _} = object_pattern in
    let property_actions = List.map property_action properties in
    let drop_all = List.for_all
        (fun action -> match action with
          | Drop -> true
          | _ -> false)
        property_actions
    in
    let action = if drop_all
      then Drop
      else begin
        (* let len = List.length property_actions in *)
        let maybe_comma is_first (loc : Loc.t) =
          let start = if is_first
            then loc.start.offset
            else match Util.find_comma_pos sub loc.start.offset with
            | Some pos -> pos
            | None -> loc.start.offset
          in
          (start, loc._end.offset - start)
        in
        let patches =
          List.flatten
          @@ List.mapi
            (fun i prop ->
              match List.nth property_actions i with
              | Remove patches -> patches
              | Drop -> match prop with
                | P.Object.RestProperty (loc, _) ->
                  [ maybe_comma (i = 0) loc ]
                | P.Object.Property (loc, _) ->
                  [ maybe_comma (i = 0) loc ]
            )
            properties
        in Remove patches
      end
    in
    (action, !assignments)
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
          let (loc, { S.VariableDeclaration.Declarator. id; init }) = declarator in
          let has_rest = match id with
            | (_, P.Object pattern) -> pattern_has_rest pattern
            | _ -> false
          in
          match has_rest, id, init with
          | true, (_, P.Object pattern), Some (init_loc, _) ->
            (* TODO: get object_name properly *)
            let object_name = sub_loc init_loc in
            let action, assignments =
              pattern_action object_name pattern
            in
            let s_assigments = String.concat ", " assignments in
            begin
              match action with
              | Drop ->
                patch_loc loc s_assigments
              | Remove patches ->
                List.iter (fun (s, o) -> remove s o) patches;
                patch init_loc._end.offset 0 @@ ", " ^ s_assigments
            end
          | _ ->
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
