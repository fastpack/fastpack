
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
  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
let a1 = "Тест";;Object.defineProperty(exports, "a1", {get: function() {return a1;}});
let a2 = "Привет, мир";;Object.defineProperty(exports, "a2", {get: function() {return a2;}});
let a3 = "哈囉世界";;Object.defineProperty(exports, "a3", {get: function() {return a3;}});
let a4 = "💩";;Object.defineProperty(exports, "a4", {get: function() {return a4;}});
exports.default = {a1: a1, a2: a2, a3: a3, a4: a4};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const _1__a = __fastpack_require__(/* "./a" */ "a");
console.log(_1__a.a1, _1__a.a2, _1__a.a3);
exports.default = function() {
  console.log("Русский", "production",
              "релиз!");
}

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
