module Ast = FlowParser.Ast
module Loc = FlowParser.Loc
module S = Ast.Statement
module E = Ast.Expression
module P = Ast.Pattern
module L = Ast.Literal

module Visit = FastpackUtil.Visit

type t = Production | Development | Test

let to_string m =
match m with
| Production -> "production"
| Development -> "development"
| Test -> "test"

let rec is_matched expr mode =
match expr with
| (_, E.Logical { operator = E.Logical.Or; left; _ }) ->
  is_matched left mode

| (_, E.Binary {
    left = (_, E.Literal { value = L.String value; _});
    right = (_, E.Member {
      _object = (_, E.Member {
        _object = (_, E.Identifier (_, "process"));
        property = E.Member.PropertyIdentifier (_, "env");
        computed = false;
        _
      });
      property = E.Member.PropertyIdentifier (_, "NODE_ENV");
      computed = false;
      _
    });
    operator;
  })
| (_, E.Binary {
    left = (_, E.Member {
      _object = (_, E.Member {
        _object = (_, E.Identifier (_, "process"));
        property = E.Member.PropertyIdentifier (_, "env");
        computed = false;
        _
      });
      property = E.Member.PropertyIdentifier (_, "NODE_ENV");
      computed = false;
      _
    });
    right = (_, E.Literal { value = L.String value; _});
    operator;
  }) ->
  begin
    match operator with
    | E.Binary.Equal | E.Binary.StrictEqual ->
      Some (value = to_string mode)
    | E.Binary.NotEqual | E.Binary.StrictNotEqual ->
      Some (value <> to_string mode)
    | _ ->
      None
  end
| _ ->
  None

let patch_statement
  { Workspace. remove; patch_loc; _ }
  mode
  ({Visit. parents; _ } as visit_ctx)
  (stmt_loc, _) =
match parents with
| (Visit.APS.Statement (loc, S.If {
    test;
    consequent = (consequent_loc, _);
    alternate;
  })) :: _ ->
  begin
    match is_matched test mode with
    | None ->
      Visit.Continue visit_ctx
    | Some is_matched ->
      if consequent_loc = stmt_loc then begin
        match is_matched with
        (* patch test & alternate *)
        | true ->
          remove
            loc.Loc.start.offset
            (consequent_loc.Loc.start.offset - loc.Loc.start.offset);
          begin
            match alternate with
            | None -> ()
            | Some (alternate_loc, _) ->
              remove
                consequent_loc.Loc._end.offset
                (alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset)
          end;
          Visit.Continue visit_ctx

        (* patch test & consequent *)
        | false ->
          let () =
            match alternate with
            | None ->
              patch_loc loc "{}"
            | Some (alternate_loc, _) ->
              remove
                loc.Loc.start.offset
                (alternate_loc.Loc.start.offset - loc.Loc.start.offset);
          in
          Visit.Break
      end
      else begin
        if (not is_matched) then Visit.Continue visit_ctx else Visit.Break
      end
  end
| _ ->
  Visit.Continue visit_ctx

let patch_expression
  { Workspace. remove; patch_loc; _ }
  mode
  ({Visit. parents; _ } as visit_ctx)
  (expr_loc, expr) =
match parents with
| (Visit.APS.Expression (loc, E.Conditional {
    test;
    consequent = (consequent_loc, _);
    alternate = (alternate_loc, _)
  })) :: _ ->
  begin
    match is_matched test mode with
    | None ->
      Visit.Continue visit_ctx
    | Some is_matched ->
      if consequent_loc = expr_loc then begin
        match is_matched with
        (* patch test & alternate *)
        | true ->
          remove
            loc.Loc.start.offset
            (consequent_loc.Loc.start.offset - loc.Loc.start.offset);
          remove
            (consequent_loc.Loc._end.offset)
            (alternate_loc.Loc._end.offset - consequent_loc.Loc._end.offset);
          Visit.Continue visit_ctx

        (* patch test & consequent *)
        | false ->
          remove
            loc.Loc.start.offset
            (alternate_loc.Loc.start.offset - loc.Loc.start.offset);
          Visit.Break
      end
      else begin
        if (not is_matched) then Visit.Continue visit_ctx else Visit.Break
      end
  end

| _ ->
  match expr with
  | E.Member {
      _object = (_, E.Member {
        _object = (_, E.Identifier (_, "process"));
        property = E.Member.PropertyIdentifier (_, "env");
        computed = false;
        _
      });
      property = E.Member.PropertyIdentifier (_, "NODE_ENV");
      computed = false;
      _
    } ->
    patch_loc expr_loc @@ "\"" ^ to_string mode ^ "\"";
    Visit.Break;
  | _ ->
    Visit.Continue visit_ctx
