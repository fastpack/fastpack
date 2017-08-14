module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal
module P = Ast.Pattern
module F = Ast.Function

type pattern_action = Drop
                    | Patch of (int * int * string) list

type name_kind = Quoted | Unquoted | Generated of Loc.t

let get_handler handler transpile_source scope
    { Workspace. sub; sub_loc; patch; remove; patch_loc; _ } =

  let tmp_var = scope.Util. tmp_var in

  let transpile_assignment name value =
    let source = Printf.sprintf "var %s = %s;" name value in
    let ret = transpile_source scope source in
    (name, String.sub ret 4 ((String.length ret) - 5))
  in

  let new_name value =
    let name = tmp_var () in
    transpile_assignment name value
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
    let (before : string list ref) = ref [] in
    let (after : string list ref) = ref [] in

    let property_action prop =
      match prop with
      | P.Object.Property (_, {key; pattern=(_, pattern); _}) ->
        begin
          let some_name =
            match key with
            | P.Object.Property.Identifier (_, name) ->
              Some (name, Quoted)
            | P.Object.Property.Computed (_, E.Identifier (_, name)) ->
              Some (name, Unquoted)
            | P.Object.Property.Computed (loc, _) ->
              let name, value = new_name @@ sub_loc loc in
              begin
                before := !before @ [value];
                Some (name, Generated loc)
              end
            | _ -> None
          in
          begin
            match some_name with
            | Some (name, kind) ->
              let prop_name =
                match kind with
                | Quoted -> "\"" ^ name ^ "\""
                | _ -> name
              in
              remove_props := !remove_props @ [prop_name];
              begin
                match pattern with
                | P.Object pattern ->
                  let new_object_name =
                    match kind with
                    | Quoted -> object_name ^ "." ^ name
                    | _ -> object_name ^ "[" ^ name ^ "]"
                  in
                  let action, _before, _after =
                    pattern_action new_object_name pattern
                  in
                  begin
                    after := !after @ _after;
                    before := !before @ _before;
                    let key_patch =
                      match kind with
                      | Generated {start={offset=s; _};
                                   _end={offset=e; _}; _}
                        -> Some (s, e - s, name)
                      | _ -> None
                    in
                    match key_patch, action with
                    | None, action -> action
                    | _, Drop -> action
                    | Some patch, Patch patches -> Patch (patch::patches)
                  end
                | _ -> Patch []
              end
            | _ -> Patch []
          end;
        end

      | P.Object.RestProperty (_, {argument = (loc, _)}) ->
        after := !after
                 @ [(sub_loc loc)
                    ^ " = " ^ (Util.removeProps object_name !remove_props)
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
          (start, loc._end.offset - start, "")
        in
        let patches =
          List.flatten
          @@ List.mapi
            (fun i prop ->
               match List.nth property_actions i with
               | Patch patches -> patches
               | Drop -> match prop with
                 | P.Object.RestProperty (loc, _) ->
                   [ maybe_comma (i = 0) loc ]
                 | P.Object.Property (loc, _) ->
                   [ maybe_comma (i = 0) loc ]
            )
            properties
        in Patch patches
      end
    in
    (action, !before, !after)
  in

  let visit_function (_, {F. params; body; _}) =
    let (params, rest) = params in
    let params_with_rest =
      List.map
        (fun (_, p) -> match p with
           | P.Object pattern -> pattern_has_rest pattern
           | _ -> false
        )
        params
    in
    (* TODO: make sure this is needed and works correctly *)
    let rest_has_rest =
      match rest with
      | Some (_, {F.RestElement. argument=(_, P.Object pattern)}) ->
        pattern_has_rest pattern
      | _ -> false
    in
    if (List.exists (fun x -> x) params_with_rest) || rest_has_rest then begin
      let param_patches = List.fold_left2
          (fun result has_rest param ->
             match has_rest, param with
             | true, (loc, P.Object _) ->
               let name = tmp_var () in
               let _, assignment = transpile_assignment (sub_loc loc) name in
               begin
                 patch_loc loc name;
                 result @ [assignment]
               end
             | _ ->
               Visit.visit_pattern handler param;
               result
          )
          ([] : string list)
          params_with_rest
          params
      in
      let rest_patches =
        if rest_has_rest then
          match rest with
          | Some (loc, {F.RestElement. argument=(loc_p, P.Object _)}) ->
            let name = tmp_var () in
            let _, assignment = transpile_assignment (sub_loc loc_p) name in
            begin
              patch_loc loc name;
              [assignment]
            end
          | _ -> []
        else []
      in
      match (param_patches @ rest_patches) with
      | [] ->
        Visit.Continue
      | body_patches ->
        let body_patch = "let " ^ (String.concat ", " body_patches) ^ "; " in
        begin
          match body with
          | F.BodyBlock ((loc, _) as block) ->
            patch (loc.start.offset + 1) 0 body_patch;
            Visit.visit_block handler block;
          | F.BodyExpression (loc, expr)  ->
            patch loc.start.offset 0 @@ "{" ^ body_patch ^ "return (";
            Visit.visit_expression handler (loc, expr);
            patch loc._end.offset 0 ");}";
        end;
        Visit.Break
    end
    else
      Visit.Continue
  in

  let visit_expression ((loc: Loc.t), expr) =
    match expr with
    | E.Assignment {left=(loc_left, P.Object {properties; _});
                    right=(loc_right, _); _} ->
      begin
        let has_rest = List.exists (fun prop -> match prop with
            | P.Object.RestProperty _ -> true
            | _ -> false
          ) properties
        in
        if has_rest then
          begin
            let name, r_value = new_name @@ sub_loc loc_right in
            let _, rest = transpile_assignment (sub_loc loc_left) name in
            patch_loc loc @@ Printf.sprintf "(%s, %s)" r_value rest;
            Visit.Break
          end
        else
          Visit.Continue
      end
    | E.Object { properties } ->
      let has_spread properties = List.exists (fun prop -> match prop with
          | E.Object.SpreadProperty _ -> true
          | _ -> false
        ) properties
      in
      if has_spread properties
      then
        begin
          patch loc.start.offset 1 "Object.assign({},";
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

  let visit_statement (_, stmt) =
    match stmt with
    | S.ForOf { left; body=(loc, stmt) as body; _} ->
      let patch_body patches =
        let s_patches = "let " ^ String.concat ", " patches ^ ";" in
        match patches, stmt with
        | ([], _) ->
          Visit.visit_statement handler body;
        | _, S.Block _ ->
          patch (loc.start.offset + 1) 0 s_patches;
          Visit.visit_statement handler body;
        | _ ->
          patch loc.start.offset 0 @@ "{" ^ s_patches;
          Visit.visit_statement handler body;
          patch loc._end.offset 0 "}"
      in
      begin
        match left with
        | S.ForOf.LeftDeclaration (_, {declarations; _}) ->
          let patches = List.fold_left
              (fun patches declarator ->
                 let (loc, { S.VariableDeclaration.Declarator. id; _}) = declarator in
                 let has_rest = match id with
                   | (_, P.Object pattern) -> pattern_has_rest pattern
                   | _ -> false
                 in
                 match has_rest, id  with
                 | true, (id_loc, P.Object _) ->
                   let name = tmp_var () in
                   let _, assignment = transpile_assignment (sub_loc loc) name in
                   begin
                     patch_loc id_loc name;
                     patches @ [assignment]
                   end;
                 | _ ->
                   Visit.visit_variable_declarator handler declarator;
                   []
              )
              []
              declarations
          in
          patch_body patches;
        | S.ForOf.LeftExpression (loc, E.Object {properties}) -> ();
          let has_spread properties = List.exists (fun prop -> match prop with
              | E.Object.SpreadProperty _ -> true
              | _ -> false
            ) properties
          in
          if has_spread properties then
            let name = tmp_var () in
            let _, assignment = transpile_assignment (sub_loc loc) name in
            begin
              patch_loc loc name;
              patch_body [assignment];
            end;
        | _ -> ();
      end;
      Visit.Break;
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
             let object_name =
               match init_expr with
               | E.Identifier (_,name) -> name
               | _ ->
                 let name, value = new_name @@ sub_loc init_loc in
                 begin
                   patch id_loc.start.offset 0 @@ value ^ ", ";
                   name
                 end
             in
             let action, before, after =
               pattern_action object_name pattern
             in
             let s_before = String.concat ", " before in
             let s_after = String.concat ", " after in
             begin
               match action with
               | Drop ->
                 patch_loc loc @@ String.concat ", " @@ before @ after
               | Patch patches ->
                 if s_before <> "" then
                   patch id_loc.start.offset 0 @@ s_before ^ ", ";
                 List.iter
                   (fun (start, offset, s) -> patch start offset s) patches;
                 if object_name != (sub_loc init_loc)
                 then patch_loc init_loc object_name;
                 patch init_loc._end.offset 0 @@ ", " ^ s_after
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
    visit_function;
    visit_pattern = Visit.do_nothing;
  }
