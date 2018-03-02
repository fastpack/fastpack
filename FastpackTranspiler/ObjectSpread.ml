(*
 * This is transform for spread in object literals and rest spread in object
 * patterns
 **)
module AstMapper = FastpackUtil.AstMapper
module AstHelper = FastpackUtil.AstHelper
module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module E = Ast.Expression
module F = Ast.Function
module S = Ast.Statement
module P = Ast.Pattern
module L = Ast.Literal

(**
 * Folds over Ast.
 *
 * TODO: Decide if we need to move this to a top level module.
 **)
module AstFolder = struct

  let rec fold_pattern f v ((_loc, node) : Loc.t P.t) =
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

  let test (obj : Loc.t E.Object.t) =
    List.exists
      (function
        | E.Object.SpreadProperty _ -> true
        | _ -> false)
      obj.properties

  let transpile (obj : Loc.t E.Object.t) =
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


module TranspileObjectSpreadRest = struct

  module Pattern = struct

    type item = Assign of Loc.t P.t' * Loc.t E.t
              | Omit of (Loc.t P.t' * Loc.t E.t * (Loc.t E.t list))

    type t = {
      before : item list;
      self : item option;
      after : item list;
      result : Loc.t E.t;
    }

    let test =
      let check_pattern result node =
        match result, node with
        | true, _ -> true
        | _, P.Object {P.Object. properties; _} ->
          begin
            match List.rev properties with
            | (P.Object.RestProperty _) :: _ -> true
            | _ -> false
          end
        | _ -> false
      in
      AstFolder.fold_pattern check_pattern false

    let transpile {Context. gen_binding; _} scope left right =
      let before = ref [] in
      let after = ref [] in
      let compute_before expr =
        match (snd expr) with
        | E.Identifier (_, name) ->
          name
        | _ ->
          let name = gen_binding scope in
          begin
            before := (Assign (AstHelper.p_identifier name, expr)) :: !before;
            name
          end
      in
      let compute_key key =
        match key with
        | P.Object.Property.Computed expr ->
          let name = compute_before expr in
          P.Object.Property.Computed (AstHelper.e_identifier name)
        | _ -> key
      in
      let get_object_property obj key =
        match key with
        | P.Object.Property.Literal (_, lit) ->
          AstHelper.member_expr obj (AstHelper.e_literal lit)
        | P.Object.Property.Identifier (_, name) ->
          AstHelper.member obj name
        | P.Object.Property.Computed expr ->
          AstHelper.member_expr obj expr
      in
      let rec strip_rest pattern obj =
          match pattern with
          | P.Object ({properties; _} as pattern) ->
            let properties, spread = strip_properties properties obj in
            let () =
              match spread with
              | Some (spread, omit) ->
                after := (Omit (AstHelper.p_identifier spread, obj, omit)) :: !after
              | _ -> ()
            in
            begin
              match properties with
              | [] -> None
              | _ -> Some (P.Object { pattern with properties })
            end
          | P.Array ({elements; _} as pattern) ->
            let elements =
              elements
              |> List.mapi
                (fun i el ->
                   let index =
                     P.Object.Property.Computed (
                       AstHelper.e_literal (AstHelper.literal_num i)
                     )
                   in
                   let obj = get_object_property obj index in
                   match el with
                   | Some (P.Array.Element (_, pattern)) ->
                     begin
                       match strip_rest pattern obj with
                       | Some pattern -> Some (P.Array.Element (Loc.none, pattern))
                       | None -> None
                     end
                   | Some(P.Array.RestElement (_, {argument = (_, pattern); _})) ->
                     begin
                       match strip_rest pattern obj with
                       | Some pattern ->
                         Some (P.Array.RestElement (Loc.none, {
                             argument = (Loc.none, pattern)
                         }))
                       | None -> None
                     end
                   | _ ->
                     None
                )
            in
            Some (P.Array ({pattern with elements}))
          | _ -> Some pattern
      and strip_properties properties obj =
        let omit_keys = ref [] in
        let omit key =
          let expr =
            match key with
            | P.Object.Property.Literal (_, lit) ->
              AstHelper.e_literal lit
            | P.Object.Property.Identifier (_, name) ->
              AstHelper.e_literal_str name
            | P.Object.Property.Computed (_, E.Identifier (_, name)) ->
              AstHelper.e_identifier name
            | P.Object.Property.Computed (loc, _) ->
              raise (Error.TranspilerError (
                loc,
                "Unexpected non-identifier Object.Property.Computed"
              ))
          in
          omit_keys := expr :: !omit_keys
        in
        let properties, spread =
          properties
          |> List.partition_map
            (function
             | P.Object.Property (_, ({
                 pattern = (_, pattern);
                 key; _
               } as prop)) ->
               let key = compute_key key in
               let pattern = strip_rest pattern (get_object_property obj key) in
               begin
                 omit key;
                 match pattern with
                 | Some pattern ->
                   `Left (P.Object.Property (Loc.none, {
                       prop with
                       key;
                       pattern = (Loc.none, pattern);
                   }))
                 | None -> `Drop
               end
             | P.Object.RestProperty (_, {
                 argument = (_, P.Identifier { name = (_, name); _ })
               }) ->
               `Right name
             | P.Object.RestProperty (_, { argument = (_, pattern)}) ->
               let obj =
                 AstHelper.fpack_omit_props
                  obj
                  (AstHelper.to_array (fun x -> x) !omit_keys)
               in
               let () =
                 match strip_rest pattern obj with
                 | Some self ->
                   after := !after @ [Assign (self, obj)]
                 | None -> ()

               in
               `Drop
            )
        in
        (
          properties,
          match spread with
          | [spread] -> Some (spread, List.rev !omit_keys)
          | _ -> None
        )
      in
      let right = AstHelper.e_identifier (compute_before right) in
      let self =
        match strip_rest left right with
        | Some self -> Some (Assign (self, right))
        | None -> None
      in
      {
        before = List.rev !before;
        self;
        after = List.rev !after;
        result = right;
      }

    let to_variable_declaration = function
      | Assign (left, right) ->
        Loc.none, { S.VariableDeclaration.Declarator.
          id = Loc.none, left;
          init = Some right;
        }
      | Omit (left, right, omit) ->
        Loc.none, { S.VariableDeclaration.Declarator.
          id = Loc.none, left;
          init = Some (
              AstHelper.fpack_omit_props
                right
                (AstHelper.to_array (fun x -> x) omit)
            );
        }

    let to_assignment = function
      | Assign (left, right) ->
        Loc.none, S.Expression {
          expression = (Loc.none, E.Assignment {
            operator = E.Assignment.Assign;
            left = Loc.none, left;
            right;
          });
          directive = None;
        }
      | Omit (left, right, omit) ->
        Loc.none, S.Expression {
          expression = (Loc.none, E.Assignment {
            operator = E.Assignment.Assign;
            left = Loc.none, left;
            right = (
              AstHelper.fpack_omit_props
                right
                (AstHelper.to_array (fun x -> x) omit)
            );
          });
          directive = None;
        }


  end

  module Assignment = struct

    let test {E.Assignment. left; _} =
      Pattern.test left

    let transpile context scope {E.Assignment. left = (_, left); right; _ } =
      let {Pattern. before; self; after; result } =
        Pattern.transpile context scope left right
      in
      let declarations =
        List.map Pattern.to_variable_declaration before
      in
      let variables =
        if List.length declarations > 0
        then
          [
            Loc.none, S.VariableDeclaration {
              kind = S.VariableDeclaration.Let;
              declarations;
            }
          ]
        else
          []
      in
      let assignments =
        (match self with | Some item -> [item] | None -> []) @ after
        |> List.map Pattern.to_assignment
      in
      let func =
        Loc.none, E.ArrowFunction {
          id = None;
          params = (Loc.none, { params = []; rest = None});
          async = false;
          generator = false;
          predicate = None;
          expression = false;
          typeParameters = None;
          returnType = None;
          body = F.BodyBlock (Loc.none, {
            body = variables @ assignments @ [
                  Loc.none, S.Return {argument = Some result}
            ]
          })
        }
      in
      AstHelper.call func []
  end


  module Function = struct
    let test {F. params = (_, { params; rest }); _} =
      List.exists Pattern.test params
      || (match rest with
          | Some (_, {F.RestElement. argument}) -> Pattern.test argument
          | None -> false)

    let transpile
        context
        scope
        ({F. params = (_, { params; rest }); body; _} as func) =
      let vars = ref [] in
      let gen_binding pattern =
        let binding = context.Context.gen_binding scope in
        let () =
          vars := (snd pattern, AstHelper.e_identifier binding) :: !vars
        in
        Loc.none, AstHelper.p_identifier binding
      in
      let params =
        List.map
          (fun param ->
             if Pattern.test param
             then
               gen_binding param
             else
               param
          )
          params
      in
      let rest =
        match rest with
        | None -> None
        | Some (_, { argument }) as rest ->
          if Pattern.test argument
          then Some (Loc.none, {
              F.RestElement.  argument = gen_binding argument
            })
          else
            rest
      in
      let declarations =
        !vars
        |> List.rev
        |> List.map
          (fun (left, right) ->
             let {Pattern. before; self; after; _ } =
               Pattern.transpile context scope left right
             in
             before
             @ (match self with Some self -> [self] | None -> [])
             @ after
          )
        |> List.flatten
        |> List.map Pattern.to_variable_declaration
      in
      let decl =
        Loc.none,
        S.VariableDeclaration {
          kind = S.VariableDeclaration.Let;
          declarations;
        }
      in
      let body =
        match body with
        | F.BodyBlock (_, { body }) ->
          F.BodyBlock (Loc.none, { body =  decl :: body })
        | F.BodyExpression expr ->
          F.BodyBlock (Loc.none, {
              body = decl :: (Loc.none, S.Return {argument = Some expr}) :: []
            })
      in
      { func with params = (Loc.none, { params; rest }); body }


  end

  module VariableDeclaration = struct

    let test
        ?(with_init=true)
        ({ declarations; _ } : Loc.t S.VariableDeclaration.t) =
      let test_declaration (_, {S.VariableDeclaration.Declarator. id; init }) = 
        match with_init, id, init with
        | false, id, None
        | true, id, Some _ -> Pattern.test id
        | _ -> false
      in
      List.exists test_declaration declarations

    let transpile_declaration context scope
        (loc, ({S.VariableDeclaration.Declarator. id=(_, id); init} as decl))  =
      match init with
      | None -> [(loc, decl)]
      | Some init ->
        let {Pattern. before; self; after; _} =
          Pattern.transpile context scope id init
        in
        List.map
          Pattern.to_variable_declaration
          (before @ (match self with | Some item -> [item] | None -> []) @ after)

    let transpile context scope ({S.VariableDeclaration. declarations; _ } as node) =
      { node with
        declarations =
          List.flatten
          @@ List.map (transpile_declaration context scope) declarations
      }
  end

  module ForIn = struct

    let test {S.ForIn. left; _ } =
      match left with
      | S.ForIn.LeftDeclaration (_, decl) ->
        VariableDeclaration.test ~with_init:false decl
      | S.ForIn.LeftPattern pattern ->
        Pattern.test pattern

    let transpile
        ({Context. gen_binding; _} as ctx)
        scope
        ({S.ForIn. left; body = (body_loc, body); _ } as for_) =
      let binding = gen_binding scope in
      let left_declaration loc kind =
        S.ForIn.LeftDeclaration (
          loc,
          { kind;
            declarations = [(Loc.none, { S.VariableDeclaration.Declarator.
              id = (Loc.none, Ast.Pattern.Identifier {
                name = (Loc.none, binding);
                typeAnnotation = None;
                optional = false;
              });
              init = None
            })]
          }
        )
      in
      let prepend_stmt stmt =
        match body with
        | S.Block { body } ->
          body_loc, S.Block { body = stmt :: body }
        | prev ->
          body_loc, S.Block { body = stmt :: (Loc.none, prev) :: [] }
      in
      match left with
      | S.ForIn.LeftDeclaration (loc, { kind; declarations = (_, decl) :: [] }) ->
        let stmt =
          Loc.none,
          S.VariableDeclaration (
            VariableDeclaration.transpile ctx scope
            @@
            { S.VariableDeclaration.
              kind = S.VariableDeclaration.Let;
              declarations = [(Loc.none, {
                decl with
                init = Some (AstHelper.e_identifier binding)
              })]
            }
          )
        in
        S.ForIn {
          for_ with
          left = left_declaration loc kind;
          body = prepend_stmt stmt
        }
      | S.ForIn.LeftPattern pattern ->
        let stmt =
          Loc.none,
          S.VariableDeclaration (
            VariableDeclaration.transpile ctx scope
            @@
            { S.VariableDeclaration.
              kind = S.VariableDeclaration.Let;
              declarations = [(Loc.none, {
                id = pattern;
                init = Some (AstHelper.e_identifier binding)
              })]
            }
          )
        in
        S.ForIn {
          for_ with
          left = left_declaration Loc.none S.VariableDeclaration.Let;
          body = prepend_stmt stmt
        }
      | S.ForIn.LeftDeclaration (loc, _) ->
        raise (Error.TranspilerError (
          loc,
          "Unexpected ForIn: more than one declaration"
        ))

  end

  module Try = struct
    let test ((_,{ param; _ }) : Loc.t S.Try.CatchClause.t) =
      Pattern.test param

    let transpile context scope
        (loc, {S.Try.CatchClause. body = (body_loc, { body }); param }) =
      let name = context.Context.gen_binding scope in
      let new_param =
        (Loc.none, P.Identifier {
            name = (Loc.none, name);
            typeAnnotation = None;
            optional = false
        })
      in
      let body =
        (Loc.none,
         S.VariableDeclaration (
           VariableDeclaration.transpile context scope {
             S.VariableDeclaration.
             kind = S.VariableDeclaration.Let;
             declarations = [
               Loc.none, { S.VariableDeclaration.Declarator.
                 id = param;
                 init = Some (AstHelper.e_identifier name);
               }
             ]
           }
         )
        ) :: body
      in
      loc, {S.Try.CatchClause. param = new_param; body = (body_loc, { body }) }
  end

  module ForOf = struct

    let test {S.ForOf. left; _ } =
      match left with
      | S.ForOf.LeftDeclaration (_, decl) ->
        VariableDeclaration.test ~with_init:false decl
      | S.ForOf.LeftPattern pattern ->
        Pattern.test pattern

    let transpile
        ({Context. gen_binding; _} as ctx)
        scope
        ({S.ForOf. left; body = (body_loc, body); _ } as for_) =
      let binding = gen_binding scope in
      let left_declaration loc kind =
        S.ForOf.LeftDeclaration (
          loc,
          { kind;
            declarations = [(Loc.none, { S.VariableDeclaration.Declarator.
              id = (Loc.none, Ast.Pattern.Identifier {
                name = (Loc.none, binding);
                typeAnnotation = None;
                optional = false;
              });
              init = None
            })]
          }
        )
      in
      let prepend_stmt stmt =
        match body with
        | S.Block { body } ->
          body_loc, S.Block { body = stmt :: body }
        | prev ->
          body_loc, S.Block { body = stmt :: (Loc.none, prev) :: [] }
      in
      match left with
      | S.ForOf.LeftDeclaration (loc, { kind; declarations = (_, decl) :: [] }) ->
        let stmt =
          Loc.none,
          S.VariableDeclaration (
            VariableDeclaration.transpile ctx scope
            @@
            { S.VariableDeclaration.
              kind = S.VariableDeclaration.Let;
              declarations = [(Loc.none, {
                decl with
                init = Some (AstHelper.e_identifier binding)
              })]
            }
          )
        in
        S.ForOf {
          for_ with
          left = left_declaration loc kind;
          body = prepend_stmt stmt
        }
      | S.ForOf.LeftPattern pattern ->
        let stmt =
          Loc.none,
          S.VariableDeclaration (
            VariableDeclaration.transpile ctx scope
            @@
            { S.VariableDeclaration.
              kind = S.VariableDeclaration.Let;
              declarations = [(Loc.none, {
                id = pattern;
                init = Some (AstHelper.e_identifier binding)
              })]
            }
          )
        in
        S.ForOf {
          for_ with
          left = left_declaration Loc.none S.VariableDeclaration.Let;
          body = prepend_stmt stmt
        }
      | S.ForOf.LeftDeclaration (loc, _) ->
        raise (Error.TranspilerError (
          loc,
          "Unexpected ForOf: more than one declaration"
        ))

  end

end

let transpile ({Context. require_runtime; _ } as context) program =
  let map_statement {AstMapper. scope; _} ((loc, node) : Loc.t S.t) =
    let module T = TranspileObjectSpreadRest in
    let node = match node with
      | S.VariableDeclaration d when T.VariableDeclaration.test d ->
        require_runtime ();
        S.VariableDeclaration (T.VariableDeclaration.transpile context scope d)

      (* Only consider initdeclaration here
       * expression is handled in `map_expression`*)
      | S.For ({init = Some (S.For.InitDeclaration (_, decl)); _} as node)
        when T.VariableDeclaration.test decl ->
        require_runtime ();
        S.For {node with init = Some( S.For.InitDeclaration(
            Loc.none, T.VariableDeclaration.transpile context scope decl
          ))}

      | S.ForIn for_ when T.ForIn.test for_ ->
        require_runtime ();
        T.ForIn.transpile context scope for_

      | S.ForOf for_ when T.ForOf.test for_ ->
        require_runtime ();
        T.ForOf.transpile context scope for_

      | S.Try ({ handler = Some handler; _ } as stmt) when T.Try.test handler ->
        require_runtime ();
        S.Try { stmt with handler = Some (T.Try.transpile context scope handler)}

      | _ -> node
    in
    [loc, node]
  in

  let map_expression {AstMapper. scope; _} ((loc, node) : Loc.t E.t) =
    let node = match node with
      | E.Object obj when TranspileObjectSpread.test obj ->
        require_runtime ();
        snd (TranspileObjectSpread.transpile obj)
      | E.Assignment ({ operator = E.Assignment.Assign; _ } as obj)
        when TranspileObjectSpreadRest.Assignment.test obj ->
        require_runtime ();
        snd (TranspileObjectSpreadRest.Assignment.transpile context scope obj)
      | node -> node
    in
    loc, node
  in

  let map_function {AstMapper. scope; _} (loc, func) =
    if TranspileObjectSpreadRest.Function.test func
    then begin
      require_runtime ();
      (loc, TranspileObjectSpreadRest.Function.transpile context scope func)
    end
    else (loc, func)
  in

  let mapper = {
    AstMapper.default_mapper with
    map_expression;
    map_statement;
    map_function;
  } in

  AstMapper.map mapper program

