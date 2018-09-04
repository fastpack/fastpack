
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
"$fp$runtime__omitProps": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("\n    var hasOwnProperty = Object.prototype.hasOwnProperty;\n\n    function omitProps(target, props) {\n      var ret = {};\n      for (var prop in target) {\n        if (hasOwnProperty.call(target, prop) && props.indexOf(prop) === -1) {\n          ret[prop] = target[prop];\n        }\n      }\n      return ret;\n    }\n\n    module.exports = omitProps;\n  \n//# sourceURL=fpack:///$fp$runtime__omitProps");
},
"builtin$$B$$esm": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\nexports.default = \"hello, world!\";\n\n//# sourceURL=fpack:///builtin!esm.js");
},
"builtin$$B$$index": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("const $fp$runtime__omitProps = __fastpack_require__(/* \"$fp$runtime__omitProps\" */ \"$fp$runtime__omitProps\");\nconst esm = __fastpack_require__(/* \"./esm\" */ \"builtin$$B$$esm\");\nconst {delimiter} = path,\n  rest = $fp$runtime__omitProps(path, [\"delimiter\"]);\nconsole.log(path, module, delimiter, rest, esm);\n// The following test makes sure that builtin transpiler strips type annotations\n// from inside JSX\nconst Component = props => React.createElement(\"div\", null, item => {\n    \n  }\n  );\n\n//# sourceURL=fpack:///builtin!index.js");
},
"$fp$main": function(module, exports, __fastpack_require__, __fastpack_import__) {
eval("module.exports.__esModule = true;\n__fastpack_require__(/* \"./index.js\" */ \"builtin$$B$$index\");\n\n\n\n//# sourceURL=fpack:///$fp$main");
},

});
