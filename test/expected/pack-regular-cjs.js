module.exports = (function(modules) {
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
      i: moduleId,
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
    return new Promise((resolve, reject) => {
      try {
        resolve(__fastpack_require__(moduleId));
      } catch (e) {
        reject(e);
      }
    });
  }

  // expose the modules object
  __fastpack_require__.m = modules;

  // expose the module cache
  __fastpack_require__.c = installedModules;

  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
let a = 1;
Object.defineProperty(exports, "a", {get: () => a});

function f() { a = a + 1};
Object.defineProperty(exports, "changeA", {get: () => f});
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "./a" */ "a");
Object.defineProperty(exports, "a", {get: () => $lib1.a}); Object.defineProperty(exports, "changeA", {get: () => $lib1.changeA});
let index = 1;
Object.defineProperty(exports, "index", {get: () => index});

exports.default = function() {console.log('Hello, world!')};
},

});
