open Test

let%expect_test "ReactJSX" =
  testString transpile {|
import React from 'react'

<div />;

<div className="x" />;

<div className="x" y={1} />;

<div {...props} />;

<div className="x" {...props} />;

<div className="x" {...props} width={100} />;

<div>some</div>;

<div> some </div>;

<div>{some}</div>;

<div>X {some}</div>;

<div>X {some} Y</div>;

<div> X {some} Y </div>;

<div>
  X {some} Y
</div>;

<>some thing</>;

<>
  <div />
  <a />
</>;

<><div /> <a /></>;

<div>
  <>oops</>
</div>;

<div>
  <><div /><div /></>
</div>;

const App = ({ components }) => (
  <div>
    {components.map((Comp, i) => (
      <div key={i}>
        <Comp />
      </div>
    ))}
  </div>
);

<X component={true ? <Comp1 /> : <Comp2 />}/>;
<X>{/*
<div></div>
*/}</X>;
<Escape>&nbsp;</Escape>;
<X>&nbsp;&lt;&gt;&quot;&amp;&Dagger;</X>;
|}; [%expect_exact {|import React from 'react';
React.createElement("div", null);
React.createElement("div", {"className": "x"});
React.createElement("div", {"className": "x", "y": 1});
React.createElement("div", Object.assign({}, props));
React.createElement("div", Object.assign({}, {"className": "x"}, props));
React.createElement("div", Object.assign({}, {"className": "x"}, props, {"width": 100}));
React.createElement("div", null, "some");
React.createElement("div", null, " some ");
React.createElement("div", null, some);
React.createElement("div", null, "X ", some);
React.createElement("div", null, "X ", some, " Y");
React.createElement("div", null, " X ", some, " Y ");
React.createElement("div", null, "  X ", some, " Y");
React.createElement(React.Fragment, null, "some thing");
React.createElement(React.Fragment, null, "", React.createElement("div", null), "", React.createElement("a", null), "");
React.createElement(React.Fragment, null, React.createElement("div", null), "", React.createElement("a", null));
React.createElement("div", null, "", React.createElement(React.Fragment, null, "oops"), "");
React.createElement("div", null, "", React.createElement(React.Fragment, null, React.createElement("div", null), React.createElement("div", null)), "");
const App = ({components}) => React.createElement("div", null, "", components.map((Comp, i) => React.createElement("div", {"key": i}, "", React.createElement(Comp, null), "")), "");
React.createElement(X, {"component": true ? React.createElement(Comp1, null) : React.createElement(Comp2, null)});
React.createElement(X, null);
/*
<div></div>
*/
React.createElement(Escape, null, "\u00a0");
React.createElement(X, null, "\u00a0<>\"&\u2021");
|}]

