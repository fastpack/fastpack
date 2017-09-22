(*
 * This is transform for spread in object literals and rest spread in object
 * patterns
 **)

module E = Ast.Expression
module S = Ast.Statement
module P = Ast.Pattern
module L = Ast.Literal

module Helper = struct

  let empty_object_literal =
    Loc.none, E.Object { properties = [] }

  let object_assign arguments =
    Loc.none, E.Call {
      callee = Loc.none, E.Member {
          computed = false;
          _object = Loc.none, E.Identifier (Loc.none, "Object");
          property = E.Member.PropertyIdentifier (Loc.none, "assign");
        };
      arguments = (E.Expression empty_object_literal)::(List.rev arguments)
    }

  let object_omit expr keys =
    let keys = List.map (fun key -> Some (E.Expression key)) keys in
    let keys = Loc.none, E.Array { elements = keys } in
    Loc.none, E.Call {
      callee = Loc.none, E.Member {
          computed = false;
          _object = Loc.none, E.Identifier (Loc.none, "$fpack");
          property = E.Member.PropertyIdentifier (Loc.none, "objectOmit");
        };
      arguments = [E.Expression expr; E.Expression keys];
    }

  let object_pattern_key_to_expr = function
    | P.Object.Property.Literal (loc, lit) ->
      loc, E.Literal lit
    | P.Object.Property.Identifier (loc, id) ->
      loc, E.Literal ({
          value = L.String id;
          (** TODO: properly escape quotes from the id *)
          raw = "\"" ^ id ^ "\""
        })
    | P.Object.Property.Computed expr ->
      expr
end

module TranspileObjectSpread = struct

  let test (obj : E.Object.t) =
    List.exists
      (function
        | E.Object.SpreadProperty _ -> true
        | _ -> false)
      obj.properties

  let transpile (obj : E.Object.t) =
    let add_argument bucket arguments =
      match bucket with
      | [] ->
        arguments
      | properties ->
        let arg = E.Expression (Loc.none, E.Object { properties = List.rev properties }) in
        arg::arguments
    in
    let aux (bucket, arguments) prop =
      match prop with
      | E.Object.Property _ ->
        prop::bucket, arguments
      | E.Object.SpreadProperty (_, { argument }) ->
        let arguments = add_argument bucket arguments in
        [], (E.Expression argument)::arguments
    in
    let bucket, arguments = List.fold_left aux ([], []) obj.properties in
    let arguments = add_argument bucket arguments in
    Helper.object_assign arguments

end

(**
 * Folds over Ast.
 *
 * TODO: Decide if we need to move this to a top level module.
 **)
module AstFolder = struct

  let rec fold_pattern f v ((_loc, node) : P.t) =
    let v = match node with

      | P.Object { properties; _ } ->
        let aux v = function
          | P.Object.Property (_, p) ->
            fold_pattern f v p.pattern
          | P.Object.RestProperty (_, p) ->
            fold_pattern f v p.argument
        in
        List.fold_left aux v properties

      | P.Array { elements; _ } ->
        let aux v = function
          | Some (P.Array.Element p) ->
            fold_pattern f v p
          | Some (P.Array.RestElement (_, p)) ->
            fold_pattern f v p.argument
          | None ->
            v
        in
        List.fold_left aux v elements

      | P.Assignment _ -> v
      | P.Identifier _ -> v
      | P.Expression _ -> v
    in
    f v node
end

module TranspileObjectSpreadRest = struct

  module VariableDeclaration = struct

    let gen_omit_declarator omit_keys init decls (loc, id) =
      let omit_keys =
        List.map
          (fun key -> Helper.object_pattern_key_to_expr key.P.Object.Property.key)
          omit_keys
      in
      let init = Helper.object_omit init omit_keys in
      let decl = {
        S.VariableDeclaration.Declarator.
        init = Some init;
        id
      } in
      (loc, decl)::decls

    let gen_declarator keys init decls =
      match keys with
      | [] -> decls
      | keys ->
        let decl = {
          S.VariableDeclaration.Declarator.
          init = Some init;
          id = Loc.none, P.Object {
              properties =
                List.map
                  (fun key -> P.Object.Property (Loc.none, key))
                  keys;
              typeAnnotation = None;
            }
        } in
        (Loc.none, decl)::decls

    let explode_declarator (context : Context.t) ((_loc, {S.VariableDeclaration.Declarator. id; init}) as decl) =

      let gen_init init decls =
        let name = context.gen_id "decl" () in
        let decl =
          Loc.none,
          {
            S.VariableDeclaration.Declarator.
            id =
              Loc.none,
              P.Identifier {
                name = Loc.none, name;
                typeAnnotation = None;
                optional = false
              };
            init = Some init;
          } in
        let init = Loc.none, E.Identifier (Loc.none, name) in
        init, decl::decls
      in

      match init with
      | None -> [decl]
      | Some init ->
        let fold_pattern decls (p : P.t') =
          match p with
          | P.Object { properties; _ } ->
            let fold_property (keys_before, decls, init) = function
              | P.Object.RestProperty (loc, prop) ->
                let init, decls = gen_init init decls in
                let decls = gen_omit_declarator keys_before init decls (loc, prop.argument) in
                [], decls, init
              | P.Object.Property (_, prop) ->
                prop::keys_before, decls, init
            in 
            let remaining_keys, decls, _init = List.fold_left fold_property ([], decls, init) properties in 
            let decls = gen_declarator remaining_keys init decls in
            decls
          | _ ->
            decls
        in
        AstFolder.fold_pattern fold_pattern [] id

    let transpile context (node : S.VariableDeclaration.t) =
      let declarations =
        node.declarations
        |> List.map (explode_declarator context)
        |> List.flatten
      in
      S.VariableDeclaration { node with declarations }
  end

end

let transpile context program =

  let map_statement _scope ((loc, node) : S.t) =
    let module T = TranspileObjectSpreadRest in
    let node = match node with
      | S.VariableDeclaration d ->
        T.VariableDeclaration.transpile context d
      | S.ForIn _ -> node
      | S.ForOf _ -> node
      | S.FunctionDeclaration _ -> node
      | _ -> node
    in
    loc, node
  in

  let map_expression _scope ((loc, node) : E.t) =
    let node = match node with
      | E.Object obj when TranspileObjectSpread.test obj ->
        let _, node = TranspileObjectSpread.transpile obj in node
      | node -> node
    in
    loc, node
  in

  let mapper = {
    AstMapper.default_mapper with
    map_expression;
    map_statement;
  } in

  AstMapper.map mapper program

