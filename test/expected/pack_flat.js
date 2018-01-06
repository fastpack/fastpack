
/* a */


let $e__a__a1 = 1;
let $e__a__a2 = 2;

const $n__a = {a1: $e__a__a1, a2: $e__a__a2};

/* d */

function $e__d__d1() {
  let c;
  if(true) {
    c = __fpack_cached__($w__c);
  }
  else {
    c = __fpack_cached__($w__c);
  }
  return c;
}

let $e__d__d2 = $e__d__d1;

const $n__d = {d1: $e__d__d1, d2: $e__d__d2};

/* e */

console.log('"e" is imported');

const $n__e = {};

/* index */




{
  {
    ($n__e);
  }
}
console.log($e__a__a2, $n__d);


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

const $n__index = {};

/* c */


function $w__c() {
let $n__c;
let $i__c__cInternal1 = 100;
let $i__c__cInternal2 = 200;

function $i__c__c1() {
  let b = __fpack_cached__($w__b);
  let cInternal2 = 300;
  return b.b1() + b.b2() + $i__c__cInternal1 + cInternal2;
}

function $i__c__c2() {
  let b = __fpack_cached__($w__b);
  return b.default.b1() + b.default.b2() + $i__c__cInternal2;
}

function $i__c__c3() {
  ({cInternal1: $i__c__cInternal1, cInternal2: $i__c__cInternal2} = {cInternal1: $i__c__cInternal2, cInternal2: $i__c__cInternal1});
  [$i__c__cInternal1, $i__c__cInternal2] = [1,2];
  $i__c__cInternal1 = null;
}

Object.assign($n__c, {c1: $i__c__c1, c2: $i__c__c2, c3: $i__c__c3});

return $n__c;
}

/* b */


function $w__b() {


function $e__b__b1() {
  return $e__a__a1 + 1;
}

function $e__b__b2() {
  return $e__a__a1 + 2;
}

export default {b1: $e__b__b1, b2: $e__b__b2, b3: a1};

const $n__b = {b1: $e__b__b1, b2: $e__b__b2};

return $n__b;
}
