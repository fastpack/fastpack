
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
"dep": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst dep = () => {};;Object.defineProperty(exports, \"dep\", {enumerable: true, get: function() {return dep;}});\n\n//# sourceURL=fpack:///dep.js");
},
"reexport": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__dep_js = __fastpack_require__(/* \"./dep.js\" */ \"dep\");Object.defineProperty(exports, \"dep\", {enumerable: true, get: function() {return _1__dep_js.dep;}});\n\n//# sourceURL=fpack:///reexport.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__reexport_js = __fastpack_require__(/* \"./reexport.js\" */ \"reexport\");\nconsole.log(_1__reexport_js.dep);\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
