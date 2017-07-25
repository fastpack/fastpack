// Initial check of the interoperability with the Spread module
function foo({a, ...b} : {a: number, b: number}) {}

/* Babel: default parameters */
function foo(numVal?) {}
function foo(numVal? = 2) {}
function foo(numVal: number) {}
function foo(numVal?: number) {}
function foo(numVal: number = 2) {}
function foo(numVal?: number = 2) {}

/* Babel:  def-site-variance */
class C1<+T, -U> {}
function f<+T, -U>() {}
type T<+T, -U> = {}
type T = { +p: T }
type T = { -p: T }
type T = { +[k:K]: V }
type T = { -[k:K]: V }
interface I { +p: T }
interface I { -p: T }
interface I { +[k:K]: V }
interface I { -[k:K]: V }
declare class I { +p: T }
declare class I { -p: T }
declare class I { +[k:K]: V }
declare class I { -[k:K]: V }
// following 2 tests produce wrong output - eating out the last '}'
// due to bug in flow parser. Fix them when flow parser is updated
class C2 { +p: T }
class C3 { -p: T }
