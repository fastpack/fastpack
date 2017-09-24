/* SCOPE: 
A -> Import A from 'namedTest'
C -> Import B from 'namedTest'
F -> Function
X -> Import default from 'defaultTest'
Y -> Import * from 'namespaceTest'
a -> Var
a1 -> Var
b -> Let
f -> Let
f1 -> Let
 */
import X from "defaultTest";
import * as Y from "namespaceTest";
import {A, B as C} from "namedTest";
var a = 1;
let b = 2;
function F(a, b, c) {
  /* SCOPE: 
  a -> Argument
  b -> Argument
  c -> Let
   */
  let c = 2
};
;
let f = (x, y, z) =>  /* SCOPE: x -> Argument, y -> Argument, z -> Argument */x + y + z;
let f1 = (x, y, z) =>  {
    /* SCOPE: 
    x -> Argument
    y -> Argument
    z -> Argument
     */
    return x
  };
if (true) {
  /* SCOPE: 
  C -> Class
  b1 -> Let
   */
  // should be in the program scope
  var a1 = 2;
  // should not be in program scope
  let b1 = 2;
  class C {
    constructor(prop1 ...props) {
      /* SCOPE: 
      a2 -> Var
      prop1 -> Argument
      props -> Argument
       */
      super();
      var a2 = 1
    }
  }
};
for (let i = 0, l = 10; i < l; i++)/* SCOPE: i -> Let, l -> Let */
  {
    /* SCOPE: j -> Let */
    console.log(i);
    let j = 1
  }
;
