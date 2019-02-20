module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;

module E = Ast.Expression;
module I = Ast.Identifier;

module AstMapper = FastpackUtil.AstMapper;

let nbsp = {
  let buf = Buffer.create(2);
  Wtf8.add_wtf_8(buf, 0x00A0);
  Buffer.contents(buf);
};

/*
 Wtf8.fold_wtf_8 (fun () i c -> Printf.printf "N: %d %04x\n" i (match c with | Wtf8.Point p -> p | Malformed -> 0)) () s;;
                */
let encodeJSLiteral = s => {
  let buf = Buffer.create(String.length(s) * 6 + 2);
  let u = Printf.sprintf("\\u%04x");
  Buffer.add_char(buf, '"');
  Wtf8.fold_wtf_8(
    ((), _, codepoint) =>
      switch (codepoint) {
      | Wtf8.Malformed => () /* TODO: should we fail here? */
      | Wtf8.Point(p) =>
        switch (p) {
        | 0x22 => Buffer.add_string(buf, "\\\"")
        | p when p >= 0x20 && p <= 0x7f => Buffer.add_char(buf, Char.chr(p))
        | p when p <= 0xFFFF => Buffer.add_string(buf, u(p))
        | p =>
          /*
           https://mathiasbynens.be/notes/javascript-encoding#surrogate-formulae
           */
          Buffer.add_string(buf, u((p - 0x10000) / 0x400 + 0xD800));
          Buffer.add_string(buf, u((p - 0x10000) mod 0x400 + 0xDC00));
        }
      },
    (),
    s,
  );
  Buffer.add_char(buf, '"');
  Buffer.contents(buf);
};

