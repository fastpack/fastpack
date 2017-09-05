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
var {x} = 12;
let {y} = 12;
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
function with_type_param<T: X, Y>(a: A): T {
  
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
let x: [A, B];
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
@((f) =>  (f))
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
/* JSX */
let j = <Simple/>;
let j1 = <Namespace:Name/>;
let j2 = <X.Y.Z/>;
let j3 = <WithSpread
  {...props}/>;
let j4 = <WithAttrs
  x="1"
  y="2"
  expr1={cond ? "x" : 1}
  expr2={some_function()}/>;
let j5 = <WithChildren>
  text
  {expr}
  <Data
  x="1"/>
  </WithChildren>;
/* Arrow functions */
let f = (f) =>  (f);
let f1 = (x) =>  {
    x
  };
let f2 = (x) =>  ({x});
let f3 = ({x, y, z}) =>  {
    x++;
    y++;
    z++;
    return x + y + z
  };
let f4 = (x, y) =>  ({[x]: y});
/* Import expression */
let p = import("a");
let p1 = import(f());
/* Parentheses */
/* Logical & Binary precedence */
let e1 = 1 * 2 + 2 * 3;
let e2 = (1 + 2) / (2 - 3);
let e3 = true && false || true && true;
let e4 = (true || false) && (true || true);
let e5 = (true || false) + (true && false);
let e6 = 1 + 1 && 2 + 2;
/* make sure the comment doesn't break the expression */
function e7() {
  return (// xxx
  "test")
};
/* Statement.Expression with the unnamed class should be wrapped */
(class  {
  constructor() {
    
  }
});
/* never use parentheses with the spread operator */
let e8 = {...x || z};
let e9 = [1, 2, 3, ...[5, 6, 7]];
/* arrow functions are handled conservatively:
 * always inside parentheses within the expressions */
let e10 = ((x) =>  (x + 1)) + ((y) =>  (y + 1));
let e11 = ((x) =>  (x + 1)) || ((y) =>  (y + 1));
let e12 = true ? ((x) =>  (x + 1)) : ((y) =>  (y + 1));
let e13 = (x) =>  ((y) =>  (x + y));
let e14 = (x) =>  (x);
/* for cycle handled conservatively */
for ((i = 1, l = list.length);(i < l, l > 100);(i++, l--))
  {
    
  }
;
;
