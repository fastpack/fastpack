
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
"Util": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nfunction inherit(child, parent) {\n  child.parent = parent;\n};Object.defineProperty(exports, \"inherit\", {get: function() {return inherit;}});\n\n//# sourceURL=fpack:///Util.js");
},
"C": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nconst _1__QC = __fastpack_require__(/* \"./QC\" */ \"QC\");\nconst _2__Util = __fastpack_require__(/* \"./Util\" */ \"Util\");\n\nvar C = (function() {\n  var C = { className: 'C'};\n  _2__Util.inherit(C, _1__QC.default);\n  return C;\n})();\n\nexports.default = C;\n\n//# sourceURL=fpack:///C.js");
},
"QC": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nconst _1__C = __fastpack_require__(/* \"./C\" */ \"C\");\nconst _2__Util = __fastpack_require__(/* \"./Util\" */ \"Util\");\n\nvar Q = (function() {\n  var Q = { className: 'Q'};\n  _2__Util.inherit(Q, _1__C.default);\n  return Q;\n})();\n\nexports.default = Q;\n\n//# sourceURL=fpack:///QC.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nconst _1__QC = __fastpack_require__(/* \"./QC\" */ \"QC\");\nconsole.log(_1__QC.default);\nconsole.log(_1__QC.default.parent);\nconsole.log(_1__QC.default.parent.parent);\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
