/*
 * *********************** Object Spread Expressions ***********************
 */
/* Own */
{x, y, a, b, c: "test"};
Object.assign({}, {x}, y, {a}, b, {c, inner: Object.assign({}, {some}, rest)});
/* Babel */
Object.assign({}, {x}, y, {a}, b, {c});
z = Object.assign({}, {x}, y);
z = {x, w: Object.assign({}, y)};
var z = Object.assign({}, x);
/*
 * *********************** Variable Assignment ***********************
 */
/* Babel */
var z = {};
var x = $__fpack__.omitProps(z, []);
var __fpack__1 = {a: 1},
  a = $__fpack__.omitProps(__fpack__1, []);
var __fpack__2 = a.b,
  x = $__fpack__.omitProps(__fpack__2, []);
var __fpack__3 = a(),
  x = $__fpack__.omitProps(__fpack__3, []);
var {x1} = z,
  y1 = $__fpack__.omitProps(z, ["x1"]);
x1++;
var {[a]: b} = z,
  c = $__fpack__.omitProps(z, [a]);
var {x1} = z,
  y1 = $__fpack__.omitProps(z, ["x1"]);
let {x2, y2} = z,
  z2 = $__fpack__.omitProps(z, ["x2", "y2"]);
const {w3, x3, y3} = z,
  z4 = $__fpack__.omitProps(z, ["w3", "x3", "y3"]);
let {x: {a: xa, [d]: f}} = complex,
  asdf = $__fpack__.omitProps(complex.x, ["a", d]),
  d = $__fpack__.omitProps(complex.y, []),
  g = $__fpack__.omitProps(complex, ["x", "y"]);
let y4 = $__fpack__.omitProps(z.x4, []);
var __fpack__4 = {z: 1},
  {z} = $__fpack__.omitProps(__fpack__4, []);
var __fpack__5 = {x: 1},
  {x = 5} = $__fpack__.omitProps(__fpack__5, []);
