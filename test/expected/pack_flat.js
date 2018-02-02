(function() {
var __fastpack_cache__ = {};

function __fastpack_import__(f) {
  return new Promise((resolve, reject) => {
    try {
      if (__fastpack_cache__[f.name] === undefined) {
        __fastpack_cache__[f.name] = f();
      }
      resolve(__fastpack_cache__[f.name]);
    } catch (e) {
      reject(e);
    }
  });
}

/* a */


let $e__a__a1 = 1;
let $e__a__a2 = 2;

const $n__a = { exports: {a1: $e__a__a1, a2: $e__a__a2} };

/* d */

function $e__d__d1() {
  let c;
  if(true) {
    c = __fastpack_import__($w__c);
  }
  else {
    c = __fastpack_import__($w__c);
  }
  return c;
}

let $e__d__d2 = $e__d__d1;

const $n__d = { exports: {d1: $e__d__d1, d2: $e__d__d2} };

/* default_declaration */

function $i__default_declaration__f(x) {};const $e__default_declaration__default = $i__default_declaration__f;;
function $e__default_declaration__g() {return $i__default_declaration__f(1)}

const $n__default_declaration = { exports: {default: $i__default_declaration__f, g: $e__default_declaration__g} };

/* index */





{
  {
    __fastpack_import__($w__e);
  }
}
console.log($e__a__a2, $n__d.exports, $e__default_declaration__default, Expression);


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

const $n__index = { exports: {} };

function $w__c() {

/* b */



function $e__b__b1() {
  return $e__a__a1 + 1;
}

function $e__b__b2() {
  return $e__a__a1 + 2;
}

const $e__b__default = {b1: $e__b__b1, b2: $e__b__b2, b3: $e__a__a1};

const $n__b = { exports: {default: $e__b__default, b1: $e__b__b1, b2: $e__b__b2} };

/* c */

let $n__c = { exports: {}};
let $i__c__cInternal1 = 100;
let $i__c__cInternal2 = 200;

function $i__c__c1() {
  let b = ($n__b.exports);
  let cInternal2 = 300;
  return b.b1() + b.b2() + $i__c__cInternal1 + cInternal2;
}

function $i__c__c2() {
  let b = ($n__b.exports);
  return b.default.b1() + b.default.b2() + $i__c__cInternal2;
}

function $i__c__c3() {
  ({cInternal1: $i__c__cInternal1, cInternal2: $i__c__cInternal2} = {cInternal1: $i__c__cInternal2, cInternal2: $i__c__cInternal1});
  [$i__c__cInternal1, $i__c__cInternal2] = [1,2];
  $i__c__cInternal1 = null;
}

Object.assign($n__c.exports, {c1: $i__c__c1, c2: $i__c__c2, c3: $i__c__c3});

return $n__c.exports;
}

function $w__e() {

/* e */

console.log('"e" is imported');

const $n__e = { exports: {} };

return $n__e.exports;
}
})()
