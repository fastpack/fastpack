export let a1 = 1;
export let a2 = 2;

if (false) {
  let $e__a__a1 = 100;
  a1 += $e__a__a1;
}


function f($e__a__a1) {return $e__a__a1 + f(a1)};

for (var i = 0; i < 10; i++) {
  console.log(i);
}

let obj;
for(var k in obj) {
  console.log(k);
}
for(var p of obj) {
  console.log(p);
  let $w__1;
  for (let {a,b,c, $c__2} of p) {
    console.log(a, b, c, $c__2);
  }
  for ({$w__1} of p) {
    console.log($w__1);
  }
}

for(let {$i__1, $i__2} = {$_i1 : 1, $_i2: 2};;)
  console.log($_i1, $_i2);
