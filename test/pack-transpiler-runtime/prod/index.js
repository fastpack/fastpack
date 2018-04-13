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

/* builtin$$B$$index */

let $n__builtin$$B$$index = { id: "builtin$$B$$index", exports: {}};
const $i__builtin$$B$$index__$__fpack__ = ($n__$fp$runtime.exports);
function $i__builtin$$B$$index__decorator1(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function () {
    let ret = oldValue.call(this);
    return `@decorator1 ${ret}`;
    
  }
  ;
  return descriptor;
  
}
function $i__builtin$$B$$index__decorator2(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function () {
    let ret = oldValue.call(this);
    return `@decorator2 ${ret}`;
    
  }
  ;
  return descriptor;
  
}
function $i__builtin$$B$$index__classDecorator1(cls) {
  cls.staticProp = `@classDecorator1 ${cls.staticProp}`;
  return cls;
  
}
function $i__builtin$$B$$index__classDecorator2(cls) {
  cls.staticProp = `@classDecorator2 ${cls.staticProp}`;
  return cls;
  
}
let $i__builtin$$B$$index__Test = $i__builtin$$B$$index__$__fpack__.defineClass(class Test {
    constructor( ...args) {
      Object.defineProperty(this, "prop", {"configurable": true, "enumerable": true, "writable": true, "value": "instance property"});
      
    }
    
    method() {
      return "method";
      
    }
    
  }, [{"name": "staticProp", "value": "class property"}], [$i__builtin$$B$$index__classDecorator2, $i__builtin$$B$$index__classDecorator1], [{"method": "method", "decorators": [$i__builtin$$B$$index__decorator2, $i__builtin$$B$$index__decorator1]}]);
let $i__builtin$$B$$index____fpack__1 = {test: new $i__builtin$$B$$index__Test(), a: 1, b: 2, c: 3},
  {test: $i__builtin$$B$$index__test} = $i__builtin$$B$$index____fpack__1,
  $i__builtin$$B$$index__rest = $i__builtin$$B$$index__$__fpack__.omitProps($i__builtin$$B$$index____fpack__1, ["test"]);
document.body.innerHTML = `
<div>Static property: <b>${$i__builtin$$B$$index__Test.staticProp}</b></div>
<div>Property: <b>${$i__builtin$$B$$index__test.prop}</b></div>
<div>method: <b>${$i__builtin$$B$$index__test.method()}</b></div>
<div>...rest: <b>${JSON.stringify($i__builtin$$B$$index__rest)}</b></div>
`;

try{$n__builtin$$B$$index.exports.__esModule = $n__builtin$$B$$index.exports.__esModule || false;}catch(_){}

/* $fp$main */

let $n__$fp$main = { id: "$fp$main", exports: {}};


try{$n__$fp$main.exports.__esModule = $n__$fp$main.exports.__esModule || true;}catch(_){}
})()
