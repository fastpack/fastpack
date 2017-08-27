/* Babel: default parameters */
function foo(numVal?) {}
function foo(numVal? = 2) {}
function foo(numVal: number) {}
function foo(numVal?: number) {}
function foo(numVal: number = 2) {}
function foo(numVal?: number = 2) {}

/* Babel: strip-type-casts */
(xxx: number);
({ xxx: 0, yyy: "hey" }: { xxx: number; yyy: string });
(xxx => xxx + 1: (xxx: number) => number);
((xxx: number), (yyy: string));

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
class C2 { +p: T }
class C3 { -p: T }

/* Babel: strip-call-properties */
var a: { (): number };
var a: { (): number; };
var a: { (): number; y: string; (x: string): string };
var a: { <T>(x: T): number; };
interface A { (): number; }

/* Babel: strip-array-types */
var a: number[];
var a: ?number[];
var a: (?number)[];
var a: () => number[];
var a: (() => number)[];
var a: typeof A[];

/* Babel: strip-declare-exports */
declare export var foo
declare export var foo;
declare export function foo(): void
declare export function foo(): void;
declare export function foo<T>(): void;
declare export function foo(x: number, y: string): void;
declare export class A {}
declare export class A<T> extends B<T> { x: number }
declare export class A { static foo(): number; static x : string }
declare export class A { static [ indexer: number]: string }
declare export class A { static () : number }
declare export class A mixins B<T>, C {}
declare export default class A {}
declare export default function foo(): void;
declare export default string

/* Babel: strip-declare-module */
declare module A {}
declare module "./a/b.js" {}
declare module A { declare var x: number; }
declare module A { declare function foo(): number; }
declare module A { declare class B { foo(): number; } }

/* Babel: strip-declare-statements */
declare var foo
declare var foo;
declare function foo(): void
declare function foo(): void;
declare function foo<T>(): void;
declare function foo(x: number, y: string): void;
declare class A {}
declare class A<T> extends B<T> { x: number }
declare class A { static foo(): number; static x : string }
declare class A { static [ indexer: number]: string }
declare class A { static () : number }
declare class A mixins B<T>, C {}
declare type A = string
declare type T<U> = { [k:string]: U }
declare interface I { foo: string }
declare interface I<T> { foo: T }
declare module.exports: string;

/* Babel: strip-interfaces-module-and-script */
interface A {}
interface A extends B {}
interface A<T> extends B<T>, C<T> {}
interface A { foo: () => number; }
interface Dictionary { [index: string]: string; length: number; }
class Foo implements Bar {}
class Foo2 extends Bar implements Bat, Man<number> {}
class Foo3 extends class Bar implements Bat {} {}
class Foo4 extends class Bar implements Bat {} implements Man {}

/* Babel: strip-qualified-generic-type */
var a: A.B;
var a: A.B.C;
var a: A.B<T>;
var a: typeof A.B<T>;

/* Babel: strip-string-literal-types */
function createElement(tagName: "div"): HTMLDivElement {}
function createElement(tagName: 'div'): HTMLDivElement {}

/* Babel: strip-tuples */
var a: [] = [];
var a: [Foo<T>] = [foo];
var a: [number,] = [123,];
var a: [number, string] = [123, "duck"];

/* Babel: strip-type-alias*/
type FBID = number;
type Foo<T> = Bar<T>
export type Foo = number;

type union =
 | {type: "A"}
 | {type: "B"}
;

type overloads =
  & ((x: string) => number)
  & ((x: number) => string)
;

/* Babel: strip-type-annotations */
function foo(numVal: any) {}
function foo(numVal: number) {}
function foo(numVal: number, strVal: string) {}
function foo(numVal: number, untypedVal) {}
function foo(untypedVal, numVal: number) {}
function foo(nullableNum: ?number) {}
function foo(callback: () => void) {}
function foo(callback: () => number) {}
function foo(callback: (_: bool) => number) {}
function foo(callback: (_1: bool, _2: string) => number) {}
function foo(callback: (_1: bool, ...foo: Array<number>) => number) {}
function foo(): number{}
function foo():() => void {}
function foo():(_:bool) => number{}
function foo():(_?:bool) => number{}
function foo(): {} {}
function foo<T>() {}
function foo<T,S>() {}
a = function<T,S>() {};
// TODO: bug in printer - check printer for the next 3 tests
a = { set fooProp(value: number) {} };
a = { set fooProp(value: number): void {} };
a = { get fooProp():number{} };
a = { id<T>(x: T): T {} };
a = { *id<T>(x: T): T {} };
a = { async id<T>(x: T): T {} };
a = { 123<T>(x: T): T {} };
class Foo {
  set fooProp(value: number) {}
}
class Foo2 {
  set fooProp(value: number): void {}
}
class Foo3 {
  get fooProp(): number {}
}
var numVal: number = otherNumVal;
var a: { numVal: number };
var a: { numVal: number; };
var a: { numVal: number; [indexer: string]: number };
var a: ?{ numVal: number };
var a: { numVal: number; strVal: string }
var a: { subObj: {strVal: string} }
var a: { subObj: ?{strVal: string} }
var a: { param1: number; param2: string }
var a: { param1: number; param2?: string }
var a: { ...any; ...{}|{p: void} };
var a: { [a: number]: string; [b: number]: string; };
var a: { add(x: number, ...y: Array<string>): void };
var a: { id<T>(x: T): T; };
var a:Array<number> = [1, 2, 3]
a = class Foo<T> {}
a = class Foo<T> extends Bar<T> {}
class Foo4<T> {}
class Foo5<T> extends Bar<T> {}
class Foo6<T> extends mixin(Bar) {}
class Foo7<T> {
  bar<U>():number { return 42; }
}
class Foo8 {
  "bar"<T>() {}
}
function foo(requiredParam, optParam?) {}
class Foo9 {
  prop1: string;
  prop2: number;
}
class Foo10 {
  static prop1: string;
  prop2: number;
}
var x: number | string = 4;
class Array { concat(items:number | string) {}; }
var x: () => number | () => string = fn;
var x: typeof Y = Y;
var x: typeof Y | number = Y;
var {x}: {x: string; } = { x: "hello" };
var {x}: {x: string } = { x: "hello" };
var [x]: Array<string> = [ "hello" ];
function foo({x}: { x: string; }) {}
function foo([x]: Array<string>) {}
function foo(...rest: Array<number>) {}
(function (...rest: Array<number>) {});
((...rest: Array<number>) => rest);
var a: Map<string, Array<string> >
var a: Map<string, Array<string>>
var a: number[]
var a: ?string[]
var a: Promise<bool>[]
var a:(...rest:Array<number>) => number
var identity: <T>(x: T) => T
var identity: <T>(x: T, ...y:T[]) => T
import type foo4 from "bar";
import type { foo2, bar } from "baz";
import type { foo as bar2 } from "baz";
import type from "foo";
import type2, { foo3 } from "bar";
import type * as namespace from "bar";
export type { foo };
export type { foo2 } from "bar";
import {type T} from "foo";
import {type T2, V1} from "foo";
import {typeof V2} from "foo";
import {typeof V3, V4} from "foo";
export interface foo5 { p: number }
export interface foo6<T> { p: T }
import 'foo';
