
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
"b": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("console.log('side effect of b');\nmodule.exports = function() {console.log('b')};\n\n//# sourceURL=fpack:///b.js");
},
"a": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const b = __fastpack_require__(/* \"./b\" */ \"b\");\n\nmodule.exports = function() {\n  console.log('b in a');\n  b();\n};\n\n//# sourceURL=fpack:///a.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const a = __fastpack_require__(/* \"./a\" */ \"a\");\n\n(function() {\n  __fastpack_import__(/* \"./b\" */ \"b\").then(b => {\n    console.log('b in promise');\n    b();\n  })\n\n  let b = __fastpack_require__(/* \"./b\" */ \"b\");\n  a();\n  console.log('b in index');\n  b();\n})();\n\n/*\n$ node <bundle.js>\nside effect of b\nb in a\nb\nb in index\nb\nb in promise\nb\n*/\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
