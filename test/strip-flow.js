// Initial check of the interoperability with the Spread module
function foo({a, ...b} : {a: number, b: number}) {}

/* Babel: default parameters */
function foo(numVal?) {}
function foo(numVal? = 2) {}
function foo(numVal: number) {}
function foo(numVal?: number) {}
function foo(numVal: number = 2) {}
function foo(numVal?: number = 2) {}

/* Babel */
