
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
  return __fastpack_require__(__fastpack_require__.s = 'fp$main');
})
({
"dep": function(module, exports, __fastpack_require__, __fastpack_import__) {
exports.default = "dep.js";

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
var dep = __fastpack_require__(/* "./dep" */ "dep");

function f(require) {
  return require("./dep");
}

function g() {
  var s = f(x => x);
  var dep2 = __fastpack_require__(/* "./dep" */ "dep");
  document.body.innerHTML = `Imported: ${dep.default} Imported: ${
    dep2.default
  } Untouched: ${s}`;
}

g();

},
"fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./index.js" */ "index");


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
