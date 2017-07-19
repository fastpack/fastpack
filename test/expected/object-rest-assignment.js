/* Babel */
var z = {};
var x = $fpack.removeProps(z, []);
var a = $fpack.removeProps({ a: 1 }, []);
var x = $fpack.removeProps(a.b, []);
var x = $fpack.removeProps(a(), []);
var {x1} = z, y1 = $fpack.removeProps(z, ["x1"]);
let y4 = $fpack.removeProps(z.x4, []);
let {
  x: { a: xa, [d]: f }
} = complex, asdf = $fpack.removeProps(complex.x, ["a",d]), d = $fpack.removeProps(complex.y, []), g = $fpack.removeProps(complex, ["x","y"]);
