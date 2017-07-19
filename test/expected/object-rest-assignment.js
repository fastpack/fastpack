/* Babel */
var z = {};
var x = $fpack.removeProps(z, []);
var $$fpack_1 = { a: 1 }, a = $fpack.removeProps($$fpack_1, []);
var $$fpack_2 = a.b, x = $fpack.removeProps($$fpack_2, []);
var $$fpack_3 = a(), x = $fpack.removeProps($$fpack_3, []);
var {x1} = z, y1 = $fpack.removeProps(z, ["x1"]);
let y4 = $fpack.removeProps(z.x4, []);
let {
  x: { a: xa, [d]: f }
} = complex, asdf = $fpack.removeProps(complex.x, ["a", d]), d = $fpack.removeProps(complex.y, []), g = $fpack.removeProps(complex, ["x", "y"]);

/* Own */
let $$fpack_4 = {a: 1, b: 2, c: 3}, {a} = $$fpack_4, b = $fpack.removeProps($$fpack_4, ["a"]);
