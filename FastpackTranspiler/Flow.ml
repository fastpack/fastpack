module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Spider_monkey_ast.Statement
module E = Spider_monkey_ast.Expression
module L = Spider_monkey_ast.Literal
module P = Spider_monkey_ast.Pattern
module F = Spider_monkey_ast.Function
module C = Spider_monkey_ast.Class

let get_handler handler _ _ { Workspace. patch_loc; remove_loc; _} =

  let visit_expression _ = Visit.Continue in

  let remove_if_some node =
    match node with
    | Some (loc, _) -> remove_loc loc;
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
      remove_if_some typeAnnotation;

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
      remove_if_some typeAnnotation;

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
    remove_if_some returnType;
    remove_if_some typeParameters;
    Visit.Continue;
  in

  let visit_statement (loc, stmt) =
    match stmt with
    | S.VariableDeclaration { declarations; _ } ->
      List.iter
        (fun declarator ->
          let (_, { S.VariableDeclaration.Declarator. id; _ }) = declarator in
          patch_pattern id
        )
        declarations;
      Visit.Continue;

    | S.ClassDeclaration {body=(_, {body}); typeParameters; superTypeParameters; _} ->
      remove_if_some typeParameters;
      remove_if_some superTypeParameters;
      List.iter
        (fun element ->
           match element with
           | C.Body.Property (loc, {value=None; typeAnnotation=Some _; _}) ->
             remove_loc loc;
           | _ -> ();
        )
        body;
      Visit.Continue;

    | S.DeclareClass _
    | S.InterfaceDeclaration _
    | S.TypeAlias _ ->
      remove_loc loc;
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
