/*
 * *********************** Object Spread Expressions ***********************
 */

/* Own */
({ x, y, a, b, c: "test" });
({ x, ...y, a, ...b, c, inner: {some, ...rest} });

/* Babel */
({ x, ...y, a, ...b, c });

/*
 * *********************** Variable Assignment ***********************
 */

/* Babel */
var z = {};
var { ...x } = z;
var { ...a } = { a: 1 };
var { ...x } = a.b;
var { ...x } = a();
var {x1, ...y1} = z;
x1++;
var { [a]: b, ...c } = z;
var {x1, ...y1} = z;
let {x2, y2, ...z2} = z;
const {w3, x3, y3, ...z4} = z;

let {
  x: { a: xa, [d]: f, ...asdf },
  y: { ...d },
  ...g
} = complex;

let { x4: { ...y4 } } = z;

var { ...{ z } } = { z: 1 };
var { ...{ x = 5 } } = { x : 1 };

/* Own */

// Produce tmp_name for the expression
let {a, ...b} = {a: 1, b: 2, c: 3};

// Drop pattern entirely
let {x: {...xx}, y: {...yy}, ...zz} = z;

// Make sure to transpile inside the expression using the same scope
let {...x} = (function(){
  let {a, ...b} = {a: 1, b:2, c: 3};
  return b;
})();

// Computed property handling
let {[(function() {return "a";})()]:{...b}} = {a: {b: 2, c: 3}};
let {[(function() {return "a";})()]:{b, ...cc}} = {a: {b: 2, c: 3}};
