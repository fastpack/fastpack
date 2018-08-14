(function() {

/* $fp$runtime */

let $n__$fp$runtime = { id: "$fp$runtime", exports: {}};

function $i__$fp$runtime__applyDecorator(decorator, proto, property, descriptor) {
  var ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function $i__$fp$runtime__decorateProperty(cls, property, decorators) {
  var proto = cls.prototype;
  var descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;
      i < l;
      i++) {
    descriptor = $i__$fp$runtime__applyDecorator(reversed[i], proto, property, descriptor);
  }

  Object.defineProperty(proto, property, descriptor);
}

$n__$fp$runtime.exports = {
  omitProps: function(target, props) {
    var ret = {};
    for(var prop in target) {
      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {
        ret[prop] = target[prop];
      }
    }
    return ret;
  },

  defineClass: function(cls, statics, classDecorators, propertyDecorators) {
    for(var i = 0, l = propertyDecorators.length; i < l; i++) {
      $i__$fp$runtime__decorateProperty(cls,
                       propertyDecorators[i].method,
                       propertyDecorators[i].decorators);
    }

    for(var i = 0, l = statics.length; i < l; i++) {
      Object.defineProperty(cls, statics[i].name, {
        configurable: true,
        enumerable: true,
        writable: true,
        value: statics[i].value
      })
    }

    var _cls = cls;
    classDecorators = classDecorators.reverse();
    for(var i = 0; i < classDecorators.length; i++) {
      _cls = classDecorators[i](_cls);
    }
    return _cls;
  }
};

try{$n__$fp$runtime.exports.__esModule = $n__$fp$runtime.exports.__esModule || false;}catch(_){}

/* builtin$$B$$transpile$$_$$class */

let $n__builtin$$B$$transpile$$_$$class = { id: "builtin$$B$$transpile$$_$$class", exports: {}};
const $i__builtin$$B$$transpile$$_$$class__$__fpack__ = ($n__$fp$runtime.exports);
/* nothing to transform */
class $i__builtin$$B$$transpile$$_$$class__CC {
  method1() {
    
  }
  
  constructor() {
    
  }
  
  method2() {
    
  }
  
}/* no costructor */
class $i__builtin$$B$$transpile$$_$$class__C {
  constructor( ...args) {
    Object.defineProperty(this, "state", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
    
  }
  
}/* constructor */
class $i__builtin$$B$$transpile$$_$$class__C1 {
  constructor() {
    Object.defineProperty(this, "x", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
    Object.defineProperty(this, "y", {"configurable": true, "enumerable": true, "writable": true, "value": 2});
    this.z = this.x + this.y;
    
  }
  
}/* constructor & super */
class $i__builtin$$B$$transpile$$_$$class__C2 extends $i__builtin$$B$$transpile$$_$$class__C1 {
  method() {
    
  }
  
  constructor() {
    debugger;
    super();
    Object.defineProperty(this, "onClick", {"configurable": true, "enumerable": true, "writable": true, "value": e => {
      console.log('hello');
      
    }
    });
    Object.defineProperty(this, "onMouseMove", {"configurable": true, "enumerable": true, "writable": true, "value": e => {
      console.log(e);
      
    }
    });
    Object.defineProperty(this, "doSomethingUseful", {"configurable": true, "enumerable": true, "writable": true, "value": () => 42});
    this.onClick();
    
  }
  
}/* class decorators */
let $i__builtin$$B$$transpile$$_$$class__C3 = $i__builtin$$B$$transpile$$_$$class__$__fpack__.defineClass(class C3 {
    
  }, [], [c => c, dec], []);
/* method decorators */
let $i__builtin$$B$$transpile$$_$$class__C4 = $i__builtin$$B$$transpile$$_$$class__$__fpack__.defineClass(class C4 {
    method1() {
      
    }
    
    method2() {
      
    }
    
  }, [], [], [{"method": "method1", "decorators": [dec]}, {"method": "method2", "decorators": [m => m, dec2]}]);
/* class expressions */
(class  {
  constructor( ...args) {
    Object.defineProperty(this, "prop1", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
    
  }
  
});
let $i__builtin$$B$$transpile$$_$$class__C5 = $i__builtin$$B$$transpile$$_$$class__$__fpack__.defineClass(class  {
    constructor( ...args) {
      Object.defineProperty(this, "prop1", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
      
    }
    
  }, [{"name": "prop2", "value": void 0}], [], []);
/* all of the above */
let $i__builtin$$B$$transpile$$_$$class__C6 = $i__builtin$$B$$transpile$$_$$class__$__fpack__.defineClass(class C6 extends $i__builtin$$B$$transpile$$_$$class__C5 {
    method1() {
      
    }
    
    methodDecorated2() {
      
    }
    
    constructor() {
      before_super1();
      before_super2();
      super();
      Object.defineProperty(this, "prop_no_value", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
      Object.defineProperty(this, "prop_int", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
      Object.defineProperty(this, "prop_func", {"configurable": true, "enumerable": true, "writable": true, "value": x => x + 1});
      after_super_and_props();
      
    }
    
    methodDecorated3() {
      
    }
    
  }, [{"name": "static_prop", "value": void 0}], [cls, cls => cls], [{"method": "methodDecorated2", "decorators": [m => m]}, {"method": "methodDecorated3", "decorators": [mDec1, mDec2]}]);
/* constructor & super with arguments */
class $i__builtin$$B$$transpile$$_$$class__MyComponent extends Component {
  constructor( ...args) {
    super(...args);
    Object.defineProperty(this, "state", {"configurable": true, "enumerable": true, "writable": true, "value": {content: this.props.content}});
    
  }
  
}
try{$n__builtin$$B$$transpile$$_$$class.exports.__esModule = $n__builtin$$B$$transpile$$_$$class.exports.__esModule || false;}catch(_){}

/* builtin$$B$$transpile$$_$$object$$_$$spread */

let $n__builtin$$B$$transpile$$_$$object$$_$$spread = { id: "builtin$$B$$transpile$$_$$object$$_$$spread", exports: {}};
const $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__ = ($n__$fp$runtime.exports);
/*
 * *********************** Object Spread Expressions ***********************
 */
/* Own */
({x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x, y: $i__builtin$$B$$transpile$$_$$object$$_$$spread__y, a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__a, b: $i__builtin$$B$$transpile$$_$$object$$_$$spread__b, c: "test"});
Object.assign({}, {x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__y, {a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__a}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__b, {c: $i__builtin$$B$$transpile$$_$$object$$_$$spread__c, inner: Object.assign({}, {some: some}, rest)});
/* Babel */
Object.assign({}, {x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__y, {a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__a}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__b, {c: $i__builtin$$B$$transpile$$_$$object$$_$$spread__c});
$i__builtin$$B$$transpile$$_$$object$$_$$spread__z = Object.assign({}, {x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__y);
$i__builtin$$B$$transpile$$_$$object$$_$$spread__z = {x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x, w: Object.assign({}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__y)};
var z = Object.assign({}, $i__builtin$$B$$transpile$$_$$object$$_$$spread__x);
/*
 * *********************** Variable Assignment ***********************
 */
/* Babel */
var z = {};
var x = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__1 = {a: 1},
  a = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__1, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__2 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__a.b,
  x = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__2, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__3 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__a(),
  x = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__3, []);
var {x1} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__z,
  y1 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, ["x1"]);
$i__builtin$$B$$transpile$$_$$object$$_$$spread__x1++;
var {[a]: b} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__z,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, [$i__builtin$$B$$transpile$$_$$object$$_$$spread__a]);
var {x1: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x1} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__z,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__y1 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, ["x1"]);
let {x2: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x2, y2: $i__builtin$$B$$transpile$$_$$object$$_$$spread__y2} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__z,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__z2 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, ["x2", "y2"]);
const {w3: $i__builtin$$B$$transpile$$_$$object$$_$$spread__w3, x3: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x3, y3: $i__builtin$$B$$transpile$$_$$object$$_$$spread__y3} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__z,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__z4 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, ["w3", "x3", "y3"]);
let {x: {a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__xa, [d]: $i__builtin$$B$$transpile$$_$$object$$_$$spread__f}} = complex,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__asdf = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(complex.x, ["a", $i__builtin$$B$$transpile$$_$$object$$_$$spread__d]),
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__d = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(complex.y, []),
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__g = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(complex, ["x", "y"]);
let $i__builtin$$B$$transpile$$_$$object$$_$$spread__y4 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z.x4, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__4 = {z: 1},
  {z: $i__builtin$$B$$transpile$$_$$object$$_$$spread__z} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__4, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__5 = {x: 1},
  {x = 5} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__5, []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__6 = [1, {y: 100, z: 1, zz: 10}],
  [x, {y}] = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__6,
  p = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__6[1], ["y"]);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__7 = [1, {y: 100, z: 1, zz: 10}],
  [x, ] = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__7,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__p = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__7[1], []);
var {outer: {inner: {three: $i__builtin$$B$$transpile$$_$$object$$_$$spread__three}}} = defunct,
  other = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(defunct.outer.inner, ["three"]);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread__test = {foo: {bar: {baz: {a: {x: 1, y: 2, z: 3}}}}};
var {foo: {bar: {baz: {a: {x}}}}} = $i__builtin$$B$$transpile$$_$$object$$_$$spread__test,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__other = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__test.foo.bar.baz.a, ["x"]);
/* Own */
// Produce tmp_name for the expression
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__8 = {a: 1, b: 2, c: 3},
  {a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__a} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__8,
  b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__8, ["a"]);
// Drop pattern entirely
var $i__builtin$$B$$transpile$$_$$object$$_$$spread__xx = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z.x, []),
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__yy = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z.y, []),
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__zz = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread__z, ["x", "y"]);
// Make sure to transpile inside the expression using the same scope
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__10 = (function () {
    let __fpack__9 = {a: 1, b: 2, c: 3},
      {a} = __fpack__9,
      b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__9, ["a"]);
    return b;
    
  }
  )(),
  x = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__10, []);