let transpile = (_, program, modified) => {
  let null_expression = (
    Loc.none,
    E.Literal({value: Ast.Literal.Null, raw: "null"}),
  );

  let true_expression = (
    Loc.none,
    E.Literal(FastpackUtil.AstHelper.literal_true),
  );

  let map_expression =
      (context, (loc, node): Ast.Expression.t(Loc.t, Loc.t)) => {
    open Ast.JSX;

    /*** Transpile JSX elememnt name */
    let transpile_name = (name: name(Loc.t)) => {
      let aux_property = ((loc, {name}): Identifier.t(Loc.t)) => (
        loc,
        name,
      );

      let rec aux_object = (_object: MemberExpression._object(Loc.t)) =>
        switch (_object) {
        | MemberExpression.Identifier((loc, {name})) =>
          E.Identifier((loc, name))
        | MemberExpression.MemberExpression((loc, {_object, property})) =>
          E.Member({
            _object: (loc, aux_object(_object)),
            property: E.Member.PropertyIdentifier(aux_property(property)),
            computed: false,
          })
        };

      switch (name) {
      | Identifier((loc, {name})) =>
        if (Str.string_match(Str.regexp("^[A-Z]"), name, 0)) {
          E.Expression((loc, E.Identifier((loc, name))));
        } else {
          E.Expression(FastpackUtil.AstHelper.e_literal_str(name));
        }
      | MemberExpression((loc, {_object, property})) =>
        E.Expression((
          loc,
          E.Member({
            _object: (Loc.none, aux_object(_object)),
            property: E.Member.PropertyIdentifier(aux_property(property)),
            computed: false,
          }),
        ))
      | NamespacedName((loc, _)) =>
        raise(
          Error.TranspilerError((
            loc,
            "Namespaced tags are not supported. ReactJSX is not XML",
          )),
        )
      };
    };

    /*** Transpile JSX attributes */
    let transpile_attributes =
        (attributes: list(Opening.attribute(Loc.t, Loc.t))) => {
      let empty_object_literal = (Loc.none, E.Object({properties: []}));

      let object_assign = arguments => (
        Loc.none,
        E.Call({
          callee: (
            Loc.none,
            E.Member({
              computed: false,
              _object: (Loc.none, E.Identifier((Loc.none, "Object"))),
              property: E.Member.PropertyIdentifier((Loc.none, "assign")),
            }),
          ),
          arguments: [
            E.Expression(empty_object_literal),
            ...List.rev(arguments),
          ],
          targs: None,
        }),
      );

      switch (attributes) {
      /*** If no attributes present we pass null */
      | [] => E.Expression(null_expression)
      | attributes =>
        let add_to_expressions = (bucket, expressions) =>
          switch (bucket) {
          | [] => expressions
          | properties =>
            let expr = (
              Loc.none,
              E.Object({properties: List.rev(properties)}),
            );
            [`Expression(expr), ...expressions];
          };

        let (bucket, expressions) =
          List.fold_left(
            ((bucket, expressions), attr: Opening.attribute(Loc.t, Loc.t)) =>
              switch (attr) {
              | Opening.Attribute((loc, {name, value})) =>
                let key =
                  switch (name) {
                  | Attribute.Identifier((loc, {name})) =>
                    E.Object.Property.Literal((
                      loc,
                      {
                        value: Ast.Literal.String(name),
                        raw: "\"" ++ name ++ "\"",
                      },
                    ))
                  | Attribute.NamespacedName((loc, _)) =>
                    raise(
                      Error.TranspilerError((
                        loc,
                        "Namespaced tags are not supported. ReactJSX is not XML",
                      )),
                    )
                  };

                let value =
                  switch (value) {
                  | None => true_expression
                  | Some(
                      Attribute.Literal(
                        loc,
                        {value: Ast.Literal.String(value), _},
                      ),
                    ) => (
                      loc,
                      E.Literal({
                        value: String(value),
                        raw:
                          value
                          |> String.split_on_char('\n')
                          |> List.map(String.trim)
                          |> String.concat("\\n")
                          |> encodeJSLiteral,
                      }),
                    )
                  | Some(Attribute.Literal(loc, {value, raw})) => (
                      loc,
                      E.Literal({value, raw}),
                    )
                  | Some(
                      Attribute.ExpressionContainer(
                        _loc,
                        {expression: ExpressionContainer.Expression(expr)},
                      ),
                    ) =>
                    AstMapper.map_expression(context, expr)
                  | Some(
                      Attribute.ExpressionContainer(
                        loc,
                        {expression: ExpressionContainer.EmptyExpression(_)},
                      ),
                    ) =>
                    raise(
                      Error.TranspilerError((
                        loc,
                        "Found EmptyExpression container",
                      )),
                    )
                  };

                let prop =
                  E.Object.Property((
                    loc,
                    E.Object.Property.Init({key, value, shorthand: false}),
                  ));
                ([prop, ...bucket], expressions);
              | Opening.SpreadAttribute((_loc, {argument})) =>
                let expressions = add_to_expressions(bucket, expressions);
                let spread = `Spread(argument);
                ([], [spread, ...expressions]);
              },
            ([], []),
            attributes,
          );

        let expressions = expressions |> add_to_expressions(bucket);
        switch (expressions) {
        | [] => E.Expression(null_expression)
        | [`Spread(expr)] =>
          E.Expression(object_assign([E.Expression(expr)]))
        | [`Expression(expr)] => E.Expression(expr)
        | items =>
          let items =
            items
            |> List.map(
                 fun
                 | `Spread(expr) => E.Expression(expr)
                 | `Expression(expr) => E.Expression(expr),
               );

          E.Expression(object_assign(items));
        };
      };
    };

    let rec transpile_children = children => {
      let trim_text = text => {
        let is_not_empty_line = line => String.trim(line) != "";

        text
        |> String.split_on_char('\n')
        |> List.filter(is_not_empty_line)
        |> String.concat(" ");
      };

      let transpile_child = ((loc, child): child(Loc.t, Loc.t)) => {
        let expr =
          switch (child) {
          | Element(element) => Some((loc, transpile_element(element)))
          | ExpressionContainer({
              expression: ExpressionContainer.Expression(expression),
            }) =>
            Some(AstMapper.map_expression(context, expression))
          | ExpressionContainer({
              expression: ExpressionContainer.EmptyExpression(_),
            }) =>
            None
          | Text({value, raw}) =>
            let value = trim_text(value);
            /* TODO: this is a bug in flow_parse@0.81. To be removed when we update parser */
            let value =
              if (CCString.mem(~sub="&nbsp;", value)
                  && CCString.mem(~sub="&nbsp;", raw)) {
                CCString.replace(~sub="&nbsp;", ~by=nbsp, value);
              } else {
                value;
              };

            Some((
              loc,
              E.Literal({
                value: Ast.Literal.String(value),
                raw: encodeJSLiteral(value),
              }),
            ));
          | Fragment(fragment) => Some((loc, transpile_fragment(fragment)))
          | SpreadChild(_) =>
            raise(
              Error.TranspilerError((loc, "SpreadChild are not implemented")),
            )
          };

        switch (expr) {
        | Some(expr) => [E.Expression(expr)]
        | None => []
        };
      };

      children
      |> List.map(transpile_child)
      |> List.concat
      |> List.filter(child =>
           switch (child) {
           | E.Expression((_, E.Literal({raw: "''", _}))) => false
           | _ => true
           }
         );
    }
    and transpile_element =
        ({openingElement: (_, openingElement), children, _}) => {
      let {Opening.name, attributes, _} = openingElement;
      E.Call({
        callee: (
          Loc.none,
          E.Member({
            computed: false,
            _object: (Loc.none, E.Identifier((Loc.none, "React"))),
            property:
              E.Member.PropertyIdentifier((Loc.none, "createElement")),
          }),
        ),
        arguments: [
          transpile_name(name),
          transpile_attributes(attributes),
          ...transpile_children(children),
        ],
        targs: None,
      });
    }
    and transpile_fragment =
        ({frag_openingElement: _, frag_closingElement: _, frag_children}) => {
      let elements = frag_children |> transpile_children;

      let name =
        E.Expression((
          loc,
          E.Member({
            _object: (Loc.none, E.Identifier((Loc.none, "React"))),
            property: E.Member.PropertyIdentifier((Loc.none, "Fragment")),
            computed: false,
          }),
        ));

      E.Call({
        callee: (
          Loc.none,
          E.Member({
            computed: false,
            _object: (Loc.none, E.Identifier((Loc.none, "React"))),
            property:
              E.Member.PropertyIdentifier((Loc.none, "createElement")),
          }),
        ),
        arguments: [name, E.Expression(null_expression), ...elements],
        targs: None,
      });
    };

    switch (node) {
    | E.JSXElement(element) => (Loc.none, transpile_element(element))
    | E.JSXFragment(fragment) => (Loc.none, transpile_fragment(fragment))
    | node => (loc, node)
    };
  };

  let mapper = {...AstMapper.default_mapper, map_expression};

  AstMapper.map(~modified, mapper, program);
};
