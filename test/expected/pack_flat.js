
/* a.js-fb1192555b4afa97f8bf590f5331902d */


let $_e1 = 1;
let $_e2 = 2;

const $_e3 = {a1: $_e1, a2: $_e2};
/* d.js-4b186fd1d6f1579cb8d1e2d8b3961ffe */

export function $_e4() {
  let c;
  if(true) {
    c = __fpack__.cached($_w1);
  }
  else {
    c = __fpack__.cached($_w1);
  }
  return c;
}

let $_e5 = d1;

const $_e6 = {d1: $_e4, d2: $_e5};
/* e.js-53755ac792d422954b7b38d32fb8e8f6 */

console.log('"e" is imported');

const $_e7 = {};
/* index.js-c46c4e9e002d45c71aaf635189f80e19 */




{
  {
    ($_e7);
  }
}
console.log(A2, D);


/*
 * Legend
 *   (=>) : requires statically
 *   (->) : requires dynamically
 * Dependencies:
 *   index => a
 *   index => d
 *   index => e
 *   d => a
 *   d -> c
 *   c -> b
 *   b => a
 */

const $_e8 = {};
/* c.js-d61468bee36ba5f51f6f73437a95ba4a */


function $_w1() {

let $_i1 = 100;
let $_i2 = 200;

function $_i3() {
  let b = __fpack__.cached($_w2);
  return b.b1() + b.b2() + cInternal1;
}

function $_i4() {
  let b = __fpack__.cached($_w2);
  return b.default.b1() + b.default.b2() + cInternal2;
}

Object.assign(module.exports, {c1, c2});
return ({});
}

/* b.js-fbc8722aa7253184e85b898677c98268 */


function $_w2() {


export function $_e9() {
  return a + 1;
}

export function $_e10() {
  return a + 2;
}

export default {b1, b2, b3: a1};
return ({b1: $_e9, b2: $_e10});
}
