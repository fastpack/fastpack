export let a1 = 1; // expect: let $_e1 = 1;
export let a2 = 2; // expect: let $_e2 = 2;

if (false) {
  let $_e1 = 100; // expect: let $_c1 = 100;
  a1 += $_e1; // expect: $_e1 += $_c1;
}


function f($_e1) {return $_e1 + a1}; // expect: function $_i1($_c2) {return $_c2 + $_e1}

for (var i = 0; i < 10; i++) {
  console.log(i);
}

let obj;
for(var k in obj) {
  console.log(k);
}
for(var p of obj) {
  console.log(p);
  let $_w1;
  for (let {a,b,c, $_c2} of p) {
    console.log(a, b, c, $_c2);
  }
  for ({$_w1} of p) {
    console.log($_w1);
  }
}

for(let {$_i1, $_i2} = {$_i1 : 1, $_i2: 2};;)
  console.log($_i1, $_i2);
