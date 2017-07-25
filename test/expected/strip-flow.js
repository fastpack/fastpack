// Initial check of the interoperability with the Spread module
function foo($$fpack_1) {let {a}  = $$fpack_1, b = $fpack.removeProps($$fpack_1, ["a"]); }

/* Babel: default parameters */
function foo(numVal) {}
function foo(numVal = 2) {}
function foo(numVal) {}
function foo(numVal) {}
function foo(numVal = 2) {}
function foo(numVal = 2) {}

/* Babel:  def-site-variance */
class C1 {}
function f() {}













// following 2 tests produce wrong output - eating out the last '}'
// due to bug in flow parser. Fix them when flow parser is updated
class C2 { 
class C3 { 