// Computed property handling
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__11 = {a: {b: 2, c: 3}},
  $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__12 = (function () {
    return "a";
    
  }
  )(),
  b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__11[$i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__12], []);
var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__13 = {a: {b: 2, c: 3}},
  $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__14 = (function () {
    return "a";
    
  }
  )(),
  {[__fpack__14]: {b: $i__builtin$$B$$transpile$$_$$object$$_$$spread__b}} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__13,
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__cc = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__13[$i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__14], ["b"]);
/*
 * *********************** Assignment Expressions ***********************
 */
/* Babel */
({a1: a1} = c1);
(() => {
  ({a2: a2} = c2);
  b2 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(c2, ["a2"]);
  return c2;
  
}
)();
console.log((() => {
  ({a3: a3} = c3);
  b3 = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(c3, ["a3"]);
  return c3;
  
}
)());
/* Own  - Babel fails on this */
console.log((() => {
  let __fpack__15 = {a: 1, b: 2, c: {x: 1}},
    __fpack__16 = "c" + "";
  ({a: $i__builtin$$B$$transpile$$_$$object$$_$$spread__a} = __fpack__15);
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__xx = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__15[__fpack__16], []);
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__15, ["a", __fpack__16]);
  return __fpack__15;
  
}
)());
/*
 * *********************** Functions ***********************
 */
