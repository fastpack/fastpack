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
  bindings : binding M.t;
}
and binding = {
  typ : typ;
  loc : Loc.t;
  exported : string option;
  shorthand : bool;
}
and typ = Import of import
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

let string_of_binding { typ; loc; exported; _ } =
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
  ^ Loc.(Printf.sprintf
           " [%d:%d - %d:%d]"
           loc.start.line
           loc.start.column
           loc._end.line
           loc._end.column)


let scope_to_str ?(sep="\n") scope =
  scope.bindings
  |> M.bindings
  |> List.map
    (fun (name, binding) ->
       name ^ " -> " ^ string_of_binding binding
    )
  |> String.concat sep

let name_of_identifier (_, name) =
  name

let names_of_pattern node =
  let rec names_of_pattern' ?(shorthand=false) names (_, node) =
    match node with
    | P.Object { properties; _ } ->
      let on_property names = function
        | P.Object.Property (_,{ pattern; shorthand; _ }) ->
          names_of_pattern' ~shorthand names pattern
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
    | P.Identifier { name; _ } ->
      (name, shorthand) :: names
    | P.Expression _ ->
      names
  in names_of_pattern' [] node

let export_binding name remote bindings =
  match M.get name bindings with
  | Some { typ = Argument; _ } ->
    failwith ("Cannot export Argument: " ^ name)
  | Some ({ exported = None; _ } as binding) ->
    M.add name { binding with exported = Some remote } bindings
  | Some { exported = Some _; _ } ->
    failwith ("Cannot export twice: " ^ name)
  | None ->
    failwith ("Cannot export previously undefined name: " ^ name)

let update_bindings loc name typ shorthand (bindings : binding M.t)=
  match M.get name bindings, typ with
  | None, _
  | Some { typ = Argument; _ }, _
  | Some { typ = Function; _ }, Var
  | Some { typ = Function; _ }, Function
  | Some { typ = Var; _}, Var ->
    M.add name { exported = None; loc; typ; shorthand } bindings
  | Some { typ = Var; _}, Function ->
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
         List.map
           (fun (name, shorthand) -> (name, typ, shorthand))
           (names_of_pattern id)
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
      | Some (S.ImportDeclaration.ImportNamespaceSpecifier (_, name)) ->
        [name, Import { remote = None; source }, false]
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
                 local,
                 Import {remote = Some (name_of_identifier remote); source},
                 false
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
      | Some name ->
        (name, Import { remote = Some "default"; source}, false) :: names
    end
  | S.ClassDeclaration { id = Some name; _} ->
    [(name, Class, false)]
  | S.FunctionDeclaration { id = Some name; _ } ->
    [(name, Function, false)]
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


let gather_bindings ?(init=None) =
  let init =
    match init with
    | Some init -> init
    | None -> M.empty
  in
  List.fold_left
    (fun bindings ((loc, name), typ, shorthand) ->
      update_bindings loc name typ shorthand bindings
    )
    init


let of_statement _ ((_, stmt) as node) scope =
  let bindings =
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
      names_of_node node |> gather_bindings

    | _ ->
      M.empty
  in
  if bindings != M.empty
  then { bindings; parent = Some scope; }
  else scope



let bindings_of_function_block stmts =
  let bindings = ref (M.empty) in

  let add_bindings node =
    List.iter
      (fun ((loc, name), typ, shorthand) ->
        bindings := update_bindings loc name typ shorthand !bindings
      )
      @@ names_of_node node
  in

  let export_bindings =
    List.iter
      (fun (name, remote) -> bindings := export_binding name remote !bindings)
  in

  let level = ref 0 in

  let enter_statement _ctx _ =
    level := !level + 1
  in

  let leave_statement _ctx _ =
    level := !level - 1
  in

  let visit_statement _ctx ((_, stmt) as node) =
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
      } ->
      let names =
        List.map
          (fun ((_, name), _, _) -> (name, "default"))
          @@ names_of_node declaration
      in
      begin
        add_bindings declaration;
        export_bindings names;
        Visit.Break
      end

    | S.ExportNamedDeclaration {
        exportKind = S.ExportValue;
        declaration = Some declaration;
        source = None; _
      } ->
      let names =
        List.map
          (fun ((_, name), _, _) -> (name, name))
          @@ names_of_node declaration
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
    enter_statement;
    leave_statement;
  } in
  let () =
    Visit.visit handler ([], stmts, [])
  in
  !bindings


let of_block parents (((_ : Loc.t), { S.Block. body }) as block) scope =
  let bindings =
    match parents with
    | [] | (AstParentStack.Function _) :: _ ->
      bindings_of_function_block body
    | _ ->
      (* TODO: account for names in try/catch *)
      let init =
        match parents with
        | (AstParentStack.Statement (_, S.Try { handler = Some (
            _, {S.Try.CatchClause. body; param }
          ); _})) :: _
          when body = block ->
          names_of_pattern param
          |> List.map (fun (id, shorthand) -> (id, Let, shorthand))
          |> gather_bindings
        | _ ->
          M.empty
      in
      body
      |> List.map
        (fun ((_, stmt) as node) ->
           match stmt with
           | S.ClassDeclaration _
           | S.VariableDeclaration { kind = S.VariableDeclaration.Let; _ }
           | S.VariableDeclaration { kind = S.VariableDeclaration.Const; _ } ->
             names_of_node node
           | _ -> []
        )
      |> List.concat
      |> gather_bindings ~init:(Some init)
  in
  { bindings; parent = Some scope; }

let of_function _ (_, {F. params = (_, { params; rest }); _}) scope =
  let bindings =
    gather_bindings
    @@ List.map (fun (id, shorthand) -> (id, Argument, shorthand))
    @@ List.flatten
    @@ List.append
      (List.map names_of_pattern params)
      (match rest with
       | Some (_, { F.RestElement.  argument }) ->
         [names_of_pattern argument]
       | None -> []
      )
  in
  { bindings; parent = Some scope; }

let of_program stmts =
  of_block [] (Loc.none, { S.Block. body = stmts; })


let rec get_binding name { bindings; parent } =
  let binding = M.get name bindings in
  match binding, parent with
  | None, Some parent -> get_binding name parent
  | _ -> binding

let has_binding name scope =
  (get_binding name scope) != None

let bindings scope =
  scope.bindings |> M.bindings

let get_exports scope =
  scope.bindings
  |> M.bindings
  |> List.filter_map (fun (_, { exported; _ }) -> exported)

let iter f scope =
  scope.bindings
  |> M.bindings
  |> List.iter f

let fold_left f acc scope =
  scope.bindings
  |> M.bindings
  |> List.fold_left f acc
