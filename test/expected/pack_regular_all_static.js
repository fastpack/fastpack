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
"b": function(module, exports, __fastpack_require__, __fastpack_import__) {
console.log('side effect of b');
module.exports = function() {console.log('b')};
},
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
const b = __fastpack_require__(/* "./b" */ "b");

module.exports = function() {
  console.log('b in a');
  b();
};
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const a = __fastpack_require__(/* "./a" */ "a");

(function() {
  __fastpack_import__(/* "./b" */ "b").then(b => {
    console.log('b in promise');
    b();
  })

  let b = __fastpack_require__(/* "./b" */ "b");
  a();
  console.log('b in index');
  b();
})();

/*
$ node <bundle.js>
side effect of b
b in a
b
b in index
b
b in promise
b
*/
},

});
