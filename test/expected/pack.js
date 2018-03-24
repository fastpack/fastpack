
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
  return __fastpack_require__(__fastpack_require__.s = 'index');
})
({
"z": function(module, exports, __fastpack_require__, __fastpack_import__) {
exports.default = 1;

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"y": function(module, exports, __fastpack_require__, __fastpack_import__) {
exports.default = 1;

let a = 1;
Object.defineProperty(exports, "a", {get: function() {return a;}});


function updateA (newA) {
  a = newA;
}
Object.defineProperty(exports, "updateA", {get: function() {return updateA;}});


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"yz": function(module, exports, __fastpack_require__, __fastpack_import__) {

const _1__z = __fastpack_require__(/* "./z" */ "z");Object.defineProperty(exports, "Z", {get: function() {return _1__z;}});
const _2__y = __fastpack_require__(/* "./y" */ "y"); Object.defineProperty(exports, "a", {get: function() {return _2__y.a;}}); Object.defineProperty(exports, "updateA", {get: function() {return _2__y.updateA;}});

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"yz_reimport": function(module, exports, __fastpack_require__, __fastpack_import__) {
const _1__y = __fastpack_require__(/* "./y" */ "y");
const _2__z = __fastpack_require__(/* "./z" */ "z");

exports.default = {a: _1__y.a, updateA: _1__y.updateA, Z: _2__z.default};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"cjs": function(module, exports, __fastpack_require__, __fastpack_import__) {

module.exports = function() {
  console.log('cjs');
}

},
"x": function(module, exports, __fastpack_require__, __fastpack_import__) {
const ZModule = __fastpack_require__(/* "./z" */ "z");


let z = 1, zz = 1;
Object.defineProperty(exports, "z", {get: function() {return z;}}); Object.defineProperty(exports, "Z", {get: function() {return zz;}});

let x = 1, y = 2;
Object.defineProperty(exports, "x", {get: function() {return x;}}); Object.defineProperty(exports, "y", {get: function() {return y;}});


// export default function () {
//   x = 1;
// };
// export default class {};
class F {}
exports.default = F;
;

function updateX() {
  x++;
  console.log('updated X', x);
}
Object.defineProperty(exports, "updateX", {get: function() {return updateX;}});


const _1__y = __fastpack_require__(/* "./y" */ "y");Object.defineProperty(exports, "X", {get: function() {return _1__y.default;}}); Object.defineProperty(exports, "xA", {get: function() {return _1__y.a;}}); Object.defineProperty(exports, "updateA", {get: function() {return _1__y.updateA;}});
Object.defineProperty(exports, "ZM", {get: function() {return ZModule.default;}});

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"util": function(module, exports, __fastpack_require__, __fastpack_import__) {
const _1__x = __fastpack_require__(/* "./x" */ "x");


const allX = _1__x;
const YZ = __fastpack_require__(/* "./yz" */ "yz");

function xShouldRemain() {
  let x = "this is not updated";
  let updateX = () => console.log(x);
}

if(false) {
  let x = "this is not updated as well";
  let updateX = () => console.log(x);
  updateX();
}

let $lib1 = {};
console.log($lib1.x);

module.exports.sayHello = function() {
  _1__x.default();
  console.log("x before update", _1__x.x);
  _1__x.updateX();
  console.log("x after update:", _1__x.x);
};

try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},
"index": function(module, exports, __fastpack_require__, __fastpack_import__) {
__fastpack_require__(/* "./yz" */ "yz");

__fastpack_require__(/* "./yz_reimport.js" */ "yz_reimport");

const _1__cjs = __fastpack_require__(/* "./cjs" */ "cjs");const _1__cjs__default = _1__cjs.__esModule ? _1__cjs.default : _1__cjs;

const util = __fastpack_require__(/* "./util" */ "util");

if (true) {
  let yz = __fastpack_import__(/* "./yz" */ "yz");
}
else {
  _1__cjs__default();
}


try {module.exports.__esModule = module.exports.__esModule || true}catch(_){}

},

});
