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

  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"local$$_$$shim": function(module, exports, __fastpack_require__, __fastpack_import__) {
console.log('local-shim.js: ok')
},
"builtin$$COLON$$__empty_module__": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = {};},
"module$$_$$a$$_$$shim": function(module, exports, __fastpack_require__, __fastpack_import__) {
console.log('module-shim.js: ok');
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./local.js" */ "local$$_$$shim");
__fastpack_require__(/* "./ignore.js" */ "builtin$$COLON$$__empty_module__");
__fastpack_require__(/* "module-a" */ "module$$_$$a$$_$$shim");
},

});
