
/* a.js-8b777862f8f7f3bd5fbe46af31409e7b */


if (false) {
  let $_c1 = 100; // expect: let $_c1 = 100;
  a1 += $_c1; // expect: $_e1 += $_c1;
}

let $_e1 = 1; // expect: let $_e1 = 1;
let $_e2 = 2; // expect: let $_e2 = 2;

function $_i1($_c2) {return $_c2 + $_e1}; // expect: function $_i1($_c2) {return $_c2 + $_e1}

const $_e3 = {a1: $_e1, a2: $_e2};

/* index.js-a20aab43919e65bedc9837ef6de8bd2e */



console.log($_e3);


const $_e4 = {};
