
var process = {env: {NODE_ENV: 'production'}};
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

let $n__b;console.log('side effect of b');
$n__b = function() {console.log('b')};

/* a */

let $n__a;const $i__a__b = ($n__b);

$n__a = function() {
  console.log('b in a');
  $i__a__b();
};

/* index */

const $i__index__a = ($n__a);

(function() {
  __fastpack_import__($w__b).then(b => {
    console.log('b in promise');
    b();
  })

  let b = __fastpack_require__($w__b);
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

const $n__index = {};
function $w__b() {return $n__b;}
