open Test

let%expect_test "transpile-object-spread.js" =
  test transpile "transpile-object-spread.js";
  [%expect_exact {|const $__fpack__ = require("$fp$runtime");
/*
 * *********************** Object Spread Expressions ***********************
 */
/* Own */
({x, y, a, b, c: "test"});
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
var __fpack__6 = [1, {y: 100, z: 1, zz: 10}],
  [x, {y}] = __fpack__6,
  p = $__fpack__.omitProps(__fpack__6[1], ["y"]);
var __fpack__7 = [1, {y: 100, z: 1, zz: 10}],
  [x, ] = __fpack__7,
  p = $__fpack__.omitProps(__fpack__7[1], []);
var {outer: {inner: {three}}} = defunct,
  other = $__fpack__.omitProps(defunct.outer.inner, ["three"]);
var test = {foo: {bar: {baz: {a: {x: 1, y: 2, z: 3}}}}};
var {foo: {bar: {baz: {a: {x}}}}} = test,
  other = $__fpack__.omitProps(test.foo.bar.baz.a, ["x"]);
/* Own */
// Produce tmp_name for the expression
var __fpack__8 = {a: 1, b: 2, c: 3},
  {a} = __fpack__8,
  b = $__fpack__.omitProps(__fpack__8, ["a"]);
// Drop pattern entirely
var xx = $__fpack__.omitProps(z.x, []),
  yy = $__fpack__.omitProps(z.y, []),
  zz = $__fpack__.omitProps(z, ["x", "y"]);
// Make sure to transpile inside the expression using the same scope
var __fpack__10 = (function () {
    let __fpack__9 = {a: 1, b: 2, c: 3},
      {a} = __fpack__9,
      b = $__fpack__.omitProps(__fpack__9, ["a"]);
    return b;
    
  }
  )(),
  x = $__fpack__.omitProps(__fpack__10, []);
// Computed property handling
var __fpack__11 = {a: {b: 2, c: 3}},
  __fpack__12 = (function () {
    return "a";
    
  }
  )(),
  b = $__fpack__.omitProps(__fpack__11[__fpack__12], []);
var __fpack__13 = {a: {b: 2, c: 3}},
  __fpack__14 = (function () {
    return "a";
    
  }
  )(),
  {[__fpack__14]: {b}} = __fpack__13,
  cc = $__fpack__.omitProps(__fpack__13[__fpack__14], ["b"]);
/*
 * *********************** Assignment Expressions ***********************
 */
/* Babel */
({a1} = c1);
(() => {
  ({a2} = c2);
  b2 = $__fpack__.omitProps(c2, ["a2"]);
  return c2;
  
}
)();
console.log((() => {
  ({a3} = c3);
  b3 = $__fpack__.omitProps(c3, ["a3"]);
  return c3;
  
}
)());
/* Own  - Babel fails on this */
console.log((() => {
  let __fpack__15 = {a: 1, b: 2, c: {x: 1}},
    __fpack__16 = "c" + "";
  ({a} = __fpack__15);
  xx = $__fpack__.omitProps(__fpack__15[__fpack__16], []);
  b = $__fpack__.omitProps(__fpack__15, ["a", __fpack__16]);
  return __fpack__15;
  
}
)());
/*
 * *********************** Functions ***********************
 */
/* Own */
function ff(__fpack__17) {
  let a = $__fpack__.omitProps(__fpack__17, []);
  
}
let f1 = function (__fpack__18) {
    let b = $__fpack__.omitProps(__fpack__18, []);
    
  }
  ;
let f2 = __fpack__19 => {
    let c = $__fpack__.omitProps(__fpack__19, []);
    return c;
    
  }
  ;
let f3 = __fpack__20 => {
    let c = $__fpack__.omitProps(__fpack__20, []);
    return c;
    
  }
  ;
// many parameters
function f5(a, __fpack__21, __fpack__22) {
  let c = $__fpack__.omitProps(__fpack__21.b, []),
    g = $__fpack__.omitProps(__fpack__22.d.e.f, []);
  
}
let f6 = (__fpack__23, c, __fpack__24) => {
    let {a} = __fpack__23,
      b = $__fpack__.omitProps(__fpack__23, ["a"]),
      f = $__fpack__.omitProps(__fpack__24.d.e, []);
    return {};
    
  }
  ;
// could rest pattern be a part of the rest element at all?
function f7(a, ...b) {
  
}
function f8(a, ...__fpack__25) {
  let {b} = __fpack__25,
    c = $__fpack__.omitProps(__fpack__25, ["b"]);
  
}
function f9(a, __fpack__26, ...__fpack__27) {
  let c = $__fpack__.omitProps(__fpack__26.b, []),
    d = $__fpack__.omitProps(__fpack__27, []);
  
}
// basic for loop
for (p = (() => {
  let __fpack__28 = {x: 1, a: 2};
  ({x} = __fpack__28);
  y = $__fpack__.omitProps(__fpack__28, ["x"]);
  return __fpack__28;
  
}
)(); false; )
  {
    
  }
for (var __fpack__29 = {x: 1, a: 2}, {x} = __fpack__29, y = $__fpack__.omitProps(__fpack__29, ["x"]); false; )
  {
    
  }
// for in
for (let __fpack__30 in iterator)
  {
    let {x} = __fpack__30,
      y = $__fpack__.omitProps(__fpack__30, ["x"]);
    
  }
for (var __fpack__31 in iterator)
  {
    let {x} = __fpack__31,
      y = $__fpack__.omitProps(__fpack__31, ["x"]);
    
  }
for (let __fpack__32 in iterator)
  {
    let {x} = __fpack__32,
      y = $__fpack__.omitProps(__fpack__32, ["x"]);
    console.log(x);
    
  }
for (var __fpack__33 in iterator)
  {
    let {x} = __fpack__33,
      y = $__fpack__.omitProps(__fpack__33, ["x"]);
    console.log(x);
    
  }
// for of
for (let __fpack__34 of iterator)
  {
    let {x} = __fpack__34,
      y = $__fpack__.omitProps(__fpack__34, ["x"]);
    
  }
for (var __fpack__35 of iterator)
  {
    let {x} = __fpack__35,
      y = $__fpack__.omitProps(__fpack__35, ["x"]);
    
  }
for (let __fpack__36 of iterator)
  {
    let {x} = __fpack__36,
      y = $__fpack__.omitProps(__fpack__36, ["x"]);
    console.log(x);
    
  }
for (var __fpack__37 of iterator)
  {
    let {x} = __fpack__37,
      y = $__fpack__.omitProps(__fpack__37, ["x"]);
    console.log(x);
    
  }
// try
try {
  throw {x: 1, y: 2, z: 3};
  
} catch (__fpack__38) {
  let {x} = __fpack__38,
    rest = $__fpack__.omitProps(__fpack__38, ["x"]);
  console.log(x, rest);
  
}
|}]
