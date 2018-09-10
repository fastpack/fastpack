
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
"NM$$babel$$_$$loader$lib$indexDOT$$js$$B$$nm$package$$_$$1$babel$$_$$transpile":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nfunction _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }\n\nexports.default = class {\n  constructor() {\n    _defineProperty(this, \"field\", 'babel-transpile');\n  }\n\n}\n//# sourceURL=fpack:///node_modules/babel-loader/lib/index.js!nm/package-1/babel-transpile.js\n//# sourceURL=fpack:///node_modules/babel-loader/lib/index.js!nm/package-1/babel-transpile.js");
},
d: {}
},
"builtin$$B$$nm$package$$_$$1$builtin$$_$$transpile":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = class  {\n  constructor( ...args) {\n    Object.defineProperty(this, \"field\", {\"configurable\": true, \"enumerable\": true, \"writable\": true, \"value\": 'builtin-transpile'});\n    \n  }\n  \n};\n\n//# sourceURL=fpack:///builtin!nm/package-1/builtin-transpile.js\n//# sourceURL=fpack:///builtin!nm/package-1/builtin-transpile.js");
},
d: {}
},
"nm$package$$_$$1$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__babel_transpile_js = __fastpack_require__(\"./babel-transpile.js\");const _1__babel_transpile_js__default = _1__babel_transpile_js.__esModule ? _1__babel_transpile_js.default : _1__babel_transpile_js;\nconst _2__builtin_transpile_js = __fastpack_require__(\"./builtin-transpile.js\");const _2__builtin_transpile_js__default = _2__builtin_transpile_js.__esModule ? _2__builtin_transpile_js.default : _2__builtin_transpile_js;\n\n\n\nexports.default = function () {\n  console.log('package-1')\n  console.log(_1__babel_transpile_js__default, _2__builtin_transpile_js__default)\n}\n\n//# sourceURL=fpack:///nm/package-1/index.js\n//# sourceURL=fpack:///nm/package-1/index.js");
},
d: {"./babel-transpile.js":"NM$$babel$$_$$loader$lib$indexDOT$$js$$B$$nm$package$$_$$1$babel$$_$$transpile","./builtin-transpile.js":"builtin$$B$$nm$package$$_$$1$builtin$$_$$transpile"}
},
"app$nm$package$$_$$2$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = function () {\n  console.log('package-2')\n}\n\n//# sourceURL=fpack:///app/nm/package-2/index.js\n//# sourceURL=fpack:///app/nm/package-2/index.js");
},
d: {}
},
"app$mock":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nfunction mock() {\n  console.log('mock')\n}\nexports.default = mock;\n\n\n//# sourceURL=fpack:///app/mock.js\n//# sourceURL=fpack:///app/mock.js");
},
d: {}
},
"app$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1_package_1 = __fastpack_require__(\"package-1\");const _1_package_1__default = _1_package_1.__esModule ? _1_package_1.default : _1_package_1;\nconst _2_package_2 = __fastpack_require__(\"package-2\");const _2_package_2__default = _2_package_2.__esModule ? _2_package_2.default : _2_package_2;\nconst _3_mocked = __fastpack_require__(\"mocked\");const _3_mocked__default = _3_mocked.__esModule ? _3_mocked.default : _3_mocked;\n\n\n\n\nconsole.log(_1_package_1__default, _2_package_2__default, _3_mocked__default)\n\n//# sourceURL=fpack:///app/index.js\n//# sourceURL=fpack:///app/index.js");
},
d: {"package-1":"nm$package$$_$$1$index","package-2":"app$nm$package$$_$$2$index","mocked":"app$mock"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"app$index"}
},

});
