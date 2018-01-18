
(function() {
var __DEV__ = false;
var __fastpack_cache__ = {};

function __fastpack_require__(f) {
  if (__fastpack_cache__[f.name] === undefined) {
    __fastpack_cache__[f.name] = f();
  }
  return __fastpack_cache__[f.name];
}

function __fastpack_import__(f) {
  return new Promise((resolve, reject) => {
    try {
      resolve(__fastpack_require__(f));
    } catch (e) {
      reject(e);
    }
  });
}

/* prod */

let $n__prod = { exports: {}};$n__prod.exports = {prod: true};

/* index */


let $i__index__p;

// if-then-no-else
$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

{}

{}

{}

{}

// if-then-else
$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);

$i__index__p = ($n__prod.exports);


// alternative statement
$i__index__p = ($n__prod.exports);

// logical AND expression
$i__index__p = ($n__prod.exports);

// conditional operator
$i__index__p = ($n__prod.exports);
console.log("production");

// bug
if (true) {} else {console.log("prod!")}
if (false) {} else {}

const $n__index = { exports: {} };
})()
