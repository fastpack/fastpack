
/* a */


let $e$__a__a1 = 1;
let $e$__a__a2 = 2;

const $e$__a__$$NAMESPACE$$ = {a1: $e$__a__a1, a2: $e$__a__a2};

/* d */

function $e$__d__d1() {
  let c;
  if(true) {
    c = __fpack__.cached($_w1);
  }
  else {
    c = __fpack__.cached($_w1);
  }
  return c;
}

let $e$__d__d2 = $e$__d__d1;

const $e$__d__$$NAMESPACE$$ = {d1: $e$__d__d1, d2: $e$__d__d2};

/* e */

console.log('"e" is imported');

const $e$__e__$$NAMESPACE$$ = {};

/* index */




{
  {
    ($e$__e__$$NAMESPACE$$);
  }
}
console.log($e$__a__a2, $e$__d__$$NAMESPACE$$);


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

const $e$__index__$$NAMESPACE$$ = {};

/* c */


function $_w1() {

let $i$__c__cInternal1 = 100;
let $i$__c__cInternal2 = 200;

function $i$__c__c1() {
  let b = __fpack__.cached($_w2);
  let cInternal2 = 300;
  return b.b1() + b.b2() + $i$__c__cInternal1 + cInternal2;
}

function $i$__c__c2() {
  let b = __fpack__.cached($_w2);
  return b.default.b1() + b.default.b2() + $i$__c__cInternal2;
}

function $i$__c__c3() {
  ({cInternal1: $i$__c__cInternal1, cInternal2: $i$__c__cInternal2} = {cInternal1: $i$__c__cInternal2, cInternal2: $i$__c__cInternal1});
  [$i$__c__cInternal1, $i$__c__cInternal2] = [1,2];
  $i$__c__cInternal1 = null;
}

Object.assign(module.exports, {c1: $i$__c__c1, c2: $i$__c__c2, c3: $i$__c__c3});

const $e$__c__$$NAMESPACE$$ = {};

}

/* b */


function $_w2() {


function $e$__b__b1() {
  return $e$__a__a1 + 1;
}

function $e$__b__b2() {
  return $e$__a__a1 + 2;
}

export default {b1: $e$__b__b1, b2: $e$__b__b2, b3: a1};

const $e$__b__$$NAMESPACE$$ = {b1: $e$__b__b1, b2: $e$__b__b2};

}
