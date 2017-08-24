/** bindings */
var x = 1;
let y = 2;
const z = 3;
var x = 1,
  y = 2;
let x = 1,
  y = 2;
const x = 1,
  y = 2;
var x;
let y;
let y: A;
/** binding with patterns */
var {x: x} = 12;
let {y: y} = 12;
const {z: [a]} = 12;
/** functions */
function x() {
  
};
function y(a) {
  
};
function z(a ...b) {
  
};
function a() {
  stmt
};
function b() {
  return stmt
};
function c() {
  stmt;
  return stmt
};
function with_return_type_annot(): T {
  
};
function with_arg_types(a: A): T {
  
};
function with_type_param<T>(a: A): T {
  
};
function with_type_param<T: X,Y>(a: A): T {
  
};
function with_type_param<A: T<B>>(a: A): T {
  
};
/** Types */
let x: A;
let x: number;
let x: string;
let x: boolean;
let x: "literal";
let x: 42;
let x: true,
  y: false;
let x: null,
  y: void;
let x: any;
let x: mixed;
let x: *;
let x: [A,B];
let x: typeof 12;
let x: Array<string>;
let x: Array<string>;
/* async for of */
async function a() {
  for await (var x of y)
    {
      
    }
  ;
  
};
/* class decorators */
@(function (f) { return (f); })
@(function decorator1(s) {
  return s
})
@(decorator2)
class C {
  
};
/* template literals */
let t = `test`;
t = `test ${1} test`;
t = `test ${x + y}
xxx
test ${z}`;
let tagged = Tag`xxx ${1}`;
/* class expressions */
let c = class  {
    render() {
      console.log('hello')
    }
    static prop = 1;
  };
