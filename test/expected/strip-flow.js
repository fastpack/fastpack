// Initial check of the interoperability with the Spread module
function foo($$fpack_1) {let {a}  = $$fpack_1, b = $fpack.removeProps($$fpack_1, ["a"]); }

/* Babel: default parameters */
function foo(numVal) {}
function foo(numVal = 2) {}
function foo(numVal) {}
function foo(numVal) {}
function foo(numVal = 2) {}
function foo(numVal = 2) {}

/* Babel */
