
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


const $n__a = {a: $e__a__a, changeA: $e__a__changeA};

/* index */


let $e__index__index = 1;
const $e__index__default = function() {console.log('Hello, world!')};

const $n__index = {default: $e__index__default, index: $e__index__index, a: $e__a__a, changeA: $e__a__changeA};
export default $e__index__default;
export {$e__index__index as index};
export {$e__a__a as a};
export {$e__a__changeA as changeA};
