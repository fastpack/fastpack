
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
  return __fastpack_require__(__fastpack_require__.s = '$fp$main');
})
({
"custom$$_$$loaderDOT$$js$$B$$": function(module, exports, __fastpack_require__, __fastpack_import__) {

document.body.innerHTML = document.body.innerHTML
+ "<div>Source: " + "empty" + ". Query: .</div>";
module.exports = {};
  
},
"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$": function(module, exports, __fastpack_require__, __fastpack_import__) {

document.body.innerHTML = document.body.innerHTML
+ "<div>Source: " + "empty" + ". Query: ?bool=true.</div>";
module.exports = {};
  
},
"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {

document.body.innerHTML = document.body.innerHTML
+ "<div>Source: " + "not empty" + ". Query: ?bool=true.</div>";
module.exports = {};
  
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./custom-loader!" */ "custom$$_$$loaderDOT$$js$$B$$");

__fastpack_require__(/* "./custom-loader?bool=true!" */ "custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$");

__fastpack_require__(/* "./custom-loader?bool=true!./index.js" */ "custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$index");


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./index.js" */ "index");


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
