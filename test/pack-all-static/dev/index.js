
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
"b":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("console.log('side effect of b');\nmodule.exports = function() {console.log('b')};\n\n//# sourceURL=fpack:///b.js\n//# sourceURL=fpack:///b.js");
},
d: {}
},
"a":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const b = __fastpack_require__(\"./b\");\n\nmodule.exports = function() {\n  console.log('b in a');\n  b();\n};\n\n//# sourceURL=fpack:///a.js\n//# sourceURL=fpack:///a.js");
},
d: {"./b":"b"}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const a = __fastpack_require__(\"./a\");\n\n(function() {\n  __fastpack_import__(/* \"./b\").then(b => {\n    console.log('b in promise');\n    b();\n  })\n\n  let b = __fastpack_require__(\"./b\");\n  a();\n  console.log('b in index');\n  b();\n})();\n\n/*\n$ node <bundle.js>\nside effect of b\nb in a\nb\nb in index\nb\nb in promise\nb\n*/\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"./a":"a","./b":"b","./b":"b"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
