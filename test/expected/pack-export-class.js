
// This function is a modified version of the one created by the Webpack project
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

  // expose the modules object
  __fastpack_require__.m = modules;

  // expose the module cache
  __fastpack_require__.c = installedModules;

  return __fastpack_require__(__fastpack_require__.s = 'builtin$$B$$index');
})
({
"builtin$$COLON$$__fastpack_runtime__": function(module, exports, __fastpack_require__, __fastpack_import__) {

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
"builtin$$B$$ExportDefaultNamedClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $__fpack__ = __fastpack_require__(/* "__fastpack_runtime__" */ "builtin$$COLON$$__fastpack_runtime__");
let C = $__fpack__.defineClass(class C {
    
  }, [{"name": "prop", "value": 'ExportDefaultNamedClass'}], [], []);
exports.default = C;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"builtin$$B$$ExportDefaultClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $__fpack__ = __fastpack_require__(/* "__fastpack_runtime__" */ "builtin$$COLON$$__fastpack_runtime__");
exports.default = $__fpack__.defineClass(class  {
  
}, [{"name": "prop", "value": 'ExportDefaultClass'}], [], []);
;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"builtin$$B$$ExportNamedClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $__fpack__ = __fastpack_require__(/* "__fastpack_runtime__" */ "builtin$$COLON$$__fastpack_runtime__");
let ExportNamedClass = $__fpack__.defineClass(class ExportNamedClass {
    
  }, [{"name": "prop", "value": "ExportNamedClass"}], [], []);
Object.defineProperty(exports, "ExportNamedClass", {get: function() {return ExportNamedClass;}});

;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "./ExportDefaultNamedClass" */ "builtin$$B$$ExportDefaultNamedClass");
const $lib2 = __fastpack_require__(/* "./ExportDefaultClass" */ "builtin$$B$$ExportDefaultClass");
const $lib3 = __fastpack_require__(/* "./ExportNamedClass" */ "builtin$$B$$ExportNamedClass");
console.log($lib1.default.prop);
console.log($lib2.default.prop);

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},

});
