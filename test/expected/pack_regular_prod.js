
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
"prod": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = {prod: true};

},
"dev": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = {dev: true};

},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {

let p;

// if-then-no-else
p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

{}

{}

{}

{}

// if-then-else
p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");

p = __fastpack_require__(/* "./prod" */ "prod");


// alternative statement
p = __fastpack_require__(/* "./prod" */ "prod");

// logical AND expression
if ("production" == "production" && x && y && z)
  p = __fastpack_require__(/* "./prod" */ "prod");
else
  p = __fastpack_require__(/* "./dev" */ "dev");

// conditional operator
p = __fastpack_require__(/* "./prod" */ "prod");
console.log("production");

// bug
if (true) {} else {console.log("prod!")}
if (false) {} else {}

// bug
Image.propTypes = {});

},

});
