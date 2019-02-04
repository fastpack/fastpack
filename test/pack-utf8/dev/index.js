
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
/* !s: a.js */
"a":{m:function(module, exports, __fastpack_require__) {
eval("module.exports.__esModule = true;\nlet a1 = \"Тест\";;Object.defineProperty(exports, \"a1\", {enumerable: true, get: function() {return a1;}});\nlet a2 = \"Привет, мир\";;Object.defineProperty(exports, \"a2\", {enumerable: true, get: function() {return a2;}});\nlet a3 = \"哈囉世界\";;Object.defineProperty(exports, \"a3\", {enumerable: true, get: function() {return a3;}});\nlet a4 = \"💩\";;Object.defineProperty(exports, \"a4\", {enumerable: true, get: function() {return a4;}});\nexports.default = {a1: a1, a2: a2, a3: a3, a4: a4};\n\n//# sourceURL=fpack:///a.js");
},
d: {}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");\n\nconsole.log(_1__a.a1, _1__a.a2, _1__a.a3);\nexports.default = function() {\n  console.log(\"Русский\", \"development\",\n              \"разработка\");\n}\n\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
