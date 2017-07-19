module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Spider_monkey_ast.Statement
module E = Spider_monkey_ast.Expression
module L = Spider_monkey_ast.Literal
module P = Spider_monkey_ast.Pattern

type pattern_action = Drop
                    | Remove of (int * int) list

let get_handler handler transpile_source scope
    { Workspace. sub; sub_loc; patch; remove; patch_loc; _ } =

  let tmp_var = scope.Util. tmp_var in

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
    let (remove_props : string list ref) = ref [] in
    let (assignments : string list ref) = ref [] in
    let property_action prop =
      match prop with
      | P.Object.Property (_, {key; pattern=(_, pattern); _}) ->
        begin
          let some_name =
            match key with
            | P.Object.Property.Identifier (_, name) ->
              Some ("\"" ^ name ^ "\"")
            (* TODO: Computed is complex. May require adding another name
             *  Example: let {[0 + 1]: {y}} = {1: {y: 500}};
             * *)
            | P.Object.Property.Computed (loc, E.Identifier _) ->
              Some (sub_loc loc)
            | _ -> None
          in
          begin
            match some_name with
            | Some name ->
              remove_props := !remove_props @ [name];
              begin
                match pattern with
                | P.Object pattern ->
                  (* TODO: prettify name handling *)
                  let new_object_name =
                    if name.[0] = '"'
                    then object_name ^ "." ^ (String.sub name 1 ((String.length name) - 2))
                    else object_name ^ "[" ^ name ^ "]"
                  in
                  let action, _assignments =
                    pattern_action new_object_name pattern
                  in
                  begin
                    assignments := !assignments @ _assignments;
                    action
                  end
                | _ -> Remove []
              end
            | _ -> Remove []
          end;
        end

      | P.Object.RestProperty (_, {argument = (loc, _)}) ->
        assignments :=
          !assignments
          @ [(sub_loc loc)
             ^ " = "
             ^ (Util.removeProps object_name !remove_props)
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
      List.iter
        (fun declarator ->
          let (loc, { S.VariableDeclaration.Declarator. id; init }) = declarator in
          let has_rest = match id with
            | (_, P.Object pattern) -> pattern_has_rest pattern
            | _ -> false
          in
          match has_rest, id, init with
          | true, (id_loc, P.Object pattern), Some (init_loc, init_expr) ->
            (* TODO: get object_name properly *)
            let object_name =
              match init_expr with
              | E.Identifier _ -> sub_loc init_loc
              | _ ->
                let name = tmp_var () in
                let source =
                  Printf.sprintf "%s = %s" name @@ sub_loc init_loc
                in
                let transpiled = transpile_source scope source in
                begin
                  patch id_loc.start.offset 0 @@ transpiled ^ ", ";
                  name
                end
            in
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
                if object_name != (sub_loc init_loc)
                  then patch_loc init_loc object_name;
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
