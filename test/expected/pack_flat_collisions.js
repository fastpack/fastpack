
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
  for (let {a,b,c, $c__a__$c__2} of $i__a__p) {
    console.log(a, b, c, $c__a__$c__2);
  }
  for ({$w__1} of $i__a__p) {
    console.log($c__a__$w__1);
  }
}

for(let {$c__a__$i__1, $c__a__$i__2} = {$_i1 : 1, $_i2: 2};;)
  console.log($_i1, $_i2);

const $n__a = {a1: $e__a__a1, a2: $e__a__a2};

/* index */



console.log($n__a);


const $n__index = {};
