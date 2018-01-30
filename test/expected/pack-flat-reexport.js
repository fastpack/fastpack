(function() {
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

/* b */

let $e__b__b = 1;

const $n__b = { exports: {b: $e__b__b} };

/* a */



const $n__a = { exports: {a: $e__b__b} };

/* index */



console.log($e__b__b);

const $n__index = { exports: {} };
})()
