
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
"x": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"x exported\";\nconst x = \"x\";;Object.defineProperty(exports, \"x\", {enumerable: true, get: function() {return x;}});\n\n//# sourceURL=fpack:///x.js");
},
"y": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"y exported\";\nconst y = \"y\";;Object.defineProperty(exports, \"y\", {enumerable: true, get: function() {return y;}});\n\n//# sourceURL=fpack:///y.js");
},
"reexport": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__x = __fastpack_require__(/* \"./x\" */ \"x\");Object.defineProperty(exports, \"x\", {enumerable: true, get: function() {return _1__x.x;}});\nconst _2__y = __fastpack_require__(/* \"./y\" */ \"y\");Object.defineProperty(exports, \"y\", {enumerable: true, get: function() {return _2__y.y;}});\n\n//# sourceURL=fpack:///reexport.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__reexport = __fastpack_require__(/* \"./reexport\" */ \"reexport\");\n\nconsole.log(_1__reexport.x,_1__reexport.y);\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
