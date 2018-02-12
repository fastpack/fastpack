(function() {
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

/* b */

let $n__b = { exports: {}};
console.log('side effect of b');
$n__b.exports = function() {console.log('b')};
$n__b.exports.__esModule = $n__b.exports.__esModule || false;

/* a */

let $n__a = { exports: {}};
const $i__a__b = ($n__b.exports);

$n__a.exports = function() {
  console.log('b in a');
  $i__a__b();
};
$n__a.exports.__esModule = $n__a.exports.__esModule || false;

/* index */

let $n__index = { exports: {}};
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
$n__index.exports.__esModule = $n__index.exports.__esModule || false;
function $w__b() {return $n__b.exports;}
})()
