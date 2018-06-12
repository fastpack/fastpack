
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
"logSourceDOT$$js$$B$$log1": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\n  exports.default = function () {console.log(\"\\nexport default function() { console.log(1); }\\n\")};\n  \n//# sourceURL=fpack:///logSource.js!log1.js");
},
"builtin$$B$$log2": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = function () {\n  console.log(2);\n  \n}\n;\n\n//# sourceURL=fpack:///builtin!log2.js");
},
"builtin$$B$$log3": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = function () {\n  console.log(3);\n  \n}\n;\n\n//# sourceURL=fpack:///builtin!log3.js");
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__log1 = __fastpack_require__(/* \"./log1\" */ \"logSourceDOT$$js$$B$$log1\");\nconst _2__log2 = __fastpack_require__(/* \"./log2\" */ \"builtin$$B$$log2\");\nconst _3__log3 = __fastpack_require__(/* \"./log3\" */ \"builtin$$B$$log3\");\n_1__log1.default();\n_2__log2.default();\n_3__log3.default();\n\n//# sourceURL=fpack:///builtin!index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"builtin$$B$$index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
