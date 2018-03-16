
// This function is a modified version of the one created by the Webpack project
global = window;
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
"NM$$raw$$_$$loader$indexDOT$$js$$B$$testDOT$$txt": function(module, exports, __fastpack_require__, __fastpack_import__) {
module.exports = "Hello, world!\n\nLorem Ipsum is simply dummy text of the printing and typesetting industry.\nLorem Ipsum has been the industry's standard dummy text ever since the 1500s,\nwhen an unknown printer took a galley of type and scrambled it to make a type\nspecimen book. It has survived not only five centuries, but also the leap into\nelectronic typesetting, remaining essentially unchanged. It was popularised in\nthe 1960s with the release of Letraset sheets containing Lorem Ipsum passages,\nand more recently with desktop publishing software like Aldus PageMaker\nincluding versions of Lorem Ipsum.\n"
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
const _raw_loader_test_txt = __fastpack_require__(/* "raw-loader!./test.txt" */ "NM$$raw$$_$$loader$indexDOT$$js$$B$$testDOT$$txt");

document.body.innerHTML = `
<h1>test.txt</h1>
<pre>${_raw_loader_test_txt}</pre>
`;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
