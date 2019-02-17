
global = this;
global.process = global.process || {};
global.process.env = global.process.env || {};
global.process.browser = true;
if(!global.Buffer) {
  global.Buffer = function() {
    throw Error("Buffer is not included in the browser environment. Consider using the polyfill")
  };
  global.Buffer.isBuffer = function() {return false};
}
if(!global.setImmediate) {
  global.setImmediate = setTimeout;
  global.clearImmediate = clearTimeout;
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

  global.__fastpack_update_modules__ = function(newModules) {
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
      if (!global.Promise) {
        throw Error("global.Promise is undefined, consider using a polyfill");
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
              setTimeout(resolve);
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
}) /* --runtimeMain-- */
({
/* !s: log1.js */
"logSourceDOT$$js$$B$$log1":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n\n  exports.default = function () {console.log(\"\\nexport default function() { console.log(1); }\\n\")};\n  \n//# sourceURL=fpack:///logSource.js!log1.js");
},
d: {}
},
/* !s: log2.js */
"builtin$$B$$log2":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n\nexports.default = function() { console.log(2); }\n\n//# sourceURL=fpack:///builtin!log2.js");
},
d: {}
},
/* !s: log3.js */
"builtin$$B$$log3":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n\nexports.default = function() { console.log(3); }\n\n//# sourceURL=fpack:///builtin!log3.js");
},
d: {}
},
/* !s: index.js */
"builtin$$B$$index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__log1 = __fastpack_require__(\"./log1\");\nconst _2__log2 = __fastpack_require__(\"./log2\");\nconst _3__log3 = __fastpack_require__(\"./log3\");\n\n\n\n\n\n(__fastpack_require__.default(_1__log1))();\n(__fastpack_require__.default(_2__log2))();\n(__fastpack_require__.default(_3__log3))();\n\n//# sourceURL=fpack:///builtin!index.js");
},
d: {"./log1":"logSourceDOT$$js$$B$$log1","./log2":"builtin$$B$$log2","./log3":"builtin$$B$$log3"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"builtin$$B$$index"}
},

});
