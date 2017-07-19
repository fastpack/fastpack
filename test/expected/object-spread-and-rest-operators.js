/*
 * *********************** Object Spread Expressions ***********************
 */

/* Own */
({ x, y, a, b, c: "test" });
(Object.assign({}, {x}, y, {a}, b, {c}, {inner: Object.assign({},{some}, rest)} ));

/* Babel */
(Object.assign({}, {x}, y, {a}, b, {c} ));
z = Object.assign({}, {x}, y );
z = { x, w: Object.assign({}, y ) };
var z = Object.assign({}, x );

/*
 * *********************** Variable Assignment ***********************
 */

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
const { outer: { inner: { three } } } = defunct, other = $fpack.removeProps(defunct.outer.inner, ["three"])
const test = {
  foo: {
    bar: {
      baz: {
        a: {
          x: 1,
          y: 2,
          z: 3,
        },
      },
    },
  },
};

const { foo: { bar: { baz: { a: { x } } } } } = test, other = $fpack.removeProps(test.foo.bar.baz.a, ["x"]);

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

// Computed property handling
let $$fpack_9 = {a: {b: 2, c: 3}}, $$fpack_10 = (function() {return "a";})(), b = $fpack.removeProps($$fpack_9[$$fpack_10], []);
let $$fpack_11 = {a: {b: 2, c: 3}}, $$fpack_12 = (function() {return "a";})(), {[$$fpack_12]:{b}} = $$fpack_11, cc = $fpack.removeProps($$fpack_11[$$fpack_12], ["b"]);

/*
 * *********************** Assignment Expressions ***********************
 */

/* Babel */
({ a1 } = c1);
(($$fpack_13 = c2, { a2 } = $$fpack_13, b2 = $fpack.removeProps($$fpack_13, ["a2"])));

console.log(($$fpack_14 = c3, { a3 } = $$fpack_14, b3 = $fpack.removeProps($$fpack_14, ["a3"])));

/* Own */

console.log(($$fpack_15 = {a: 1, b: 2, c: {x: 1}}, $$fpack_16 = "c" + "", { a } = $$fpack_15, xx = $fpack.removeProps($$fpack_15[$$fpack_16], []), b = $fpack.removeProps($$fpack_15, ["a", $$fpack_16])));
