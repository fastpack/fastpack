
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
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
  return __fastpack_require__(null, __fastpack_require__.s = '$fp$main');
})
    ({
"logSourceDOT$$js$$B$$log1":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n\n  exports.default = function () {console.log(\"\\nexport default function() { console.log(1); }\\n\")};\n  \n//# sourceURL=fpack:///logSource.js!log1.js\n//# sourceURL=fpack:///logSource.js!log1.js");
},
d: {}
},
"builtin$$B$$log2":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = function () {\n  console.log(2);\n  \n}\n;\n\n//# sourceURL=fpack:///builtin!log2.js\n//# sourceURL=fpack:///builtin!log2.js");
},
d: {}
},
"builtin$$B$$log3":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = function () {\n  console.log(3);\n  \n}\n;\n\n//# sourceURL=fpack:///builtin!log3.js\n//# sourceURL=fpack:///builtin!log3.js");
},
d: {}
},
"builtin$$B$$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1__log1 = __fastpack_require__(\"./log1\");const _1__log1__default = _1__log1.__esModule ? _1__log1.default : _1__log1;\nconst _2__log2 = __fastpack_require__(\"./log2\");const _2__log2__default = _2__log2.__esModule ? _2__log2.default : _2__log2;\nconst _3__log3 = __fastpack_require__(\"./log3\");const _3__log3__default = _3__log3.__esModule ? _3__log3.default : _3__log3;\n\n\n\n_1__log1__default();\n_2__log2__default();\n_3__log3__default();\n\n//# sourceURL=fpack:///builtin!index.js\n//# sourceURL=fpack:///builtin!index.js");
},
d: {"./log1":"logSourceDOT$$js$$B$$log1","./log2":"builtin$$B$$log2","./log3":"builtin$$B$$log3"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"builtin$$B$$index"}
},

});
