
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
"$fp$runtime__defineClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\n  function applyDecorator(decorator, proto, property, descriptor) {\n    var ret = decorator(proto, property, descriptor);\n    // TODO: assert all descriptor properties;\n    return ret;\n  }\n\n  function decorateProperty(cls, property, decorators) {\n    var proto = cls.prototype;\n    var descriptor = Object.assign(\n      {},\n      Object.getOwnPropertyDescriptor(proto, property)\n    );\n\n    for (\n      var i = 0, reversed = decorators.reverse(), l = reversed.length;\n      i < l;\n      i++\n    ) {\n      descriptor = applyDecorator(reversed[i], proto, property, descriptor);\n    }\n\n    Object.defineProperty(proto, property, descriptor);\n  }\n\n  function defineClass(cls, statics, classDecorators, propertyDecorators) {\n    for (var i = 0, l = propertyDecorators.length; i < l; i++) {\n      decorateProperty(\n        cls,\n        propertyDecorators[i].method,\n        propertyDecorators[i].decorators\n      );\n    }\n\n    for (var i = 0, l = statics.length; i < l; i++) {\n      Object.defineProperty(cls, statics[i].name, {\n        configurable: true,\n        enumerable: true,\n        writable: true,\n        value: statics[i].value\n      });\n    }\n\n    var _cls = cls;\n    classDecorators = classDecorators.reverse();\n    for (var i = 0; i < classDecorators.length; i++) {\n      _cls = classDecorators[i](_cls);\n    }\n    return _cls;\n  }\n\n  module.exports = defineClass;\n\n//# sourceURL=fpack:///$fp$runtime__defineClass");
},
"$fp$runtime__omitProps": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\n    var hasOwnProperty = Object.prototype.hasOwnProperty;\n\n    function omitProps(target, props) {\n      var ret = {};\n      for (var prop in target) {\n        if (hasOwnProperty.call(target, prop) && props.indexOf(prop) === -1) {\n          ret[prop] = target[prop];\n        }\n      }\n      return ret;\n    }\n\n    module.exports = omitProps;\n  \n//# sourceURL=fpack:///$fp$runtime__omitProps");
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const $fp$runtime__defineClass = __fastpack_require__(/* \"$fp$runtime__defineClass\" */ \"$fp$runtime__defineClass\");\nconst $fp$runtime__omitProps = __fastpack_require__(/* \"$fp$runtime__omitProps\" */ \"$fp$runtime__omitProps\");\nfunction decorator1(proto, property, descriptor) {\n  let oldValue = descriptor.value;\n  descriptor.value = function () {\n    let ret = oldValue.call(this);\n    return `@decorator1 ${ret}`;\n    \n  }\n  ;\n  return descriptor;\n  \n}\nfunction decorator2(proto, property, descriptor) {\n  let oldValue = descriptor.value;\n  descriptor.value = function () {\n    let ret = oldValue.call(this);\n    return `@decorator2 ${ret}`;\n    \n  }\n  ;\n  return descriptor;\n  \n}\nfunction classDecorator1(cls) {\n  cls.staticProp = `@classDecorator1 ${cls.staticProp}`;\n  return cls;\n  \n}\nfunction classDecorator2(cls) {\n  cls.staticProp = `@classDecorator2 ${cls.staticProp}`;\n  return cls;\n  \n}\nlet Test = $fp$runtime__defineClass(class Test {\n    constructor( ...args) {\n      Object.defineProperty(this, \"prop\", {\"configurable\": true, \"enumerable\": true, \"writable\": true, \"value\": \"instance property\"});\n      \n    }\n    \n    method() {\n      return \"method\";\n      \n    }\n    \n  }, [{\"name\": \"staticProp\", \"value\": \"class property\"}], [classDecorator2, classDecorator1], [{\"method\": \"method\", \"decorators\": [decorator2, decorator1]}]);\nlet __fpack__1 = {test: new Test(), a: 1, b: 2, c: 3},\n  {test} = __fpack__1,\n  rest = $fp$runtime__omitProps(__fpack__1, [\"test\"]);\ndocument.body.innerHTML = `\n<div>Static property: <b>${Test.staticProp}</b></div>\n<div>Property: <b>${test.prop}</b></div>\n<div>method: <b>${test.method()}</b></div>\n<div>...rest: <b>${JSON.stringify(rest)}</b></div>\n`;\n\n//# sourceURL=fpack:///builtin!index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"builtin$$B$$index\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
