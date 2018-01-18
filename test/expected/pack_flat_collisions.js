
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

/* a */

let $e__a__a1 = 1;
let $e__a__a2 = 2;

if (false) {
  let $c__a__$e__a__a1 = 100;
  $e__a__a1 += $c__a__$e__a__a1;
}


function $i__a__f($c__a__$e__a__a1) {return $c__a__$e__a__a1 + $i__a__f($e__a__a1)};

for (var $i__a__i = 0; $i__a__i < 10; $i__a__i++) {
  console.log($i__a__i);
}

let $i__a__obj;
for(var $i__a__k in $i__a__obj) {
  console.log($i__a__k);
}
for(var $i__a__p of $i__a__obj) {
  console.log($i__a__p);
  let $c__a__$w__1;
  for (let {a,b,c, $c__2: $c__a__$c__2} of $i__a__p) {
    console.log(a, b, c, $c__a__$c__2);
  }
  for ({$w__1: $c__a__$w__1} of $i__a__p) {
    console.log($c__a__$w__1);
  }
}

for(let {$i__1: $c__a__$i__1, $i__2: $c__a__$i__2} = {$_i1 : 1, $_i2: 2};;)
  console.log($_i1, $_i2);

function $i__a__g({$w__1: $c__a__$w__1, $c__2: $c__a__$c__2, ...$c__a__$e__3}) {
  return Object.assign($c__a__$e__3, {x: $c__a__$w__1 + $c__a__$c__2});
}

try {
  $i__a__g();
}
catch({$w__x: $c__a__$w__x, ...$c__a__$c__y}) {
  console.log($c__a__$w__x, $c__a__$c__y);
}

const $n__a = { exports: {a1: $e__a__a1, a2: $e__a__a2} };

/* index */



console.log($n__a.exports);


const $n__index = { exports: {} };
})()
