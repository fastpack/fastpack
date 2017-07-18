var z = {};
var { ...x } = z;
var { ...a } = { a: 1 };
var { ...x } = a.b;
var { ...x } = a();
var {x1, ...y1} = z;
let { x4: { ...y4 } } = z;
let {
  x: { a: xa, [d]: f, ...asdf },
  y: { ...d },
  ...g
} = complex;
