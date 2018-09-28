
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
"NM$$raw$$_$$loader$indexDOT$$js$$B$$testDOT$$txt":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports = \"Hello, world!\\n\\nLorem Ipsum is simply dummy text of the printing and typesetting industry.\\nLorem Ipsum has been the industry's standard dummy text ever since the 1500s,\\nwhen an unknown printer took a galley of type and scrambled it to make a type\\nspecimen book. It has survived not only five centuries, but also the leap into\\nelectronic typesetting, remaining essentially unchanged. It was popularised in\\nthe 1960s with the release of Letraset sheets containing Lorem Ipsum passages,\\nand more recently with desktop publishing software like Aldus PageMaker\\nincluding versions of Lorem Ipsum.\\n\"\n//# sourceURL=fpack:///node_modules/raw-loader/index.js!test.txt\n//# sourceURL=fpack:///node_modules/raw-loader/index.js!test.txt");
},
d: {}
},
"index":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nconst _1_raw_loader_test_txt = __fastpack_require__(\"raw-loader!./test.txt\");\n\n\ndocument.body.innerHTML = `\n<h1>test.txt</h1>\n<pre>${(__fastpack_require__.default(_1_raw_loader_test_txt))}</pre>\n`;\n\n//# sourceURL=fpack:///index.js\n//# sourceURL=fpack:///index.js");
},
d: {"raw-loader!./test.txt":"NM$$raw$$_$$loader$indexDOT$$js$$B$$testDOT$$txt"}
},
"$fp$main":{m:function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(\"./index.js\");\n\n\n\n//# sourceURL=fpack:///$fp$main\n//# sourceURL=fpack:///$fp$main");
},
d: {"./index.js":"index"}
},

});
