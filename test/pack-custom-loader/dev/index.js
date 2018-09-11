
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
"custom$$_$$loaderDOT$$js$$B$$":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\ndocument.body.innerHTML = document.body.innerHTML\n+ \"<div>Source: \" + \"empty\" + \". Query: .</div>\";\nmodule.exports = {};\n  \n//# sourceURL=fpack:///custom-loader.js!\n//# sourceURL=fpack:///custom-loader.js!");
},
d: {}
},
"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\ndocument.body.innerHTML = document.body.innerHTML\n+ \"<div>Source: \" + \"empty\" + \". Query: ?bool=true.</div>\";\nmodule.exports = {};\n  \n//# sourceURL=fpack:///custom-loader.js?bool=true!\n//# sourceURL=fpack:///custom-loader.js?bool=true!");
},
d: {}
},
"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\ndocument.body.innerHTML = document.body.innerHTML\n+ \"<div>Source: \" + \"not empty\" + \". Query: ?bool=true.</div>\";\nmodule.exports = {};\n  \n//# sourceURL=fpack:///custom-loader.js?bool=true!index.js\n//# sourceURL=fpack:///custom-loader.js?bool=true!index.js");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./custom-loader!\");\n\n__fastpack_require__(\"./custom-loader?bool=true!\");\n\n__fastpack_require__(\"./custom-loader?bool=true!./index.js\");\n\n\n\n\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./custom-loader!":"custom$$_$$loaderDOT$$js$$B$$","./custom-loader?bool=true!":"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$","./custom-loader?bool=true!./index.js":"custom$$_$$loaderDOT$$js$$Q$$bool$$E$$true$$B$$index"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
