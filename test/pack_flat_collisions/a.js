
if (false) {
  let $_e1 = 100; // expect: let $_i1 = 100;
  a1 += $_i1; // expect: $_e1 += $_i1;
}

export let a1 = 1; // expect: let $_e1 = 1;
export let a2 = 2; // expect: let $_e2 = 2;

function f($_e1) {return $_e1 + a1}; // expect: function $_i3($_i2) {return $_i2 + $_e1}
