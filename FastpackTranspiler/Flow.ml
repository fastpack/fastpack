module Visit = Fastpack.Visit
module Workspace = Fastpack.Workspace
module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal
module P = Ast.Pattern
module F = Ast.Function
module C = Ast.Class

let get_handler handler _ _ { Workspace. sub; patch_loc; remove_loc; remove; _} =

  (* let remove_list = *)
  (*   List.iter (fun (loc, _) -> remove_loc loc) *)
  (* in *)

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

  let patch_class {C.
                    implements;
                    body=(_, {body});
                    typeParameters;
                    superTypeParameters; _
                  } =
    begin
      match implements with
      | [] -> ();
      | _ ->
        let s, _ = List.hd implements in
        let e, _ = List.hd @@ List.rev implements in
        let implements_start = Util.find_string_start
            "implements"
            sub
            (s.start.offset - 9)
        in
        match implements_start with
        | Some s -> remove s (e._end.offset - s)
        | None -> failwith "implements not found"
    end;
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
  in

  let patch_import_declaration
      (loc, {S.ImportDeclaration. importKind; specifiers; _}) =

    let patch_specifier len (i, specifier) =
      let is_last = i = (len - 1) in

      let maybe_comma_after (loc : Loc.t) =
        if is_last
        then loc._end.offset
        else match Util.find_comma_pos ~direction:Util.GoForward sub loc._end.offset with
          | Some pos -> pos
          | None -> loc._end.offset
      in

      let patch_specifier_loc start_string (loc: Loc.t) =
        let s =
          Util.find_string_start
            start_string
            sub
            (loc.start.offset - (String.length start_string))
        in
        match s with
        | None -> failwith "type or typeof not found"
        | Some s ->
          let e = maybe_comma_after loc in
          remove s (e - s);
      in

      match specifier with
      | S.ImportDeclaration.ImportNamedSpecifier spec ->
        begin
          match spec with
          | {kind=Some S.ImportDeclaration.ImportType; remote=(loc, _); _} ->
            patch_specifier_loc "type" loc;
            true;
          | {kind=Some S.ImportDeclaration.ImportTypeof; remote=(loc, _); _} ->
            patch_specifier_loc "typeof" loc;
            true;
          | _ -> false
        end;
      | _ -> false;
    in

    match importKind with
    | S.ImportDeclaration.ImportType
    | S.ImportDeclaration.ImportTypeof ->
      remove_loc loc;
    | S.ImportDeclaration.ImportValue ->
      if List.for_all
          (patch_specifier @@ List.length specifiers)
          (List.mapi (fun i s -> (i, s)) specifiers)
      then remove_loc loc;
  in

  let visit_expression (_, expr) =
    begin
      match expr with
      | E.Class cls -> patch_class cls;
      | E.TypeCast {expression; typeAnnotation=(loc, _)} ->
        Visit.visit_expression handler expression;
        remove_loc loc;
      | _ -> ();
    end;
    Visit.Continue;
  in


  let visit_function (_, {F. params; returnType; typeParameters; _}) =
    let (params, rest) = params in
    Visit.visit_list handler (fun _ p -> patch_pattern p) params;
    begin
      match rest with
      | Some (_, {argument}) -> patch_pattern argument;
      | None -> ();
    end;
    remove_if_some returnType;
    remove_if_some typeParameters;
    Visit.Continue;
  in

  let visit_statement (loc, stmt) =
    match stmt with
    | S.ImportDeclaration ({S.ImportDeclaration. specifiers=_::_; _} as decl) ->
      patch_import_declaration (loc, decl);
      Visit.Continue;
    | S.VariableDeclaration { declarations; _ } ->
      List.iter
        (fun declarator ->
           let (_, { S.VariableDeclaration.Declarator. id; _ }) = declarator in
           patch_pattern id
        )
        declarations;
      Visit.Continue;

    | S.ClassDeclaration cls ->
      patch_class cls;
      Visit.Continue;

    | S.DeclareModule _
    | S.DeclareExportDeclaration _
    | S.DeclareVariable _
    | S.DeclareFunction _
    | S.DeclareClass _
    | S.InterfaceDeclaration _
    | S.DeclareModuleExports _
    | S.ExportNamedDeclaration _
    | S.ExportDefaultDeclaration _
    | S.TypeAlias _ ->
      remove_loc loc;
      Visit.Continue;

    | _ -> Visit.Continue;
  in
  {
    Visit.default_visit_handler with
    visit_statement;
    visit_expression;
    visit_function;
    visit_pattern=Visit.do_nothing;
  }
