/** bindings */

var x = 1;
let y = 2;
const z = 3;

var x = 1, y = 2;
let x = 1, y = 2;
const x = 1, y = 2;

var x;
let y;

/** binding with patterns */

var {x} = 12;
let {y} = 12;
const {z: [a]} = 12;

/** functions */

function x() {}
function y(a) {}
function z(a, ...b) {}
function a() {
	stmt;
}
function b() {
	return stmt;
}
function c() {
	stmt;
	return stmt;
}

/* async for of */
async function a() {
  for await (var x of y) {};
}

/* class decorators */
@(f => f)
@(function decorator1(s) {
  return s
})
@decorator2
class C {}

/* template literals */
let t = `test`;
t = `test ${1} test`;
t = `test ${x + y}
xxx
test ${z}`;
let tagged = Tag`xxx ${1}`;

/* class expressions */
let c = class { render() {console.log('hello');} static prop = 1;};

/* JSX */
let j = <Simple />;
let j1 = <Namespace:Name/>
let j2 = <X.Y.Z/> 
let j3 = <WithSpread {...props}/>
let j4 = <WithAttrs
  x="1"
  y="2"
  expr1={cond ? "x": 1}
  expr2={some_function()}
  />
let j5 = <WithChildren>
  text
  {expr}
  <Data x="1"/>
  </WithChildren>;

/* Arrow functions */
let f = f => f;
let f1 = x => {x};
let f2 = x => ({x});
let f3 = ({x, y, z}) => {x++; y++; z++; return x + y + z;}
let f4 = (x, y) => ({[x]: y})

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
let e6 = (1 + 1) && (2 + 2);

/* make sure the comment doesn't break the expression */
function e7() {
  return ( // xxx
    "test"
  )
}

/* never use parentheses with the spread operator */
let e8 = {... x || z };
let e9 = [1,2,3, ...[5,6,7]];

/* arrow functions are handled conservatively:
 * always inside parentheses within the expressions */

let e10 = (x => x + 1) + (y => y + 1);
let e11 = (x => x + 1) || (y => y + 1);
let e12 = true ? x => x + 1 : y => y + 1;
let e13 = x => y => x + y;
let e14 = x => x

/* for cycle handled conservatively */

for (i = 1, l = list.length; i < l, l > 100; i++, l --) {};

/*  Statement.Expression should be wrapped when the argument is:
  * - class
  * - function
  * */
(class { constructor() {}});
(function() {});
(x => x);
function e15 () {}


/* Immediately invoked functions */
(function (x) {console.log(x);return x;})(1);

/* Conditional */
Image.propTypes = process.env.NODE_ENV !== "production" ? Object.assign({}, _ViewPropTypes2.default, {
  defaultSource: ImageSourcePropType,
  draggable: _propTypes.bool,
  onError: _propTypes.func,
  onLayout: _propTypes.func,
  onLoad: _propTypes.func,
  onLoadEnd: _propTypes.func,
  onLoadStart: _propTypes.func,
  resizeMode: (0, _propTypes.oneOf)(Object.keys(_ImageResizeMode2.default)),
  source: ImageSourcePropType,
  style: (0, _StyleSheetPropType2.default)(_ImageStylePropTypes2.default),
  // compatibility with React Native
  /* eslint-disable react/sort-prop-types */
  blurRadius: _propTypes.number,
  capInsets: (0, _propTypes.shape)({ top: _propTypes.number, left: _propTypes.number, bottom: _propTypes.number, right: _propTypes.number }),
  resizeMethod: (0, _propTypes.oneOf)(['auto', 'resize', 'scale'])
  /* eslint-enable react/sort-prop-types */
}) : {};


/* Export */
export class CLS {};
export function f() {};
export var C1, C2;
export let ya = 1, yo = function() {};

export { e11, e12, e13 };
export {n1, n2 as newName, n3} from "x";
export * from "y";
export * as test from "y";

export default function F() {};

export const fff1 = x => ({"x": 1}[x]);
export const fff2 = x => ({"x": x}.x);
export const fff3 = x => ({} + {});
export const fff4 = x => ({} ? 1 : x);

var x, y;
var styles = {some: (x = 1, y = 2, {paddingLeft: 1 + 2})};
