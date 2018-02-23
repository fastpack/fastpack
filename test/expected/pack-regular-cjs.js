
// This function is a modified version of the one created by the Webpack project
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

  // expose the modules object
  __fastpack_require__.m = modules;

  // expose the module cache
  __fastpack_require__.c = installedModules;

  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
let a = 1;
Object.defineProperty(exports, "a", {get: function() {return a;}});

function f() { a = a + 1};
Object.defineProperty(exports, "changeA", {get: function() {return f;}});

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "./a" */ "a");
Object.defineProperty(exports, "a", {get: function() {return $lib1.a;}}); Object.defineProperty(exports, "changeA", {get: function() {return $lib1.changeA;}});
let index = 1;
Object.defineProperty(exports, "index", {get: function() {return index;}});

exports.default = function() {console.log('Hello, world!')};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},

});
