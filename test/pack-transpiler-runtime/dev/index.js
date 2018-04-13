
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(moduleId) {

    // Check if module is in cache
    if(installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    // Create a new module (and put it into the cache)
    var module = installedModules[moduleId] = {
      id: moduleId,
      l: false,
      exports: {}
    };

    // Execute the module function
    modules[moduleId].call(
      module.exports,
      module,
      module.exports,
      __fastpack_require__,
      __fastpack_import__
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(moduleId) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(moduleId));
      } catch (e) {
        reject(e);
      }
    });
  }

  __fastpack_require__.m = modules;
  __fastpack_require__.c = installedModules;
  __fastpack_require__.omitDefault = function(moduleVar) {
    var keys = Object.keys(moduleVar);
    var ret = {};
    for(var i = 0, l = keys.length; i < l; i++) {
      var key = keys[i];
      if (key !== 'default') {
        ret[key] = moduleVar[key];
      }
    }
    return ret;
  }
  return __fastpack_require__(__fastpack_require__.s = '$fp$main');
})
({
"$fp$runtime": function(module, exports, __fastpack_require__, __fastpack_import__) {

function applyDecorator(decorator, proto, property, descriptor) {
  var ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function decorateProperty(cls, property, decorators) {
  var proto = cls.prototype;
  var descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;
      i < l;
      i++) {
    descriptor = applyDecorator(reversed[i], proto, property, descriptor);
  }

  Object.defineProperty(proto, property, descriptor);
}

module.exports = {
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
      decorateProperty(cls,
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

},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $__fpack__ = __fastpack_require__(/* "$fp$runtime" */ "$fp$runtime");
function decorator1(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function () {
    let ret = oldValue.call(this);
    return `@decorator1 ${ret}`;
    
  }
  ;
  return descriptor;
  
}
function decorator2(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function () {
    let ret = oldValue.call(this);
    return `@decorator2 ${ret}`;
    
  }
  ;
  return descriptor;
  
}
function classDecorator1(cls) {
  cls.staticProp = `@classDecorator1 ${cls.staticProp}`;
  return cls;
  
}
function classDecorator2(cls) {
  cls.staticProp = `@classDecorator2 ${cls.staticProp}`;
  return cls;
  
}
let Test = $__fpack__.defineClass(class Test {
    constructor( ...args) {
      Object.defineProperty(this, "prop", {"configurable": true, "enumerable": true, "writable": true, "value": "instance property"});
      
    }
    
    method() {
      return "method";
      
    }
    
  }, [{"name": "staticProp", "value": "class property"}], [classDecorator2, classDecorator1], [{"method": "method", "decorators": [decorator2, decorator1]}]);
let __fpack__1 = {test: new Test(), a: 1, b: 2, c: 3},
  {test} = __fpack__1,
  rest = $__fpack__.omitProps(__fpack__1, ["test"]);
document.body.innerHTML = `
<div>Static property: <b>${Test.staticProp}</b></div>
<div>Property: <b>${test.prop}</b></div>
<div>method: <b>${test.method()}</b></div>
<div>...rest: <b>${JSON.stringify(rest)}</b></div>
`;

},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./index.js" */ "builtin$$B$$index");


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
