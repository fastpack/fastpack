module S = Ast.Statement
module E = Ast.Expression
module L = Ast.Literal

let void_0 =
  Loc.none, E.Unary {
    operator = E.Unary.Void;
    prefix = true;
    argument = (Loc.none, E.Literal {L. value = Number 0.0; raw = "0"})
  }

let literal_str s =
  let raw = "\"" ^ s ^ "\"" in
  {L. value = L.String raw; raw }

let literal_true =
  {L. value = L.Boolean true; raw = "true"}

let member _object property =
  Loc.none, E.Member {
    _object = (Loc.none, E.Identifier (Loc.none, _object));
    property = E.Member.PropertyIdentifier (Loc.none, property);
    computed = false;
  }

let call callee arguments =
  Loc.none, E.Call {
    callee;
    arguments = List.map (fun arg -> E.Expression arg) arguments; 
  }

let object_ properties =
  Loc.none, E.Object { properties }

let object_property name value =
  E.Object.Property (Loc.none, {
    key = E.Object.Property.Literal (Loc.none, literal_str name);
    value = E.Object.Property.Init value;
    _method = false;
    shorthand = false
  })

let object_define_property key value =
  call (member "Object" "defineProperty") [
    (Loc.none, E.This);
    (Loc.none, E.Literal key);
    (object_ [
      object_property "configurable" (Loc.none, E.Literal literal_true);
      object_property "enumerable" (Loc.none, E.Literal literal_true);
      object_property "writable" (Loc.none, E.Literal literal_true);
      object_property "value" value;
    ])
  ]

let return expr =
  Loc.none, S.Return {argument = Some expr}

let to_array convertor list : E.t =
  Loc.none, E.Array {
    elements =
      list
      |> List.map convertor
      |> List.map (fun el -> Some (E.Expression el))
  }

let fpack_define_class cls statics =
  call (member "$fpack" "defineClass") [
    (Loc.none, E.Class cls);
    statics
  ]

let let_stmt loc name value =
  (loc, S.VariableDeclaration {
    kind = S.VariableDeclaration.Let;
    declarations = [(Loc.none, { S.VariableDeclaration.Declarator.
      id = (Loc.none, Ast.Pattern.Identifier {
        name = (Loc.none, name);
        typeAnnotation = None;
        optional = false;
      });
      init = Some value
    })]
  })
