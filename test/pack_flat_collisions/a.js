
if (false) {
  let $_e1 = 100; // expect: let $_c1 = 100;
  a1 += $_e1; // expect: $_e1 += $_c1;
}

export let a1 = 1; // expect: let $_e1 = 1;
export let a2 = 2; // expect: let $_e2 = 2;

function f($_e1) {return $_e1 + a1}; // expect: function $_i1($_c2) {return $_c2 + $_e1}
