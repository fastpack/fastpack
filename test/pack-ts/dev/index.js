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

  return __fastpack_require__(__fastpack_require__.s = 'NM$$ts$$_$$loader$indexDOT$$js$$B$$indexDOT$$ts');
})
({
"NM$$ts$$_$$loader$indexDOT$$js$$B$$renderDOT$$ts": function(module, exports, __fastpack_require__, __fastpack_import__) {
"use strict";
function render() {
    document.body.innerHTML = "<h1> Hello World from TypeScript!</h1>";
}
module.exports = render;
},
"NM$$ts$$_$$loader$indexDOT$$js$$B$$indexDOT$$ts": function(module, exports, __fastpack_require__, __fastpack_import__) {
"use strict";
exports.__esModule = true;
var render = __fastpack_require__(/* "./render.ts" */ "NM$$ts$$_$$loader$indexDOT$$js$$B$$renderDOT$$ts");
render();

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},

});
