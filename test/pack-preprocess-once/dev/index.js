
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
/* !s: log1.js */
"logSourceDOT$$js$$B$$log1":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\n  exports.default = function () {console.log(\"\\nexport default function() { console.log(1); }\\n\")};\n  \n//# sourceURL=fpack:///logSource.js!log1.js
},
d: {}
},
/* !s: log2.js */
"builtin$$B$$log2":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nexports.default = function() { console.log(2); }\n\n//# sourceURL=fpack:///builtin!log2.js
},
d: {}
},
/* !s: log3.js */
"builtin$$B$$log3":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\nexports.default = function() { console.log(3); }\n\n//# sourceURL=fpack:///builtin!log3.js
},
d: {}
},
/* !s: index.js */
"builtin$$B$$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__log1 = __fastpack_require__(\"./log1\");\nconst _2__log2 = __fastpack_require__(\"./log2\");\nconst _3__log3 = __fastpack_require__(\"./log3\");\n\n\n\n\n\n(__fastpack_require__.default(_1__log1))();\n(__fastpack_require__.default(_2__log2))();\n(__fastpack_require__.default(_3__log3))();\n\n//# sourceURL=fpack:///builtin!index.js
},
d: {"./log1":"logSourceDOT$$js$$B$$log1","./log2":"builtin$$B$$log2","./log3":"builtin$$B$$log3"}
},
/* !s: main */
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main
},
d: {"./index.js":"builtin$$B$$index"}
},

});
