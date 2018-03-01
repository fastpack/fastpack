
// This function is a modified version of the one created by the Webpack project
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

  // expose the modules object
  __fastpack_require__.m = modules;

  // expose the module cache
  __fastpack_require__.c = installedModules;

  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"NM$$file$$_$$loader$dist$cjsDOT$$js$$Q$$publicPath$$E$$DOT$$$$B$$logoDOT$$svg": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = "./5d5d9eefa31e5e13a6610d9fa7a283bb.svg";},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const $lib1 = __fastpack_require__(/* "file-loader?publicPath=./!./logo.svg" */ "NM$$file$$_$$loader$dist$cjsDOT$$js$$Q$$publicPath$$E$$DOT$$$$B$$logoDOT$$svg");
document.body.innerHTML = '<img src="' + $lib1 + '"/>';

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}
},

});
