
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(fromModule, request) {
    var moduleId = fromModule === null ? request : modules[fromModule].d[request];

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
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      __fastpack_require__.bind(null, moduleId),
      __fastpack_import__.bind(null, moduleId)
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(fromModule, request) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(fromModule, request));
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
  return __fastpack_require__(null, __fastpack_require__.s = '$fp$main');
})
    ({
"$fp$runtime":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\nfunction applyDecorator(decorator, proto, property, descriptor) {\n  var ret = decorator(proto, property, descriptor);\n  // TODO: assert all descriptor properties;\n  return ret;\n}\n\nfunction decorateProperty(cls, property, decorators) {\n  var proto = cls.prototype;\n  var descriptor = Object.assign(\n    {},\n    Object.getOwnPropertyDescriptor(proto, property)\n  );\n\n  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;\n      i < l;\n      i++) {\n    descriptor = applyDecorator(reversed[i], proto, property, descriptor);\n  }\n\n  Object.defineProperty(proto, property, descriptor);\n}\n\nmodule.exports = {\n  omitProps: function(target, props) {\n    var ret = {};\n    for(var prop in target) {\n      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {\n        ret[prop] = target[prop];\n      }\n    }\n    return ret;\n  },\n\n  defineClass: function(cls, statics, classDecorators, propertyDecorators) {\n    for(var i = 0, l = propertyDecorators.length; i < l; i++) {\n      decorateProperty(cls,\n                       propertyDecorators[i].method,\n                       propertyDecorators[i].decorators);\n    }\n\n    for(var i = 0, l = statics.length; i < l; i++) {\n      Object.defineProperty(cls, statics[i].name, {\n        configurable: true,\n        enumerable: true,\n        writable: true,\n        value: statics[i].value\n      })\n    }\n\n    var _cls = cls;\n    classDecorators = classDecorators.reverse();\n    for(var i = 0; i < classDecorators.length; i++) {\n      _cls = classDecorators[i](_cls);\n    }\n    return _cls;\n  }\n};\n\n//# sourceURL=fpack:///$fp$runtime\n//# sourceURL=fpack:///$fp$runtime");
},
d: {}
},
"builtin$$B$$esm":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"hello, world!\";\n\n//# sourceURL=fpack:///builtin!esm.js\n//# sourceURL=fpack:///builtin!esm.js");
},
d: {}
},
"builtin$$B$$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const $__fpack__ = __fastpack_require__(\"$fp$runtime\");\nconst esm = __fastpack_require__(\"./esm\");\nconst {delimiter} = path,\n  rest = $__fpack__.omitProps(path, [\"delimiter\"]);\nconsole.log(path, module, delimiter, rest, esm);\n// The following test makes sure that builtin transpiler strips type annotations\n// from inside JSX\nconst Component = props => React.createElement(\"div\", null, item => {\n    \n  }\n  );\n\n//# sourceURL=fpack:///builtin!index.js\n//# sourceURL=fpack:///builtin!index.js");
},
d: {"$fp$runtime":"$fp$runtime","./esm":"builtin$$B$$esm"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"builtin$$B$$index"}
},

});
