(function() {
var __fastpack_cache__ = {};

function __fastpack_import__(f) {
  if (!window.Promise) {
    throw 'window.Promise is undefined, consider using a polyfill';
  }
  return new Promise(function(resolve, reject) {
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

let $n__a = { id: "a", exports: {}};

let $e__a__a1 = 1;
let $e__a__a2 = 2;

try{$n__a.exports.a1 = $e__a__a1;
$n__a.exports.a2 = $e__a__a2;
$n__a.exports.__esModule = $n__a.exports.__esModule || true;}catch(_){}

/* d */

let $n__d = { id: "d", exports: {}};
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

try{$n__d.exports.d1 = $e__d__d1;
$n__d.exports.d2 = $e__d__d2;
$n__d.exports.__esModule = $n__d.exports.__esModule || true;}catch(_){}

/* default_declaration */

let $n__default_declaration = { id: "default_declaration", exports: {}};
function $i__default_declaration__f(x) {};const $e__default_declaration__default = $i__default_declaration__f;;
function $e__default_declaration__g() {return $i__default_declaration__f(1)}

try{$n__default_declaration.exports.default = $i__default_declaration__f;
$n__default_declaration.exports.g = $e__default_declaration__g;
$n__default_declaration.exports.__esModule = $n__default_declaration.exports.__esModule || true;}catch(_){}

/* index */

let $n__index = { id: "index", exports: {}};




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

try{$n__index.exports.__esModule = $n__index.exports.__esModule || true;}catch(_){}

/* $fp$main */

let $n__$fp$main = { id: "$fp$main", exports: {}};


try{$n__$fp$main.exports.__esModule = $n__$fp$main.exports.__esModule || true;}catch(_){}

function $w__c() {

/* b */

let $n__b = { id: "b", exports: {}};


function $e__b__b1() {
  return $e__a__a1 + 1;
}

function $e__b__b2() {
  return $e__a__a1 + 2;
}

const $e__b__default = {b1: $e__b__b1, b2: $e__b__b2, b3: $e__a__a1};

try{$n__b.exports.b1 = $e__b__b1;
$n__b.exports.b2 = $e__b__b2;
$n__b.exports.default = $e__b__default;
$n__b.exports.__esModule = $n__b.exports.__esModule || true;}catch(_){}

/* c */

let $n__c = { id: "c", exports: {}};

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

try{$n__c.exports.__esModule = $n__c.exports.__esModule || false;}catch(_){}

return $n__c.exports;
}

function $w__e() {

/* e */

let $n__e = { id: "e", exports: {}};
console.log('"e" is imported');

try{$n__e.exports.__esModule = $n__e.exports.__esModule || false;}catch(_){}

return $n__e.exports;
}
})()
