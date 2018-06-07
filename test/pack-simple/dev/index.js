
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
"z": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = 1;\n\n//# sourceURL=fpack:///z.js");
},
"y": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = 1;\n\nlet a = 1;;Object.defineProperty(exports, \"a\", {enumerable: true, get: function() {return a;}});\n\nfunction updateA (newA) {\n  a = newA;\n};Object.defineProperty(exports, \"updateA\", {enumerable: true, get: function() {return updateA;}});\n\n//# sourceURL=fpack:///y.js");
},
"yz": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nconst _1__z = __fastpack_require__(/* \"./z\" */ \"z\");Object.defineProperty(exports, \"Z\", {enumerable: true, get: function() {return _1__z;}});\nconst _2__y = __fastpack_require__(/* \"./y\" */ \"y\");Object.defineProperty(exports, \"a\", {enumerable: true, get: function() {return _2__y.a;}});Object.defineProperty(exports, \"updateA\", {enumerable: true, get: function() {return _2__y.updateA;}});\n\n//# sourceURL=fpack:///yz.js");
},
"yz_reimport": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__y = __fastpack_require__(/* \"./y\" */ \"y\");\nconst _2__z = __fastpack_require__(/* \"./z\" */ \"z\");\n\nexports.default = {a: _1__y.a, updateA: _1__y.updateA, Z: _2__z.default};\n\n//# sourceURL=fpack:///yz_reimport.js");
},
"cjs": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\nmodule.exports = function() {\n  console.log('cjs');\n}\n\n//# sourceURL=fpack:///cjs.js");
},
"x": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst ZModule = __fastpack_require__(/* \"./z\" */ \"z\");\n\n\nlet z = 1, zz = 1;\nObject.defineProperty(exports, \"z\", {enumerable: true, get: function() {return z;}});Object.defineProperty(exports, \"Z\", {enumerable: true, get: function() {return zz;}});\n\nlet x = 1, y = 2;;Object.defineProperty(exports, \"x\", {enumerable: true, get: function() {return x;}});Object.defineProperty(exports, \"y\", {enumerable: true, get: function() {return y;}});\n\n// export default function () {\n//   x = 1;\n// };\n// export default class {};\nclass F {}\nexports.default = F;\n;\n\nfunction updateX() {\n  x++;\n  console.log('updated X', x);\n};Object.defineProperty(exports, \"updateX\", {enumerable: true, get: function() {return updateX;}});\n\nconst _1__y = __fastpack_require__(/* \"./y\" */ \"y\");Object.defineProperty(exports, \"X\", {enumerable: true, get: function() {return _1__y.default;}});Object.defineProperty(exports, \"xA\", {enumerable: true, get: function() {return _1__y.a;}});Object.defineProperty(exports, \"updateA\", {enumerable: true, get: function() {return _1__y.updateA;}});\nObject.defineProperty(exports, \"ZM\", {enumerable: true, get: function() {return ZModule.default;}});\n\n//# sourceURL=fpack:///x.js");
},
"util": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__x = __fastpack_require__(/* \"./x\" */ \"x\");\n\n\nconst allX = _1__x;\nconst YZ = __fastpack_require__(/* \"./yz\" */ \"yz\");\n\nfunction xShouldRemain() {\n  let x = \"this is not updated\";\n  let updateX = () => console.log(x);\n}\n\nif(false) {\n  let x = \"this is not updated as well\";\n  let updateX = () => console.log(x);\n  updateX();\n}\n\nlet $lib1 = {};\nconsole.log($lib1.x);\n\nmodule.exports.sayHello = function() {\n  _1__x.default();\n  console.log(\"x before update\", _1__x.x);\n  _1__x.updateX();\n  console.log(\"x after update:\", _1__x.x);\n};\n\n//# sourceURL=fpack:///util.js");
},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./yz\" */ \"yz\");\n\n__fastpack_require__(/* \"./yz_reimport.js\" */ \"yz_reimport\");\n\nconst _1__cjs = __fastpack_require__(/* \"./cjs\" */ \"cjs\");const _1__cjs__default = _1__cjs.__esModule ? _1__cjs.default : _1__cjs;\n\nconst util = __fastpack_require__(/* \"./util\" */ \"util\");\n\nif (true) {\n  let yz = __fastpack_import__(/* \"./yz\" */ \"yz\");\n}\nelse {\n  _1__cjs__default();\n}\n\n\n//# sourceURL=fpack:///index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"index\");\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
