
global = this;
process = { env: {}, browser: true };
if(!global.Buffer) {
  global.Buffer = {isBuffer: false};
}
// This function is a modified version of the one created by the Webpack project
(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(fromModule, request) {
    var moduleId = fromModule === null ? request : modules[fromModule].d[request];

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

    var r = __fastpack_require__.bind(null, moduleId);
    r.default = __fastpack_require__.default;
    r.omitDefault = __fastpack_require__.omitDefault;
    // Execute the module function
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      r,
      __fastpack_import__.bind(null, moduleId)
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(fromModule, request) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(fromModule, request));
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
  __fastpack_require__.default = function(exports) {
    return exports.__esModule ? exports.default : exports;
  }
  return __fastpack_require__(null, __fastpack_require__.s = '$fp$main');
})
({
/* !s: yz_reimport.js */
"yz_reimport":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__y = __fastpack_require__(\"./y\");\nconst _2__z = __fastpack_require__(\"./z\");\n\n\n\nexports.default = {a: _1__y.a, updateA: _1__y.updateA, Z: (__fastpack_require__.default(_2__z))};\n\n//# sourceURL=fpack:///yz_reimport.js\n//# sourceURL=fpack:///yz_reimport.js");
},
d: {"./y":"y","./z":"z"}
},
/* !s: cjs.js */
"cjs":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\nmodule.exports = function() {\n  console.log('cjs');\n}\n\n//# sourceURL=fpack:///cjs.js\n//# sourceURL=fpack:///cjs.js");
},
d: {}
},
/* !s: x.js */
"x":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst ZModule = __fastpack_require__(\"./z\");\n\n\n\nlet z = 1, zz = 1;\nObject.defineProperty(exports, \"z\", {enumerable: true, get: function() {return z;}});Object.defineProperty(exports, \"Z\", {enumerable: true, get: function() {return zz;}});\n\nlet x = 1, y = 2;;Object.defineProperty(exports, \"x\", {enumerable: true, get: function() {return x;}});Object.defineProperty(exports, \"y\", {enumerable: true, get: function() {return y;}});\n\n// export default function () {\n//   x = 1;\n// };\n// export default class {};\nclass F {}\nexports.default = F;\n;\n\nfunction updateX() {\n  x++;\n  console.log('updated X', x);\n};Object.defineProperty(exports, \"updateX\", {enumerable: true, get: function() {return updateX;}});\n\nconst _1__y = __fastpack_require__(\"./y\");Object.defineProperty(exports, \"X\", {enumerable: true, get: function() {return (__fastpack_require__.default(_1__y));}});Object.defineProperty(exports, \"xA\", {enumerable: true, get: function() {return _1__y.a;}});Object.defineProperty(exports, \"updateA\", {enumerable: true, get: function() {return _1__y.updateA;}});\nObject.defineProperty(exports, \"ZM\", {enumerable: true, get: function() {return (__fastpack_require__.default(ZModule));}});\n\n//# sourceURL=fpack:///x.js\n//# sourceURL=fpack:///x.js");
},
d: {"./z":"z","./y":"y","./z":"z"}
},
/* !s: z.js */
"z":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = 1;\n\n//# sourceURL=fpack:///z.js\n//# sourceURL=fpack:///z.js");
},
d: {}
},
/* !s: y.js */
"y":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = 1;\n\nlet a = 1;;Object.defineProperty(exports, \"a\", {enumerable: true, get: function() {return a;}});\n\nfunction updateA (newA) {\n  a = newA;\n};Object.defineProperty(exports, \"updateA\", {enumerable: true, get: function() {return updateA;}});\n\n//# sourceURL=fpack:///y.js\n//# sourceURL=fpack:///y.js");
},
d: {}
},
/* !s: yz.js */
"yz":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nconst _1__z = __fastpack_require__(\"./z\");Object.defineProperty(exports, \"Z\", {enumerable: true, get: function() {return _1__z;}});\nconst _2__y = __fastpack_require__(\"./y\");Object.assign(module.exports, __fastpack_require__.omitDefault(_2__y));\n\n//# sourceURL=fpack:///yz.js\n//# sourceURL=fpack:///yz.js");
},
d: {"./z":"z","./y":"y"}
},
/* !s: util.js */
"util":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__x = __fastpack_require__(\"./x\");\nconst allX = _1__x;\nconst YZ = __fastpack_require__(\"./yz\");\n\n\n\n\n\n\nfunction xShouldRemain() {\n  let x = \"this is not updated\";\n  let updateX = () => console.log(x);\n}\n\nif(false) {\n  let x = \"this is not updated as well\";\n  let updateX = () => console.log(x);\n  updateX();\n}\n\nlet $lib1 = {};\nconsole.log($lib1.x);\n\nmodule.exports.sayHello = function() {\n  (__fastpack_require__.default(_1__x))();\n  console.log(\"x before update\", _1__x.x);\n  _1__x.updateX();\n  console.log(\"x after update:\", _1__x.x);\n};\n\n//# sourceURL=fpack:///util.js\n//# sourceURL=fpack:///util.js");
},
d: {"./x":"x","./x":"x","./x":"x","./x":"x","./yz":"yz"}
},
/* !s: index.js */
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./yz\");\n\n__fastpack_require__(\"./yz_reimport.js\");\n\nconst _1__cjs = __fastpack_require__(\"./cjs\");\n\n\n\n\nconst util = __fastpack_require__(\"./util\");\n\nif (true) {\n  let yz = __fastpack_import__(\"./yz\");\n}\nelse {\n  (__fastpack_require__.default(_1__cjs))();\n}\n\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./yz":"yz","./yz_reimport.js":"yz_reimport","./cjs":"cjs","./util":"util","./yz":"yz"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