/* Own */
function $i__builtin$$B$$transpile$$_$$object$$_$$spread__ff(__fpack__17) {
  let a = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__17, []);
  
}
let $i__builtin$$B$$transpile$$_$$object$$_$$spread__f1 = function (__fpack__18) {
    let b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__18, []);
    
  }
  ;
let $i__builtin$$B$$transpile$$_$$object$$_$$spread__f2 = __fpack__19 => {
    let c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__19, []);
    return c;
    
  }
  ;
let $i__builtin$$B$$transpile$$_$$object$$_$$spread__f3 = __fpack__20 => {
    let c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__20, []);
    return c;
    
  }
  ;
// many parameters
function $i__builtin$$B$$transpile$$_$$object$$_$$spread__f5(a, __fpack__21, __fpack__22) {
  let c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__21.b, []),
    g = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__22.d.e.f, []);
  
}
let $i__builtin$$B$$transpile$$_$$object$$_$$spread__f6 = (__fpack__23, c, __fpack__24) => {
    let {a} = __fpack__23,
      b = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__23, ["a"]),
      f = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__24.d.e, []);
    return {};
    
  }
  ;
// could rest pattern be a part of the rest element at all?
function $i__builtin$$B$$transpile$$_$$object$$_$$spread__f7(a, ...b) {
  
}
function $i__builtin$$B$$transpile$$_$$object$$_$$spread__f8(a, ...__fpack__25) {
  let {b} = __fpack__25,
    c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__25, ["b"]);
  
}
function $i__builtin$$B$$transpile$$_$$object$$_$$spread__f9(a, __fpack__26, ...__fpack__27) {
  let c = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__26.b, []),
    d = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__27, []);
  
}
// basic for loop
for ($i__builtin$$B$$transpile$$_$$object$$_$$spread__p = (() => {
  let __fpack__28 = {x: 1, a: 2};
  ({x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x} = __fpack__28);
  $i__builtin$$B$$transpile$$_$$object$$_$$spread__y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__28, ["x"]);
  return __fpack__28;
  
}
)(); false; )
  {
    
  }
