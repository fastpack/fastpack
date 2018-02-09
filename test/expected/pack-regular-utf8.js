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
let a1 = "Тест";
Object.defineProperty(exports, "a1", {get: () => a1});

let a2 = "Привет, мир";
Object.defineProperty(exports, "a2", {get: () => a2});

let a3 = "哈囉世界";
Object.defineProperty(exports, "a3", {get: () => a3});

let a4 = "💩";
Object.defineProperty(exports, "a4", {get: () => a4});

exports.default = {a1: a1, a2: a2, a3: a3, a4: a4};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "./a" */ "a");
exports.default = function() {
  console.log("Русский", "production",
              "релиз!");
}

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},

});
