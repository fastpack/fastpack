/* Babel */
var z = {};
var x = $fpack.removeProps(z, []);
var $$fpack_1 = { a: 1 }, a = $fpack.removeProps($$fpack_1, []);
var $$fpack_2 = a.b, x = $fpack.removeProps($$fpack_2, []);
var $$fpack_3 = a(), x = $fpack.removeProps($$fpack_3, []);
var {x1} = z, y1 = $fpack.removeProps(z, ["x1"]);
x1++;
var { [a]: b } = z, c = $fpack.removeProps(z, [a]);
var {x1} = z, y1 = $fpack.removeProps(z, ["x1"]);
let {x2, y2} = z, z2 = $fpack.removeProps(z, ["x2", "y2"]);
const {w3, x3, y3} = z, z4 = $fpack.removeProps(z, ["w3", "x3", "y3"]);

let {
  x: { a: xa, [d]: f }
} = complex, asdf = $fpack.removeProps(complex.x, ["a", d]), d = $fpack.removeProps(complex.y, []), g = $fpack.removeProps(complex, ["x", "y"]);

let y4 = $fpack.removeProps(z.x4, []);

var $$fpack_4 = { z: 1 }, { z } = $fpack.removeProps($$fpack_4, []);
var $$fpack_5 = { x : 1 }, { x = 5 } = $fpack.removeProps($$fpack_5, []);

/* Own */

// Produce tmp_name for the expression
let $$fpack_6 = {a: 1, b: 2, c: 3}, {a} = $$fpack_6, b = $fpack.removeProps($$fpack_6, ["a"]);

// Drop pattern entirely
let xx = $fpack.removeProps(z.x, []), yy = $fpack.removeProps(z.y, []), zz = $fpack.removeProps(z, ["x", "y"]);

// Make sure to transpile inside the expression using the same scope
let $$fpack_7 = (function(){
  let $$fpack_8 = {a: 1, b:2, c: 3}, {a} = $$fpack_8, b = $fpack.removeProps($$fpack_8, ["a"]);
  return b;
})(), x = $fpack.removeProps($$fpack_7, []);
