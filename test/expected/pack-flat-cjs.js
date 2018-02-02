
/* a */

let $e__a__a = 1;
function $e__a__changeA() { $e__a__a = $e__a__a + 1};


const $n__a = { exports: {a: $e__a__a, changeA: $e__a__changeA} };

/* index */


let $e__index__index = 1;
const $e__index__default = function() {console.log('Hello, world!')};

const $n__index = { exports: {default: $e__index__default, index: $e__index__index, a: $e__a__a, changeA: $e__a__changeA} };
module.exports = $n__index.exports;
