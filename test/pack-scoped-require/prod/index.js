(function() {

/* dep */

let $n__dep = { id: "dep", exports: {}};
const $e__dep__default = "dep.js";

try{$n__dep.exports.default = $e__dep__default;
$n__dep.exports.__esModule = $n__dep.exports.__esModule || true;}catch(_){}

/* index */

let $n__index = { id: "index", exports: {}};
var $i__index__dep = ($n__dep.exports);

function $i__index__f(require) {
  return require("./dep");
}

function $i__index__g() {
  var s = $i__index__f(x => x);
  var dep2 = ($n__dep.exports);
  document.body.innerHTML = `Imported: ${$i__index__dep.default} Imported: ${
    dep2.default
  } Untouched: ${s}`;
}

$i__index__g();

try{$n__index.exports.__esModule = $n__index.exports.__esModule || false;}catch(_){}

/* fp$main */

let $n__fp$main = { id: "fp$main", exports: {}};


try{$n__fp$main.exports.__esModule = $n__fp$main.exports.__esModule || true;}catch(_){}
})()
