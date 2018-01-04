
/* a.js-fb1192555b4afa97f8bf590f5331902d */


let $_e1 = 1;
let $_e2 = 2;

const $_e3 = {a1: $_e1, a2: $_e2};

/* d.js-4b186fd1d6f1579cb8d1e2d8b3961ffe */

function $_e4() {
  let c;
  if(true) {
    c = __fpack__.cached($_w1);
  }
  else {
    c = __fpack__.cached($_w1);
  }
  return c;
}

let $_e5 = $_e4;

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
console.log($_e2, $_e6);


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
  let cInternal2 = 300;
  return b.b1() + b.b2() + $_i1 + cInternal2;
}

function $_i4() {
  let b = __fpack__.cached($_w2);
  return b.default.b1() + b.default.b2() + $_i2;
}

function $_i5() {
  ({cInternal1: $_i1, cInternal2: $_i2} = {cInternal1: $_i2, cInternal2: $_i1});
  [$_i1, $_i2] = [1,2];
  $_i1 = null;
}

Object.assign(module.exports, {c1: $_i3, c2: $_i4, c3: $_i5});

return ({});

}

/* b.js-fbc8722aa7253184e85b898677c98268 */


function $_w2() {


function $_e9() {
  return $_e1 + 1;
}

function $_e10() {
  return $_e1 + 2;
}

export default {b1: $_e9, b2: $_e10, b3: a1};

return ({b1: $_e9, b2: $_e10});

}
