var __DEV__ = false;
var __fastpack_cache__ = {};

function __fastpack_require__(f) {
  if (__fastpack_cache__[f.name] === undefined) {
    __fastpack_cache__[f.name] = f();
  }
  return __fastpack_cache__[f.name];
}

function __fastpack_import__(f) {
  return new Promise((resolve, reject) => {
    try {
      resolve(__fastpack_require__(f));
    } catch (e) {
      reject(e);
    }
  });
}

/* a */

let $e__a__a = 1;
function $e__a__changeA() { $e__a__a = $e__a__a + 1};


const $n__a = { exports: {a: $e__a__a, changeA: $e__a__changeA} };

/* index */


let $e__index__index = 1;
const $e__index__default = function() {console.log('Hello, world!')};

const $n__index = { exports: {default: $e__index__default, index: $e__index__index, a: $e__a__a, changeA: $e__a__changeA} };
module.exports = $n__index.exports;
