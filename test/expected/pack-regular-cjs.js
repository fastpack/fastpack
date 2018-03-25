
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
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
  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
let a = 1;;Object.defineProperty(exports, "a", {get: function() {return a;}});
function f() { a = a + 1};
Object.defineProperty(exports, "changeA", {get: function() {return f;}});

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const _1__a = __fastpack_require__(/* "./a" */ "a");Object.defineProperty(exports, "a", {get: function() {return _1__a.a;}});Object.defineProperty(exports, "changeA", {get: function() {return _1__a.changeA;}});
let index = 1;;Object.defineProperty(exports, "index", {get: function() {return index;}});
exports.default = function() {console.log('Hello, world!')};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
