import X from "defaultTest";
import * as Y from "namespaceTest";
import {A, B as C} from "namedTest";

var a = 1;
let b = 2;
function F(a, b, c) {
  let c = 2;
};
let f = (x,y,z) => x + y + z;
let f1 = (x,y,z) => {
  return x;
};
if (true) {
  // should be in the program scope
  var a1 = 2;
  // should not be in program scope
  let b1 = 2;

  class C {
    constructor(prop1, ...props) {
      super();
      var a2 = 1;
    }
  }
}

for(let i = 0, l = 10; i < l; i++) {
  console.log(i);
  let j = 1;
}

export function exportF() {};
export class exportC {};
export let exportVar = 25;
export {a, a1 as A1};
// re-exports are not getting into scope
export {reexp1, reexp2 as Reexp2} from "./other";

export default function doSomethingUseful() {};

let {z1: z11, z2, z3} = {};


for (let p in {a: 1}) {
  console.log(p);
}

for (let p of {a: 1}) {
  console.log(p);
}

try {
  let a = 1;
  throw "test";
} catch({e1, e2, ...e3}) {
  console.log(e1, e2, e3);
} finally {
  let f = 1;
}

function S() {
  var S1 = 1;
}

(function() {
  var SS1 = 1;
})();