for (var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__29 = {x: 1, a: 2}, {x: $i__builtin$$B$$transpile$$_$$object$$_$$spread__x} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__29, $i__builtin$$B$$transpile$$_$$object$$_$$spread__y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__29, ["x"]); false; )
  {
    
  }
// for in
for (let __fpack__30 in iterator)
  {
    let {x} = __fpack__30,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__30, ["x"]);
    
  }
for (var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__31 in iterator)
  {
    let {x} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__31,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__31, ["x"]);
    
  }
for (let __fpack__32 in iterator)
  {
    let {x} = __fpack__32,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__32, ["x"]);
    console.log(x);
    
  }
for (var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__33 in iterator)
  {
    let {x} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__33,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__33, ["x"]);
    console.log(x);
    
  }
// for of
for (let __fpack__34 of iterator)
  {
    let {x} = __fpack__34,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__34, ["x"]);
    
  }
for (var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__35 of iterator)
  {
    let {x} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__35,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__35, ["x"]);
    
  }
for (let __fpack__36 of iterator)
  {
    let {x} = __fpack__36,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__36, ["x"]);
    console.log(x);
    
  }
for (var $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__37 of iterator)
  {
    let {x} = $i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__37,
      y = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps($i__builtin$$B$$transpile$$_$$object$$_$$spread____fpack__37, ["x"]);
    console.log(x);
    
  }
// try
try {
  throw {x: 1, y: 2, z: 3};
  
} catch (__fpack__38) {
  let {x} = __fpack__38,
    rest = $i__builtin$$B$$transpile$$_$$object$$_$$spread__$__fpack__.omitProps(__fpack__38, ["x"]);
  console.log(x, rest);
  
}

try{$n__builtin$$B$$transpile$$_$$object$$_$$spread.exports.__esModule = $n__builtin$$B$$transpile$$_$$object$$_$$spread.exports.__esModule || false;}catch(_){}

/* $fp$empty */

let $n__$fp$empty = { id: "$fp$empty", exports: {}};
$n__$fp$empty.exports = {};
try{$n__$fp$empty.exports.__esModule = $n__$fp$empty.exports.__esModule || false;}catch(_){}

/* builtin$$B$$transpile$$_$$react$$_$$jsx */

let $n__builtin$$B$$transpile$$_$$react$$_$$jsx = { id: "builtin$$B$$transpile$$_$$react$$_$$jsx", exports: {}};

