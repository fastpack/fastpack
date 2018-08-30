
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

    // Execute the module function
    modules[moduleId].m.call(
      module.exports,
      module,
      module.exports,
      __fastpack_require__.bind(null, moduleId),
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
"NM$$file$$_$$loader$dist$cjsDOT$$js$$Q$$publicPath$$E$$DOT$$$$$B$$logoDOT$$svg":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports = \"./5d5d9eefa31e5e13a6610d9fa7a283bb.svg\";\n//# sourceURL=fpack:///node_modules/file-loader/dist/cjs.js?publicPath=./!logo.svg\n//# sourceURL=fpack:///node_modules/file-loader/dist/cjs.js?publicPath=./!logo.svg");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1_file_loader_publicPath_logo_svg = __fastpack_require__(\"file-loader?publicPath=./!./logo.svg\");const _1_file_loader_publicPath_logo_svg__default = _1_file_loader_publicPath_logo_svg.__esModule ? _1_file_loader_publicPath_logo_svg.default : _1_file_loader_publicPath_logo_svg;\n\ndocument.body.innerHTML = '<img src=\"' + _1_file_loader_publicPath_logo_svg__default + '\"/>';\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"file-loader?publicPath=./!./logo.svg":"NM$$file$$_$$loader$dist$cjsDOT$$js$$Q$$publicPath$$E$$DOT$$$$$B$$logoDOT$$svg"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
