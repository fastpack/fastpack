var __fastpack_cache__ = {};

function __fastpack_import__(f) {
  return new Promise((resolve, reject) => {
    try {
      if (__fastpack_cache__[f.name] === undefined) {
        __fastpack_cache__[f.name] = f();
      }
      resolve(__fastpack_cache__[f.name]);
    } catch (e) {
      reject(e);
    }
  });
}

/* index$$_$$dynamic */

let $n__index$$_$$dynamic = { id: "index$$_$$dynamic", exports: {}};
__fastpack_import__($w__dep$$_$$esm$$_$$named).then(named => {
  console.log(named);
});

try{$n__index$$_$$dynamic.exports.__esModule = $n__index$$_$$dynamic.exports.__esModule || false;}catch(_){}
module.exports = $n__index$$_$$dynamic.exports;

function $w__dep$$_$$esm$$_$$named() {

/* dep$$_$$esm$$_$$named */

let $n__dep$$_$$esm$$_$$named = { id: "dep$$_$$esm$$_$$named", exports: {}};
const $e__dep$$_$$esm$$_$$named__a = 1;
const $e__dep$$_$$esm$$_$$named__b = 2;

try{$n__dep$$_$$esm$$_$$named.exports.a = $e__dep$$_$$esm$$_$$named__a;
$n__dep$$_$$esm$$_$$named.exports.b = $e__dep$$_$$esm$$_$$named__b;
$n__dep$$_$$esm$$_$$named.exports.__esModule = $n__dep$$_$$esm$$_$$named.exports.__esModule || true;}catch(_){}

return $n__dep$$_$$esm$$_$$named.exports;
}