$n__$fp$empty.exports.createElement("div", null);
$n__$fp$empty.exports.createElement("div", {"className": "x"});
$n__$fp$empty.exports.createElement("div", {"className": "x", "y": 1});
$n__$fp$empty.exports.createElement("div", Object.assign({}, props));
$n__$fp$empty.exports.createElement("div", Object.assign({}, {"className": "x"}, props));
$n__$fp$empty.exports.createElement("div", Object.assign({}, {"className": "x"}, props, {"width": 100}));
$n__$fp$empty.exports.createElement("div", null, 'some');
$n__$fp$empty.exports.createElement("div", null, ' some ');
$n__$fp$empty.exports.createElement("div", null, some);
$n__$fp$empty.exports.createElement("div", null, 'X ', some);
$n__$fp$empty.exports.createElement("div", null, 'X ', some, ' Y');
$n__$fp$empty.exports.createElement("div", null, ' X ', some, ' Y ');
$n__$fp$empty.exports.createElement("div", null, '  X ', some, ' Y');
$n__$fp$empty.exports.createElement($n__$fp$empty.exports.Fragment, null, 'some thing');
$n__$fp$empty.exports.createElement($n__$fp$empty.exports.Fragment, null, $n__$fp$empty.exports.createElement("div", null), $n__$fp$empty.exports.createElement("a", null));
$n__$fp$empty.exports.createElement($n__$fp$empty.exports.Fragment, null, $n__$fp$empty.exports.createElement("div", null), $n__$fp$empty.exports.createElement("a", null));
$n__$fp$empty.exports.createElement("div", null, $n__$fp$empty.exports.createElement($n__$fp$empty.exports.Fragment, null, 'oops'));
$n__$fp$empty.exports.createElement("div", null, $n__$fp$empty.exports.createElement($n__$fp$empty.exports.Fragment, null, $n__$fp$empty.exports.createElement("div", null), $n__$fp$empty.exports.createElement("div", null)));
const $i__builtin$$B$$transpile$$_$$react$$_$$jsx__App = ({components}) => $n__$fp$empty.exports.createElement("div", null, components.map((Comp, i) => $n__$fp$empty.exports.createElement("div", {"key": i}, $n__$fp$empty.exports.createElement(Comp, null))));
$n__$fp$empty.exports.createElement(X, {"component": true ? $n__$fp$empty.exports.createElement(Comp1, null) : $n__$fp$empty.exports.createElement(Comp2, null)});
$n__$fp$empty.exports.createElement(X, null);
/*
<div></div>
*/

try{$n__builtin$$B$$transpile$$_$$react$$_$$jsx.exports.__esModule = $n__builtin$$B$$transpile$$_$$react$$_$$jsx.exports.__esModule || true;}catch(_){}

/* builtin$$B$$transpile$$_$$strip$$_$$flow */

