
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
"builtin$$COLON$$__empty_module__": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = {};},
"builtin$$B$$esm": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "path" */ "builtin$$COLON$$__empty_module__");
exports.default = $lib1.delimiter;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $__fpack__ = __fastpack_require__(/* "__fastpack_runtime__" */ "builtin$$COLON$$__fastpack_runtime__");
const path = __fastpack_require__(/* "path" */ "builtin$$COLON$$__empty_module__");
const module = __fastpack_require__(/* "module" */ "builtin$$COLON$$__empty_module__");
const esm = __fastpack_require__(/* "./esm" */ "builtin$$B$$esm");
const {delimiter} = path,
  rest = $__fpack__.omitProps(path, ["delimiter"]);
console.log(path, module, delimiter, rest, esm);
// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const Component = props => React.createElement("div", null, item => {
    
  }
  );
},

});
