
var __DEV__ = true;
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
"dev": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = {dev: true};
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {

let p;

// if-then-no-else








p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

// if-then-else
p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");

p = __fastpack_require__(/* "./dev" */ "dev");


// alternative statement
p = __fastpack_require__(/* "./dev" */ "dev");

// logical AND expression
p = __fastpack_require__(/* "./dev" */ "dev");

// conditional operator
p = __fastpack_require__(/* "./dev" */ "dev");
console.log("development");
},

});