let $n__builtin$$B$$transpile$$_$$strip$$_$$flow = { id: "builtin$$B$$transpile$$_$$strip$$_$$flow", exports: {}};
const $i__builtin$$B$$transpile$$_$$strip$$_$$flow__$__fpack__ = ($n__$fp$runtime.exports);
/* Babel: default parameters */
function foo(numVal) {
  
}
function foo(numVal = 2) {
  
}
function foo(numVal) {
  
}
function foo(numVal) {
  
}
function foo(numVal = 2) {
  
}
function foo(numVal = 2) {
  
}
/* Babel: strip-type-casts */
(xxx);
({xxx: 0, yyy: "hey"});
(xxx => xxx + 1);
(xxx, yyy);
/* Babel:  def-site-variance */
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__C1 {
  
}function $i__builtin$$B$$transpile$$_$$strip$$_$$flow__f() {
  
}
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__C2 {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__C3 {
  
}/* Babel: strip-call-properties */
var a;
var a;
var a;
var a;
/* Babel: strip-array-types */
var a;
var a;
var a;
var a;
var a;
var a;
/* Babel: strip-declare-exports */
/* Babel: strip-declare-module */
/* Babel: strip-declare-statements */
/* Babel: strip-interfaces-module-and-script */
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo2 extends Bar {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo3 extends class Bar {
  
} {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo4 extends class Bar {
  
} {
  
}/* Babel: strip-qualified-generic-type */
var a;
var a;
var a;
var a;
/* Babel: strip-string-literal-types */
function createElement(tagName) {
  
}
function $i__builtin$$B$$transpile$$_$$strip$$_$$flow__createElement(tagName) {
  
}
/* Babel: strip-tuples */
var a = [];
var a = [$i__builtin$$B$$transpile$$_$$strip$$_$$flow__foo];
var a = [123];
var a = [123, "duck"];
/* Babel: strip-type-alias*/
/* Babel: strip-type-annotations */
function foo(numVal) {
  
}
function foo(numVal) {
  
}
function foo(numVal, strVal) {
  
}
function foo(numVal, untypedVal) {
  
}
function foo(untypedVal, numVal) {
  
}
function foo(nullableNum) {
  
}
function foo(callback) {
  
}
function foo(callback) {
  
}
function foo(callback) {
  
}
function foo(callback) {
  
}
function foo(callback) {
  
}
function foo() {
  
}
function foo() {
  
}
function foo() {
  
}
function foo() {
  
}
function foo() {
  
}
function foo() {
  
}
function foo() {
  
}
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = function () {
  
}
;
// TODO: bug in printer - check printer for the next 3 tests
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {set fooProp(value) {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {set fooProp(value) {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {get fooProp() {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {id(x) {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {*id(x) {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {async id(x) {
  
}
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = {123(x) {
  
}
};
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo11 {
  set fooProp(value) {
    
  }
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo22 {
  set fooProp(value) {
    
  }
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo33 {
  get fooProp() {
    
  }
  
}var $i__builtin$$B$$transpile$$_$$strip$$_$$flow__numVal = otherNumVal;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a;
var a = [1, 2, 3];
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = class Foo {
  
};
$i__builtin$$B$$transpile$$_$$strip$$_$$flow__a = class Foo extends Bar {
  
};
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo44 {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo5 extends Bar {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo6 extends mixin(Bar) {
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo7 {
  bar() {
    return 42;
    
  }
  
}class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo8 {
  "bar"() {
    
  }
  
}function foo(requiredParam, optParam) {
  
}
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo9 {
  
}let $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Foo10 = $i__builtin$$B$$transpile$$_$$strip$$_$$flow__$__fpack__.defineClass(class Foo10 {
    
  }, [{"name": "prop1", "value": void 0}], [], []);
var x = 4;
class $i__builtin$$B$$transpile$$_$$strip$$_$$flow__Array {
  concat(items) {
    
  }
  
}var x = fn;
var x = Y;
var x = Y;
var {x} = {x: "hello"};
var {x} = {x: "hello"};
var [$e__builtin$$B$$transpile$$_$$strip$$_$$flow__x] = ["hello"];
function foo({x}) {
  
}
function foo([x]) {
  
}
function $i__builtin$$B$$transpile$$_$$strip$$_$$flow__foo( ...rest) {
  
}
(function ( ...rest) {
  
}
);
(( ...rest) => rest);
var a;
var a;
var a;
var a;
var a;
var $i__builtin$$B$$transpile$$_$$strip$$_$$flow__a;
var identity;
var $i__builtin$$B$$transpile$$_$$strip$$_$$flow__identity;






function $e__builtin$$B$$transpile$$_$$strip$$_$$flow__getIteratorFn(maybeIterable) {
  return null;
  
}
;

try{$n__builtin$$B$$transpile$$_$$strip$$_$$flow.exports.getIteratorFn = $e__builtin$$B$$transpile$$_$$strip$$_$$flow__getIteratorFn;
$n__builtin$$B$$transpile$$_$$strip$$_$$flow.exports.x = $e__builtin$$B$$transpile$$_$$strip$$_$$flow__x;
$n__builtin$$B$$transpile$$_$$strip$$_$$flow.exports.__esModule = $n__builtin$$B$$transpile$$_$$strip$$_$$flow.exports.__esModule || true;}catch(_){}

/* builtin$$B$$index */

let $n__builtin$$B$$index = { id: "builtin$$B$$index", exports: {}};
// @flow


// import './transpile-optional-chaining.js'


// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const $i__builtin$$B$$index__Component = props => React.createElement("div", null, item => {
    
  }
  );

try{$n__builtin$$B$$index.exports.__esModule = $n__builtin$$B$$index.exports.__esModule || true;}catch(_){}

/* $fp$main */

let $n__$fp$main = { id: "$fp$main", exports: {}};


try{$n__$fp$main.exports.__esModule = $n__$fp$main.exports.__esModule || true;}catch(_){}
})()
