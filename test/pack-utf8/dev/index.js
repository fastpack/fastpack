
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

    var r = __fastpack_require__.bind(null, moduleId);
    r.omitDefault = __fastpack_require__.omitDefault;
    // Execute the module function
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      r,
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
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nlet a1 = \"Тест\";;Object.defineProperty(exports, \"a1\", {enumerable: true, get: function() {return a1;}});\nlet a2 = \"Привет, мир\";;Object.defineProperty(exports, \"a2\", {enumerable: true, get: function() {return a2;}});\nlet a3 = \"哈囉世界\";;Object.defineProperty(exports, \"a3\", {enumerable: true, get: function() {return a3;}});\nlet a4 = \"💩\";;Object.defineProperty(exports, \"a4\", {enumerable: true, get: function() {return a4;}});\nexports.default = {a1: a1, a2: a2, a3: a3, a4: a4};\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__a = __fastpack_require__(\"./a\");\n\nconsole.log(_1__a.a1, _1__a.a2, _1__a.a3);\nexports.default = function() {\n  console.log(\"Русский\", \"development\",\n              \"разработка\");\n}\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
