open Test

let%expect_test "transpile-react-jsx.js" =
  test transpile "transpile-react-jsx.js";
  [%expect_exact {|import React from 'react';
React.createElement("div", null);
React.createElement("div", {"className": "x"});
React.createElement("div", {"className": "x", "y": 1});
React.createElement("div", Object.assign({}, props));
React.createElement("div", Object.assign({}, {"className": "x"}, props));
React.createElement("div", Object.assign({}, {"className": "x"}, props, {"width": 100}));
React.createElement("div", null, 'some');
React.createElement("div", null, ' some ');
React.createElement("div", null, some);
React.createElement("div", null, 'X ', some);
React.createElement("div", null, 'X ', some, ' Y');
React.createElement("div", null, ' X ', some, ' Y ');
React.createElement("div", null, '  X ', some, ' Y');
React.createElement(React.Fragment, null, 'some thing');
React.createElement(React.Fragment, null, React.createElement("div", null), React.createElement("a", null));
React.createElement(React.Fragment, null, React.createElement("div", null), React.createElement("a", null));
React.createElement("div", null, React.createElement(React.Fragment, null, 'oops'));
React.createElement("div", null, React.createElement(React.Fragment, null, React.createElement("div", null), React.createElement("div", null)));
const App = ({components}) => React.createElement("div", null, components.map((Comp, i) => React.createElement("div", {"key": i}, React.createElement(Comp, null))));
React.createElement(X, {"component": true ? React.createElement(Comp1, null) : React.createElement(Comp2, null)});
|}]
