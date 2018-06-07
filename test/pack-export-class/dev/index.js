
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
eval("\nfunction applyDecorator(decorator, proto, property, descriptor) {\n  var ret = decorator(proto, property, descriptor);\n  // TODO: assert all descriptor properties;\n  return ret;\n}\n\nfunction decorateProperty(cls, property, decorators) {\n  var proto = cls.prototype;\n  var descriptor = Object.assign(\n    {},\n    Object.getOwnPropertyDescriptor(proto, property)\n  );\n\n  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;\n      i < l;\n      i++) {\n    descriptor = applyDecorator(reversed[i], proto, property, descriptor);\n  }\n\n  Object.defineProperty(proto, property, descriptor);\n}\n\nmodule.exports = {\n  omitProps: function(target, props) {\n    var ret = {};\n    for(var prop in target) {\n      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {\n        ret[prop] = target[prop];\n      }\n    }\n    return ret;\n  },\n\n  defineClass: function(cls, statics, classDecorators, propertyDecorators) {\n    for(var i = 0, l = propertyDecorators.length; i < l; i++) {\n      decorateProperty(cls,\n                       propertyDecorators[i].method,\n                       propertyDecorators[i].decorators);\n    }\n\n    for(var i = 0, l = statics.length; i < l; i++) {\n      Object.defineProperty(cls, statics[i].name, {\n        configurable: true,\n        enumerable: true,\n        writable: true,\n        value: statics[i].value\n      })\n    }\n\n    var _cls = cls;\n    classDecorators = classDecorators.reverse();\n    for(var i = 0; i < classDecorators.length; i++) {\n      _cls = classDecorators[i](_cls);\n    }\n    return _cls;\n  }\n};\n\n//# sourceURL=fpack:///$fp$runtime");
},
"builtin$$B$$ExportDefaultNamedClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst $__fpack__ = __fastpack_require__(/* \"$fp$runtime\" */ \"$fp$runtime\");\nlet C = $__fpack__.defineClass(class C {\n    \n  }, [{\"name\": \"prop\", \"value\": 'ExportDefaultNamedClass'}], [], []);\nexports.default = C;\n\n//# sourceURL=fpack:///builtin!ExportDefaultNamedClass.js");
},
"builtin$$B$$ExportDefaultClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst $__fpack__ = __fastpack_require__(/* \"$fp$runtime\" */ \"$fp$runtime\");\nexports.default = $__fpack__.defineClass(class  {\n  \n}, [{\"name\": \"prop\", \"value\": 'ExportDefaultClass'}], [], []);\n;\n\n//# sourceURL=fpack:///builtin!ExportDefaultClass.js");
},
"builtin$$B$$ExportNamedClass": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst $__fpack__ = __fastpack_require__(/* \"$fp$runtime\" */ \"$fp$runtime\");\nlet ExportNamedClass = $__fpack__.defineClass(class ExportNamedClass {\n    \n  }, [{\"name\": \"prop\", \"value\": \"ExportNamedClass\"}], [], []);;Object.defineProperty(exports, \"ExportNamedClass\", {enumerable: true, get: function() {return ExportNamedClass;}});\n;\n\n//# sourceURL=fpack:///builtin!ExportNamedClass.js");
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__ExportDefaultNamedClass = __fastpack_require__(/* \"./ExportDefaultNamedClass\" */ \"builtin$$B$$ExportDefaultNamedClass\");\nconst _2__ExportDefaultClass = __fastpack_require__(/* \"./ExportDefaultClass\" */ \"builtin$$B$$ExportDefaultClass\");\nconst _3__ExportNamedClass = __fastpack_require__(/* \"./ExportNamedClass\" */ \"builtin$$B$$ExportNamedClass\");\nconsole.log(_1__ExportDefaultNamedClass.default.prop);\nconsole.log(_2__ExportDefaultClass.default.prop);\n\n//# sourceURL=fpack:///builtin!index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"builtin$$B$$index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
