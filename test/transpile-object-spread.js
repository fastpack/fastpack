/*
 * *********************** Object Spread Expressions ***********************
 */

/* Own */
({ x, y, a, b, c: "test" });
({ x, ...y, a, ...b, c, inner: {some, ...rest} });

/* Babel */
({ x, ...y, a, ...b, c });
z = { x, ...y };
z = { x, w: { ...y } };
var z = { ...x };

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
var [x, {y, ...p}] = [1, {y: 100, z: 1, zz:10}];
var [x, {...p}] = [1, {y: 100, z: 1, zz:10}];

var { outer: { inner: { three, ...other } } } = defunct
var test = {
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

var { foo: { bar: { baz: { a: { x, ...other } } } } } = test;

/* Own */

// Produce tmp_name for the expression
var {a, ...b} = {a: 1, b: 2, c: 3};

// Drop pattern entirely
var {x: {...xx}, y: {...yy}, ...zz} = z;

// Make sure to transpile inside the expression using the same scope
var {...x} = (function(){
  let {a, ...b} = {a: 1, b:2, c: 3};
  return b;
})();

// Computed property handling
var {[(function() {return "a";})()]:{...b}} = {a: {b: 2, c: 3}};
var {[(function() {return "a";})()]:{b, ...cc}} = {a: {b: 2, c: 3}};

/*
 * *********************** Assignment Expressions ***********************
 */

/* Babel */
({ a1 } = c1);
({ a2, ...b2 } = c2);

console.log({ a3, ...b3 } = c3);

/* Own  - Babel fails on this */

console.log({ a, ["c" + ""]:{...xx}, ...b } = {a: 1, b: 2, c: {x: 1}});

/*
 * *********************** Functions ***********************
 */

/* Own */

function ff({...a}) {};
let f1 = function ({...b}) {};
let f2 = ({...c}) => c;
let f3 = ({...c}) => {return c};

// many parameters
function f5(a, {b:{...c}}, {d:{e:{f:{...g}}}}) {};
let f6 = ({a, ...b}, c, {d: {e: {...f}}}) => ({});

// could rest pattern be a part of the rest element at all?
function f7(a, ...b) {};
function f8(a, ...{b, ...c}) {};
function f9(a, {b:{...c}}, ...{...d}) {};
