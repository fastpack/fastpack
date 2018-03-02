module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module C = Ast.Class
module F = Ast.Function
module L = Ast.Literal

module AstMapper = FastpackUtil.AstMapper
module AstHelper = FastpackUtil.AstHelper
module APS = FastpackUtil.AstParentStack
open FastpackUtil.AstHelper

module Helper = struct

  let op_key_to_literal key =
    match key with
    | E.Object.Property.Identifier (_, name) ->
      literal_str name
    | E.Object.Property.Literal (_, lit) ->
      lit
    | E.Object.Property.PrivateName (loc, _) ->
      raise (Error.TranspilerError (
        loc,
        "PrivateName is not implemented yet"
      ))
    | E.Object.Property.Computed (loc, _) ->
      raise (Error.TranspilerError (
        loc,
        "Computed properties are not supported here"
      ))

  let op_value_to_expr value =
    match value with
    | Some (_, value) -> Loc.none, value
    | None -> void_0

end

module Transform = struct

  let undecorate_methods ({C. body = (body_loc, { body }); _ } as cls) =
    let methods =
      body
      |> List.filter_map
        (fun m ->
           match m with
           | C.Body.Method (loc, m) ->
             Some (C.Body.Method (loc, { m with decorators = []}))
           | _ -> None
        )
    in
    { cls with
      body = (body_loc, { body = methods })
    }

  let transform_class cls =
    let {C. id; classDecorators; body = (_, { body }); _ } = cls in

    let props, methods =
      List.partition
        (fun element ->
           match element with
           | C.Body.Property _ -> true
           | _ -> false
        )
        body
    in

    let props, statics =
      List.partition_map
        (fun element ->
           match element with
           | C.Body.Property (_, { static; key; value; _ }) ->
             if static
             then `Right (key, value)
             else `Left (key, value)
           | _ ->
             `Drop
        )
        props
    in

    let decorators =
      List.filter_map
        (fun m ->
           match m with
           | C.Body.Method (_, {
               C.Method. key; decorators = _::_ as decorators; _}) ->
             Some (key, decorators)
           | _ -> None
        )
        methods
    in

    let move_props_to_constructor (cls : Loc.t C.t) =
      match props with
      | [] -> cls
      | props ->
        let prop_stmts =
          props
          |> List.map
            (fun (key, value) ->
              (Loc.none, S.Expression {
                 expression = object_define_property
                     (Helper.op_key_to_literal key)
                     (Helper.op_value_to_expr value);
               directive = None;
              })
            )
        in
        let insert_after_super stmts =
          let take, drop =
            stmts
            |> List.take_drop_while
              (fun stmt ->
                 match stmt with
                 | (_, S.Expression {
                     expression=(_, E.Call { callee = (_, E.Super); _ }); _
                   }) ->
                   false
                 | _ -> true
              )
          in
          match drop with
          | [] -> prop_stmts @ take
          | super :: rest -> take @ (super :: prop_stmts) @ rest
        in
        let constructor =
          List.head_opt
          @@ List.filter
            (fun (_, el) ->
               match el with
               | C.Body.Method (_, { kind = C.Method.Constructor; _}) -> true
               | _ -> false
            )
          @@ List.mapi (fun index el -> (index, el)) methods
        in
        let (take, drop, constructor) =
          match constructor with
          | Some (i, C.Body.Method (c_loc, ({
              value = (value_loc, value); _
            } as constructor))) ->
            let body_loc, body =
              match value.body with
              | F.BodyBlock (body_loc, { body }) -> body_loc, body
              | F.BodyExpression expr -> Loc.none, [return expr]
            in
            (i, i + 1, C.Body.Method (
                c_loc,
                { constructor with
                  value = (value_loc, {
                      value with
                      body = F.BodyBlock (body_loc, {
                          body = insert_after_super body
                      })
                    })
                }
            ))
          | None ->
            (0, 0, C.Body.Method (
                Loc.none, {
                  kind = C.Method.Constructor;
                  static = false;
                  decorators = [];
                  key = E.Object.Property.Identifier (Loc.none,
                                                      "constructor");
                  value = (Loc.none, {
                      id = None;
                      params = (Loc.none, { params = []; rest = None });
                      body = F.BodyBlock (Loc.none, { body = prop_stmts });
                      async = false;
                      generator = false;
                      predicate = None;
                      expression = false;
                      returnType = None;
                      typeParameters = None;
                  })
                }))
          | _ -> Error.ie "Only constructor is expected here"
        in
        let (body_loc, _) = cls.body in
        let body =
          List.take take methods @ [constructor] @ List.drop drop methods
        in
        { cls with
          body = (body_loc, { body })
        }
    in


    let cls = {
      (cls |> move_props_to_constructor |> undecorate_methods)
      with classDecorators = []
    }
    in

    (cls, id, statics, classDecorators, decorators)

  let wrap_class cls statics classDecorators decorators =
    let to_expr_array = to_array (fun el -> el) in

    let statics =
      statics
      |> to_array
        (fun (key, value) ->
           object_ [
             object_property "name"
               (Loc.none, E.Literal (Helper.op_key_to_literal key));
             object_property "value" (Helper.op_value_to_expr value)
           ]
        )
    in

    let decorators =
      decorators
      |> to_array
        (fun (key, decorators) ->
          object_ [
            object_property "method"
              (Loc.none, E.Literal (Helper.op_key_to_literal key));
            object_property "decorators" (to_expr_array decorators)
          ]
        )
    in
    fpack_define_class
      cls
      statics
      (to_expr_array classDecorators)
      decorators
end


let transpile {Context. require_runtime; _ } program =
  let map_expression _ ((loc, node) : Loc.t E.t) =
    match node with
    | E.Class cls ->
      begin
        match Transform.transform_class cls with
        | cls, _, [], [], [] ->
          (loc, E.Class cls)
        | cls, _, statics, classDecorators, decorators ->
          require_runtime ();
          Transform.wrap_class cls statics classDecorators decorators
      end
    | _ -> (loc, node)
  in

  let map_statement {AstMapper. parents; _ } ((loc, stmt) : Loc.t S.t) =
    match stmt with
    | S.ExportDefaultDeclaration ({
        declaration = S.ExportDefaultDeclaration.Declaration (
            _,
            S.ClassDeclaration ({ id = Some (_, name); _ } as cls)
          );
        _
      } as export) ->
      begin
        match Transform.transform_class cls with
        | cls, _, [], [], [] ->
          [
            loc,
            S.ExportDefaultDeclaration {
              export with
              declaration = S.ExportDefaultDeclaration.Declaration (
                  Loc.none,
                  S.ClassDeclaration cls
                )
            }
          ]
        | cls, _, statics, classDecorators, decorators ->
          require_runtime ();
          [
            (Transform.wrap_class cls statics classDecorators decorators
                       |> let_stmt ~loc:Loc.none name);
            (loc,
             S.ExportDefaultDeclaration {
               export with
               declaration = S.ExportDefaultDeclaration.Expression (
                   AstHelper.e_identifier name
                 )
             }
            )
          ]
      end

    | S.ClassDeclaration cls ->
      begin
        match APS.top_statement parents with
        | Some (_, S.ExportDefaultDeclaration {
            declaration = S.ExportDefaultDeclaration.Declaration (
                _,
                S.ClassDeclaration { id = Some _; _ }
              );
            _
          }) ->
          [loc, stmt]
        | _ ->
          begin
            match Transform.transform_class cls with
            | cls, _, [], [], [] ->
              [(loc, S.ClassDeclaration cls)]
            | cls, name, statics, classDecorators, decorators ->
              require_runtime ();
              let transformed =
                Transform.wrap_class cls statics classDecorators decorators
              in
              match name with
              | None ->
                [loc, S.Expression {expression = transformed; directive = None} ]
              | Some (_, name) ->
                [
                  let_stmt ~loc name transformed
                ]
          end
      end
    | _ -> [(loc, stmt)]
  in

  let mapper = {
    AstMapper.default_mapper with
    map_statement;
    map_expression;
  } in

  AstMapper.map mapper program

