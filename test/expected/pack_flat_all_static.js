(function() {
var __fastpack_cache__ = {};

function __fastpack_import__(f) {
  if (!window.Promise) {
    throw 'window.Promise is undefined, consider using a polyfill';
  }
  return new Promise(function(resolve, reject) {
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

/* b */

let $n__b = { id: "b", exports: {}};
console.log('side effect of b');
$n__b.exports = function() {console.log('b')};

try{$n__b.exports.__esModule = $n__b.exports.__esModule || false;}catch(_){}

/* a */

let $n__a = { id: "a", exports: {}};
const $i__a__b = ($n__b.exports);

$n__a.exports = function() {
  console.log('b in a');
  $i__a__b();
};

try{$n__a.exports.__esModule = $n__a.exports.__esModule || false;}catch(_){}

/* index */

let $n__index = { id: "index", exports: {}};
const $i__index__a = ($n__a.exports);

(function() {
  __fastpack_import__($w__b).then(b => {
    console.log('b in promise');
    b();
  })

  let b = ($n__b.exports);
  $i__index__a();
  console.log('b in index');
  b();
})();

/*
$ node <bundle.js>
side effect of b
b in a
b
b in index
b
b in promise
b
*/

try{$n__index.exports.__esModule = $n__index.exports.__esModule || false;}catch(_){}
function $w__b() {return $n__b.exports;}
})()
