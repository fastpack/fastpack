
/* a */

let $n__a = { id: "a", exports: {}};
let $e__a__a = 1;
function $e__a__changeA() { $e__a__a = $e__a__a + 1};


try{$n__a.exports.a = $e__a__a;
$n__a.exports.changeA = $e__a__changeA;
$n__a.exports.__esModule = $n__a.exports.__esModule || true;}catch(_){}

/* index */

let $n__index = { id: "index", exports: {}};

let $e__index__index = 1;
const $e__index__default = function() {console.log('Hello, world!')};

try{$n__index.exports.a = $e__a__a;
$n__index.exports.changeA = $e__a__changeA;
$n__index.exports.default = $e__index__default;
$n__index.exports.index = $e__index__index;
$n__index.exports.__esModule = $n__index.exports.__esModule || true;}catch(_){}
module.exports = $n__index.exports;
