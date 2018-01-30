(function() {
var __DEV__ = true;
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

/* dev */

let $n__dev = { exports: {}};$n__dev.exports = {dev: true};

/* prod */

let $n__prod = { exports: {}};$n__prod.exports = {prod: true};

/* index */


let $i__index__p;

// if-then-no-else
{}

{}

{}

{}

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

// if-then-else
$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);

$i__index__p = ($n__dev.exports);


// alternative statement
$i__index__p = ($n__dev.exports);

// logical AND expression
if ("development" == "production" && x && y && z)
  $i__index__p = ($n__prod.exports);
else
  $i__index__p = ($n__dev.exports);

// conditional operator
$i__index__p = ($n__dev.exports);
console.log("development");

// bug
if (true) {} else {}
if (false) {} else {console.log("dev!")}

const $n__index = { exports: {} };
})()
