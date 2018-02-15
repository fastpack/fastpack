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
    return new Promise((resolve, reject) => {
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
  let ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function decorateProperty(cls, property, decorators) {
  let proto = cls.prototype;
  let descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  // TODO: Babel also accounts for descriptor.initializer. Is it needed?
  descriptor = decorators.reverse().reduce(
    (descriptor, decorator) => applyDecorator(decorator, proto, property, descriptor),
    descriptor
  );

  Object.defineProperty(proto, property, descriptor);
}

module.exports = {
  omitProps(target, props) {
    let ret = {};
    for(let prop in target) {
      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {
        ret[prop] = target[prop];
      }
    }
    return ret;
  },

  defineClass(cls, statics, classDecorators, propertyDecorators) {
    propertyDecorators.forEach(
      ({method, decorators}) => decorateProperty(cls, method, decorators)
    );

    statics.forEach(({name, value}) =>
      Object.defineProperty(cls, name, {
        configurable: true,
        enumerable: true,
        writable: true,
        value: value
      })
    );
    let _cls = cls;
    classDecorators = classDecorators.reverse();
    for(let i = 0; i < classDecorators.length; i++) {
      _cls = classDecorators[i](_cls);
    }
    return _cls;

    //return classDecorators.reverse().reduce(decorator => decorator(cls), cls);
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
