module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Spider_monkey_ast.Statement
module E = Spider_monkey_ast.Expression
module L = Spider_monkey_ast.Literal
module P = Spider_monkey_ast.Pattern
module F = Spider_monkey_ast.Function

let get_handler handler _ _ { Workspace. patch_loc; remove_loc; sub_loc; _} =

  let visit_expression _ = Visit.Continue in

  let removeAnnotation typeAnnotation =
    match typeAnnotation with
    | Some (loc, _) -> (); remove_loc loc;
    | None -> ();
  in

  let rec patch_pattern ((loc, pattern): P.t) =
    match pattern with
    | P.Object { properties; typeAnnotation; } ->
      Visit.visit_list
        handler
        (fun _ prop -> match prop with
           | P.Object.Property (_,{ key = _key; pattern; shorthand = _shorthand }) ->
             patch_pattern pattern
           | P.Object.RestProperty (_,{ argument }) ->
             patch_pattern argument
        ) properties;
      removeAnnotation typeAnnotation;

    | P.Array { elements; typeAnnotation; } ->
      Visit.visit_list
        handler
        (fun _ element -> match element with
           | None -> ()
           | Some (P.Array.Element pattern) ->
             patch_pattern pattern
           | Some (P.Array.RestElement (_,{ argument })) ->
             patch_pattern argument)
        elements;
      removeAnnotation typeAnnotation;

    | P.Assignment { left; _ } ->
      patch_pattern left;

    | P.Identifier { name=(_, name); typeAnnotation; optional; _ } ->
      begin
        match typeAnnotation, optional with
        | Some _, _
        | _, true -> patch_loc loc name;
        | _ -> ();
      end;

    | P.Expression _ -> ();
  in

  let visit_function (_, {F. params; returnType; typeParameters; _}) =
    let (params, _) = params in
    Visit.visit_list handler (fun _ p -> patch_pattern p) params;
    removeAnnotation returnType;
    begin
      match typeParameters with
      | None -> ();
      | Some (loc, _) -> print_endline @@ sub_loc loc;
    end;
    Visit.Continue;
  in

  let visit_statement (_, stmt) =
    match stmt with
    | S.VariableDeclaration { declarations; _ } ->
      List.iter
        (fun declarator ->
          let (_, { S.VariableDeclaration.Declarator. id; _ }) = declarator in
          patch_pattern id
        )
        declarations;
      Visit.Continue;
    | _ -> Visit.Continue;
  in
  {
    Visit.
    visit_statement;
    visit_expression;
    visit_function;
    visit_pattern=Visit.do_nothing;
  }
