
/* a.js-fb1192555b4afa97f8bf590f5331902d */


export let a1 = 1;
export let a2 = 2;

/* d.js-4b186fd1d6f1579cb8d1e2d8b3961ffe */

export function d1() {
  let c;
  if(true) {
    c = __fpack_cache__("$_e2", $_e2);
  }
  else {
    c = __fpack_cache__("$_e2", $_e2);
  }
  return c;
}

export let d2 = d1;

/* e.js-53755ac792d422954b7b38d32fb8e8f6 */

console.log('"e" is imported');

/* index.js-c46c4e9e002d45c71aaf635189f80e19 */

/* static */ import {a1, a2} from './a';
/* static */ import {d1, d2} from './d';

{
  {
    /* static */ import('./e');
  }
}


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

/* c.js-d61468bee36ba5f51f6f73437a95ba4a */


function $_e2() {

let cInternal1 = 100;
let cInternal2 = 200;

function c1() {
  let b = __fpack_cache__("$_e4", $_e4);
  return b.b1() + b.b2() + cInternal1;
}

function c2() {
  let b = __fpack_cache__("$_e4", $_e4);
  return b.default.b1() + b.default.b2() + cInternal2;
}

Object.assign(module.exports, {c1, c2});
}


/* b.js-fbc8722aa7253184e85b898677c98268 */


function $_e4() {
/* static */ import {a1 as a} from './a';

export function b1() {
  return a + 1;
}

export function b2() {
  return a + 2;
}

export default {b1, b2, b3: a1};
}

