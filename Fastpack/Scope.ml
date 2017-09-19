module S = Ast.Statement
module P = Ast.Pattern

type name = Imported
          | Function
          | Class
          | Variable

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

let update_scope _type _name =
  failwith "not implemented"

let func_scope stmts =
  let visit_statement ((_, stmt) : S.t) =
    match stmt with
    | S.ClassDeclaration { id; _} ->
      let () =
        match id with
        | Some (_, name) -> update_scope Class name
        | None -> ()
      in Visit.Break
    | S.FunctionDeclaration { id; _ } ->
      let () =
        match id with
        | Some (_, name) -> update_scope Function name
        | None -> ()
      in Visit.Break
    | S.VariableDeclaration { kind = S.VariableDeclaration.Var; declarations } ->
      let () =
        List.iter
          (fun (_, {S.VariableDeclaration.Declarator. id; _ }) ->
             List.iter (update_scope Variable) @@ names_of_pattern id
          )
          declarations
      in Visit.Break
    | _ -> Visit.Continue
  in
  let handler = {
    Visit.default_visit_handler with
    visit_statement = visit_statement
  } in
  Visit.visit_list handler Visit.visit_statement stmts
