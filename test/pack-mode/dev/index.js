
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
"dev": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports = {dev: true};\n\n//# sourceURL=fpack:///dev.js");
},
"prod": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports = {prod: true};\n\n//# sourceURL=fpack:///prod.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\nlet p;\n\n// if-then-no-else\n{}\n\n{}\n\n{}\n\n{}\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\n// if-then-else\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\n\n// alternative statement\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\n// logical AND expression\nif (\"development\" == \"production\" && x && y && z)\n  p = __fastpack_require__(/* \"./prod\" */ \"prod\");\nelse\n  p = __fastpack_require__(/* \"./dev\" */ \"dev\");\n\n// conditional operator\np = __fastpack_require__(/* \"./dev\" */ \"dev\");\nconsole.log(\"development\");\n\n// bug\nif (true) {} else {}\nif (false) {} else {console.log(\"dev!\")}\n\n// bug\nImage.propTypes = call());\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
