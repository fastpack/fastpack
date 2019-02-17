
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
/* !s: nm/package-1/babel-transpile.js */
"NM$$babel$$_$$loader$lib$indexDOT$$js$$B$$nm$package$$_$$1$babel$$_$$transpile":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nfunction _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }\n\nexports.default = class {\n  constructor() {\n    _defineProperty(this, \"field\", 'babel-transpile');\n  }\n\n}\n//# sourceURL=fpack:///node_modules/babel-loader/lib/index.js!nm/package-1/babel-transpile.js");
},
d: {}
},
/* !s: nm/package-1/builtin-transpile.js */
"builtin$$B$$nm$package$$_$$1$builtin$$_$$transpile":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = class  {\n  constructor( ...args) {\n    Object.defineProperty(this, \"field\", {\"configurable\": true, \"enumerable\": true, \"writable\": true, \"value\": 'builtin-transpile'});\n    \n  }\n  \n};\n\n//# sourceURL=fpack:///builtin!nm/package-1/builtin-transpile.js");
},
d: {}
},
/* !s: nm/package-1/index.js */
"nm$package$$_$$1$index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1__babel_transpile_js = __fastpack_require__(\"./babel-transpile.js\");\nconst _2__builtin_transpile_js = __fastpack_require__(\"./builtin-transpile.js\");\n\n\n\nexports.default = function () {\n  console.log('package-1')\n  console.log((__fastpack_require__.default(_1__babel_transpile_js)), (__fastpack_require__.default(_2__builtin_transpile_js)))\n}\n\n//# sourceURL=fpack:///nm/package-1/index.js");
},
d: {"./babel-transpile.js":"NM$$babel$$_$$loader$lib$indexDOT$$js$$B$$nm$package$$_$$1$babel$$_$$transpile","./builtin-transpile.js":"builtin$$B$$nm$package$$_$$1$builtin$$_$$transpile"}
},
/* !s: app/nm/package-2/index.js */
"app$nm$package$$_$$2$index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nexports.default = function () {\n  console.log('package-2')\n}\n\n//# sourceURL=fpack:///app/nm/package-2/index.js");
},
d: {}
},
/* !s: app/mock.js */
"app$mock":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nfunction mock() {\n  console.log('mock')\n}\nexports.default = mock;\n\n\n//# sourceURL=fpack:///app/mock.js");
},
d: {}
},
/* !s: app/index.js */
"app$index":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\nconst _1_package_1 = __fastpack_require__(\"package-1\");\nconst _2_package_2 = __fastpack_require__(\"package-2\");\nconst _3_mocked = __fastpack_require__(\"mocked\");\n\n\n\n\nconsole.log((__fastpack_require__.default(_1_package_1)), (__fastpack_require__.default(_2_package_2)), (__fastpack_require__.default(_3_mocked)))\n\n//# sourceURL=fpack:///app/index.js");
},
d: {"package-1":"nm$package$$_$$1$index","package-2":"app$nm$package$$_$$2$index","mocked":"app$mock"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__) {
eval("Object.defineProperty(module.exports, \"__esModule\", {value: !0});\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"app$index"}
},

});
