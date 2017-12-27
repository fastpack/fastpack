module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module F = Ast.Function
module P = Ast.Pattern
module L = Ast.Literal
module SL = Ast.StringLiteral
module M = Map.Make(String)

type t = {
  parent : t option;
  bindings : (exported * binding) M.t;
}
and exported = string option
and binding = Import of import
            | Function
            | Argument
            | Class
            | Var
            | Let
            | Const
and import = {
  source : string;
  remote: string option;
}

let empty = { bindings = M.empty; parent = None; }

let scope_to_str ?(sep="\n") scope =
  scope.bindings
  |> M.bindings
  |> List.map
    (fun (name, (exported, typ)) ->
       name ^ " -> " ^
       (match typ with
        | Import { source; remote } ->
          let remote = (match remote with | None -> "*" | Some n -> n) in
          Printf.sprintf "Import %s from '%s'" remote source
        | Function -> "Function"
        | Class -> "Class"
        | Argument -> "Argument"
        | Var -> "Var"
        | Let -> "Let"
        | Const -> "Const"
       )
       ^ (match exported with
          | None -> ""
          | Some name -> Printf.sprintf " [exported as %s]" name)
    )
  |> String.concat sep

let name_of_identifier (_, name) =
  name

let names_of_pattern node =
  let rec names_of_pattern' names (_, node) =
    match node with
    | P.Object { properties; _ } ->
      let on_property names = function
        | P.Object.Property (_,{ key; pattern; shorthand }) ->
          if shorthand then
            match key with
            | P.Object.Property.Identifier id -> (name_of_identifier id)::names
            | _ -> names
          else
            names_of_pattern' names pattern
        | P.Object.RestProperty (_,{ argument }) ->
          names_of_pattern' names argument
      in
      List.fold_left on_property names properties
    | P.Array { elements; _ } ->
      let on_element names = function
        | None ->
          names
        | Some (P.Array.Element node) ->
          names_of_pattern' names node
        | Some (P.Array.RestElement (_, { argument })) ->
          names_of_pattern' names argument
      in
      List.fold_left on_element names elements
    | P.Assignment { left; _ } ->
      names_of_pattern' names left
    | P.Identifier { name = id; _ } ->
      (name_of_identifier id)::names
    | P.Expression _ ->
      names
  in names_of_pattern' [] node

let export_binding name remote bindings =
  match M.get name bindings with
  | Some (None, Argument) -> failwith ("Cannot export Argument: " ^ name)
  | Some (None, typ) -> M.add name (Some remote, typ) bindings
  | Some (Some _, _) -> failwith ("Cannot export twice: " ^ name)
  | None -> failwith ("Cannot export previously undefined name: " ^ name)

let update_bindings name typ bindings =
  match M.get name bindings, typ with
  | None, _
  | Some (_, Argument), _
  | Some (_, Function), Var
  | Some (_, Function), Function
  | Some (_, Var), Var ->
    M.add name (None, typ) bindings
  | Some (_, Var), Function ->
    bindings
  | _ ->
    (* TODO: track the Loc.t of bindings and raise the nice error *)
    failwith ("Naming collision: " ^ name)

let names_of_node ((_, node) : Loc.t S.t) =
  let type_of_kind kind =
    match kind with
    | S.VariableDeclaration.Let -> Let
    | S.VariableDeclaration.Const -> Const
    | S.VariableDeclaration.Var -> Var
  in
  let names_of_declarations kind declarations =
    let typ = type_of_kind kind in
    List.flatten
    @@ List.map
      (fun (_, {S.VariableDeclaration.Declarator. id; _ }) ->
         List.map (fun name -> (name, typ)) (names_of_pattern id)
      )
      declarations
  in
  match node with
  | S.ImportDeclaration {
      importKind = S.ImportDeclaration.ImportValue;
      source = (_, { value = source; _ });
      specifiers;
      default
    } ->
    let names =
      match specifiers with
      | None ->
        []
      | Some (S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, name))) ->
        [name, Import { remote = None; source }]
      | Some (S.ImportDeclaration.ImportNamedSpecifiers specifiers) ->
        List.filter_map
          (fun {S.ImportDeclaration. kind; local; remote } ->
             match kind with
             | Some S.ImportDeclaration.ImportValue | None ->
               let local =
                 match local with
                 | Some name -> name
                 | None -> remote
               in
               Some (
                 name_of_identifier local,
                 Import {remote = Some (name_of_identifier remote); source}
               )
             | _ ->
               None
          )
          specifiers
    in
    begin
      match default with
      | None ->
        names
      | Some (_, name) ->
        (name, Import { remote = Some "default"; source}) :: names
    end
  | S.ClassDeclaration { id = Some name; _} ->
    [(name_of_identifier name, Class)]
  | S.FunctionDeclaration { id = Some name; _ } ->
    [(name_of_identifier name, Function)]
  | S.VariableDeclaration { kind; declarations } ->
    names_of_declarations kind declarations
  | S.For {
      init = Some (S.For.InitDeclaration (_, { declarations; kind })); _
    } ->
    names_of_declarations kind declarations
  | S.ForIn {
      left = S.ForIn.LeftDeclaration (_, { declarations; kind }); _
    } ->
    names_of_declarations kind declarations
  | S.ForOf {
      left = S.ForOf.LeftDeclaration (_, { declarations; kind }); _
    } ->
    names_of_declarations kind declarations
  | _ -> []


