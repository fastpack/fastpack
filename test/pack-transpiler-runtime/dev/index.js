
global = this;
process = { env: {}, browser: true };
if (!global.Buffer) {
  global.Buffer = { isBuffer: false };
}
// This function is a modified version of the one created by the Webpack project
(function(modules) {
  // The module cache
  var installedModules = {};

  function __fastpack_require__(fromModule, request) {
    var moduleId =
      fromModule === null ? request : modules[fromModule].d[request];

    if (installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    var module = (installedModules[moduleId] = {
      id: moduleId,
      l: false,
      exports: {}
    });

    var r = __fastpack_require__.bind(null, moduleId);
    var helpers = Object.getOwnPropertyNames(__fastpack_require__.helpers);
    for (var i = 0, l = helpers.length; i < l; i++) {
      r[helpers[i]] = __fastpack_require__.helpers[helpers[i]];
    }
    r.imp = r.imp.bind(null, moduleId);
    r.state = state;
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      r,
      r.imp
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  var loadedChunks = {};
  var state = {
    publicPath: ""
  };

  window.__fastpack_update_modules__ = function(newModules) {
    for (var id in newModules) {
      if (modules[id]) {
        throw new Error(
          "Chunk tries to replace already existing module: " + id
        );
      } else {
        modules[id] = newModules[id];
      }
    }
  };

  __fastpack_require__.helpers = {
    omitDefault: function(moduleVar) {
      var keys = Object.keys(moduleVar);
      var ret = {};
      for (var i = 0, l = keys.length; i < l; i++) {
        var key = keys[i];
        if (key !== "default") {
          ret[key] = moduleVar[key];
        }
      }
      return ret;
    },

    default: function(exports) {
      return exports.__esModule ? exports.default : exports;
    },

    imp: function(fromModule, request) {
      if (!window.Promise) {
        throw Error("window.Promise is undefined, consider using a polyfill");
      }
      var sourceModule = modules[fromModule];
      var chunks = (sourceModule.c || {})[request] || [];
      var promises = [];
      for (var i = 0, l = chunks.length; i < l; i++) {
        var js = chunks[i];
        var p = loadedChunks[js];
        if (!p) {
          p = loadedChunks[js] = new Promise(function(resolve, reject) {
            var script = document.createElement("script");
            script.onload = function() {
              resolve();
            };
            script.onerror = function() {
              reject();
              throw new Error("Script load error: " + script.src);
            };
            script.src = state.publicPath + chunks[i];
            document.head.append(script);
          });
          promises.push(p);
        }
      }
      return Promise.all(promises).then(function() {
        return __fastpack_require__(fromModule, request);
      });
    }
  };

  return __fastpack_require__(null, (__fastpack_require__.s = "$fp$main"));
})
({
/* !s: transpiler-runtime */
"$fp$runtime":{m:function(module, exports, __fastpack_require__) {
eval("\n\nfunction applyDecorator(decorator, proto, property, descriptor) {\n  var ret = decorator(proto, property, descriptor);\n  // TODO: assert all descriptor properties;\n  return ret;\n}\n\nfunction decorateProperty(cls, property, decorators) {\n  var proto = cls.prototype;\n  var descriptor = Object.assign(\n    {},\n    Object.getOwnPropertyDescriptor(proto, property)\n  );\n\n  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;\n      i < l;\n      i++) {\n    descriptor = applyDecorator(reversed[i], proto, property, descriptor);\n  }\n\n  Object.defineProperty(proto, property, descriptor);\n}\n\nmodule.exports = {\n  omitProps: function(target, props) {\n    var ret = {};\n    for(var prop in target) {\n      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {\n        ret[prop] = target[prop];\n      }\n    }\n    return ret;\n  },\n\n  defineClass: function(cls, statics, classDecorators, propertyDecorators) {\n    for(var i = 0, l = propertyDecorators.length; i < l; i++) {\n      decorateProperty(cls,\n                       propertyDecorators[i].method,\n                       propertyDecorators[i].decorators);\n    }\n\n    for(var i = 0, l = statics.length; i < l; i++) {\n      Object.defineProperty(cls, statics[i].name, {\n        configurable: true,\n        enumerable: true,\n        writable: true,\n        value: statics[i].value\n      })\n    }\n\n    var _cls = cls;\n    classDecorators = classDecorators.reverse();\n    for(var i = 0; i < classDecorators.length; i++) {\n      _cls = classDecorators[i](_cls);\n    }\n    return _cls;\n  }\n};\n\n//# sourceURL=fpack:///$fp$runtime");
},
d: {}
},
/* !s: index.js */
"builtin$$B$$index":{m:function(module, exports, __fastpack_require__) {
eval("const $__fpack__ = __fastpack_require__(\"$fp$runtime\");\nfunction decorator1(proto, property, descriptor) {\n  let oldValue = descriptor.value;\n  descriptor.value = function () {\n    let ret = oldValue.call(this);\n    return `@decorator1 ${ret}`;\n    \n  }\n  ;\n  return descriptor;\n  \n}\nfunction decorator2(proto, property, descriptor) {\n  let oldValue = descriptor.value;\n  descriptor.value = function () {\n    let ret = oldValue.call(this);\n    return `@decorator2 ${ret}`;\n    \n  }\n  ;\n  return descriptor;\n  \n}\nfunction classDecorator1(cls) {\n  cls.staticProp = `@classDecorator1 ${cls.staticProp}`;\n  return cls;\n  \n}\nfunction classDecorator2(cls) {\n  cls.staticProp = `@classDecorator2 ${cls.staticProp}`;\n  return cls;\n  \n}\nlet Test = $__fpack__.defineClass(class Test {\n    constructor( ...args) {\n      Object.defineProperty(this, \"prop\", {\"configurable\": true, \"enumerable\": true, \"writable\": true, \"value\": \"instance property\"});\n      \n    }\n    \n    method() {\n      return \"method\";\n      \n    }\n    \n  }, [{\"name\": \"staticProp\", \"value\": \"class property\"}], [classDecorator2, classDecorator1], [{\"method\": \"method\", \"decorators\": [decorator2, decorator1]}]);\nlet __fpack__1 = {test: new Test(), a: 1, b: 2, c: 3},\n  {test} = __fpack__1,\n  rest = $__fpack__.omitProps(__fpack__1, [\"test\"]);\ndocument.body.innerHTML = `\n<div>Static property: <b>${Test.staticProp}</b></div>\n<div>Property: <b>${test.prop}</b></div>\n<div>method: <b>${test.method()}</b></div>\n<div>...rest: <b>${JSON.stringify(rest)}</b></div>\n`;\n\n//# sourceURL=fpack:///builtin!index.js");
},
d: {"$fp$runtime":"$fp$runtime"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"builtin$$B$$index"}
},

});
