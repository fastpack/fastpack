
var process = {env: {NODE_ENV: 'production'}};
var __fastpack_cache__ = {};
function __fastpack_require__(f) {
  if (__fastpack_cache__[f.name] === undefined) {
    __fastpack_cache__[f.name] = f();
  }
  return __fastpack_cache__[f.name];
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
  let b = __fastpack_require__($w__b);
  $i__index__a();
  console.log('b in index');
  b();
})();

const $n__index = {};
function $w__b() {return $n__b;}
