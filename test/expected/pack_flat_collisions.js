
/* a */

let $_e1 = 1; // expect: let $_e1 = 1;
let $_e2 = 2; // expect: let $_e2 = 2;

if (false) {
  let $_c1 = 100; // expect: let $_c1 = 100;
  $_e1 += $_c1; // expect: $_e1 += $_c1;
}


function $_i1($_c2) {return $_c2 + $_e1}; // expect: function $_i1($_c2) {return $_c2 + $_e1}

for (var $_i2 = 0; $_i2 < 10; $_i2++) {
  console.log($_i2);
}

let $_i3;
for(var $_i4 in $_i3) {
  console.log($_i4);
}
for(var $_i5 of $_i3) {
  console.log($_i5);
  let $_c3;
  for (let {a,b,c, $_c4} of $_i5) {
    console.log(a, b, c, $_c4);
  }
  for ({$_w1} of $_i5) {
    console.log($_c3);
  }
}

for(let {$_c5, $_c6} = {$_i1 : 1, $_i2: 2};;)
  console.log($_c5, $_c6);

const $_e3 = {a1: $_e1, a2: $_e2};

/* index */



console.log($_e3);


const $_e4 = {};