let of_statement ((_, stmt) as node) scope =
  let bindings = ref (M.empty) in
  let add_bindings node =
    List.iter
      (fun (name, typ) ->
        bindings := update_bindings name typ !bindings
      )
      @@ names_of_node node
  in

  let () =
    match stmt with
    | S.For { init = Some (S.For.InitDeclaration (_, {
        kind = S.VariableDeclaration.Let; _
      })); _ }
    | S.For { init = Some (S.For.InitDeclaration (_, {
        kind = S.VariableDeclaration.Const; _
      })); _ }
    | S.ForIn { left = S.ForIn.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Let; _
      }); _ }
    | S.ForIn { left = S.ForIn.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Const; _
      }); _ }
    | S.ForOf { left = S.ForOf.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Let; _
      }); _ }
    | S.ForOf { left = S.ForOf.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Const; _
      }); _ } ->
      add_bindings node
    | S.Block { body } ->
      List.iter
        (fun ((_, stmt) as node) ->
           match stmt with
           | S.ClassDeclaration _
           | S.VariableDeclaration { kind = S.VariableDeclaration.Let; _ }
           | S.VariableDeclaration { kind = S.VariableDeclaration.Const; _ } ->
             add_bindings node
           | _ -> ()
        )
        body
    | _ -> ()
  in
  if !bindings != M.empty
  then { bindings = !bindings; parent = Some scope; }
  else scope


let of_function_body args stmts scope =
  let bindings =
    ref @@ List.fold_left (fun m key -> M.add key (None, Argument) m) M.empty args
  in

  let add_bindings node =
    List.iter
      (fun (name, typ) ->
        bindings := update_bindings name typ !bindings
      )
      @@ names_of_node node
  in

  let export_bindings =
    List.iter (fun (name, remote) -> bindings := export_binding name remote !bindings)
  in

  let level = ref 0 in

  let enter_statement _ =
    level := !level + 1
  in

  let leave_statement _ =
    level := !level - 1
  in

  let visit_statement ((_, stmt) as node) =
    match stmt with
    | S.ImportDeclaration { importKind = S.ImportDeclaration.ImportValue; _} ->
      add_bindings node;
      Visit.Break

    | S.ClassDeclaration _ ->
      if !level = 1 then add_bindings node;
      Visit.Break;

    | S.FunctionDeclaration _ ->
      add_bindings node;
      Visit.Break

    | S.VariableDeclaration { kind; _ } ->
      let () =
        match kind, !level with
        | S.VariableDeclaration.Let, 1
        | S.VariableDeclaration.Const, 1
        | S.VariableDeclaration.Var, _ ->
          add_bindings node
        | _ ->
          ()
      in Visit.Break

    | S.For { init = Some (S.For.InitDeclaration (_, {
        kind = S.VariableDeclaration.Var; _
      })); _ }
    | S.ForIn { left = S.ForIn.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Var; _
      }); _ }
    | S.ForOf { left = S.ForOf.LeftDeclaration (_, {
        kind = S.VariableDeclaration.Var; _
      }); _ } ->
      add_bindings node;
      Visit.Continue

    | S.ExportDefaultDeclaration {
        declaration = S.ExportDefaultDeclaration.Declaration declaration;
        _
      }
    | S.ExportNamedDeclaration {
        exportKind = S.ExportValue;
        declaration = Some declaration;
        source = None; _
      } ->
      let names =
        List.map (fun (name, _) -> (name, name)) @@ names_of_node declaration
      in
      begin
        add_bindings declaration;
        export_bindings names;
        Visit.Break
      end

    | S.ExportNamedDeclaration {
        exportKind = S.ExportValue;
        specifiers = Some S.ExportNamedDeclaration.ExportSpecifiers specifiers;
        source = None;
        _
      } ->
      let names =
        List.map
          (fun (_, {
               S.ExportNamedDeclaration.ExportSpecifier.
               local = (_, local);
               exported
             }) ->
             local,
             match exported with
             | Some (_, name) -> name
             | _ -> local
          )
          specifiers
      in
      begin
        export_bindings names;
        Visit.Break
      end

    | _ -> Visit.Continue
  in

  let handler = {
    Visit.default_visit_handler with
    visit_statement;
    visit_expression = (fun _ -> Visit.Break);
    visit_pattern = (fun _ -> Visit.Break);
    visit_function = (fun _ -> Visit.Break);
    enter_statement;
    leave_statement;
  } in
  let () =
    Visit.visit_list handler Visit.visit_statement stmts
  in {
    bindings = !bindings;
    parent = Some scope;
  }

let of_function (_, {F. params = (_, { params; rest }); body; _}) =
  let arguments =
    List.flatten
    @@ List.append
      (List.map names_of_pattern params)
      (match rest with
       | Some (_, { F.RestElement.  argument }) ->
         [names_of_pattern argument]
       | None -> []
      )
  in
  match body with
  | F.BodyBlock (_, { body; }) -> of_function_body arguments body
  | F.BodyExpression _ -> of_function_body arguments []

let of_program = of_function_body []

let rec get_binding name { bindings; parent } =
  let binding = M.get name bindings in
  match binding, parent with
  | None, Some parent -> get_binding name parent
  | _ -> binding

let has_binding name scope =
  (get_binding name scope) != None

let get_exports scope =
  scope.bindings
  |> M.bindings
  |> List.filter_map (fun (_, value) -> fst value)
