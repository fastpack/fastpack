open Util

let%expect_test "print-with-scope.js" =
  test (print ~with_scope:true) "print-with-scope.js";
  [%expect_exact {|/* SCOPE: 
A -> Import A from 'namedTest' [3:8 - 3:9]
C -> Import B from 'namedTest' [3:16 - 3:17]
F -> Function [7:9 - 7:10]
S -> Function [62:9 - 62:10]
X -> Import default from 'defaultTest' [1:7 - 1:8]
Y -> Import * from 'namespaceTest' [2:12 - 2:13]
a -> Var [exported as a] [5:4 - 5:5]
a1 -> Var [exported as A1] [16:6 - 16:8]
b -> Let [6:4 - 6:5]
doSomethingUseful -> Function [exported as default] [40:24 - 40:41]
exportC -> Class [exported as exportC] [34:13 - 34:20]
exportF -> Function [exported as exportF] [33:16 - 33:23]
exportVar -> Let [exported as exportVar] [35:11 - 35:20]
f -> Let [10:4 - 10:5]
f1 -> Let [11:4 - 11:6]
z11 -> Let [42:9 - 42:12]
z2 -> Let [42:14 - 42:16]
z3 -> Let [42:18 - 42:20]
 */
import X from "defaultTest";
import * as Y from "namespaceTest";
import {A, B as C} from "namedTest";
var a = 1;
let b = 2;
function F(a, b, c)/* SCOPE: a -> Argument [7:11 - 7:12], b -> Argument [7:14 - 7:15], c -> Argument [7:17 - 7:18] */ {/* SCOPE: c -> Let [8:6 - 8:7] */

  let c = 2;
  
}
let f = (x, y, z)/* SCOPE: x -> Argument [10:9 - 10:10], y -> Argument [10:11 - 10:12], z -> Argument [10:13 - 10:14] */ => x + y + z;
let f1 = (x, y, z)/* SCOPE: x -> Argument [11:10 - 11:11], y -> Argument [11:12 - 11:13], z -> Argument [11:14 - 11:15] */ => {/* SCOPE:  */
  
    return x;
    
  }
  ;
if (true) {/* SCOPE: 
C -> Class [20:8 - 20:9]
b1 -> Let [18:6 - 18:8]
 */

  // should be in the program scope
  var a1 = 2;
  // should not be in program scope
  let b1 = 2;
  class C {
    constructor(prop1, ...props)/* SCOPE: prop1 -> Argument [21:16 - 21:21], props -> Argument [21:26 - 21:31] */ {/* SCOPE: a2 -> Var [23:10 - 23:12] */
    
      super();
      var a2 = 1;
      
    }
    
  }
}for (let i = 0, l = 10; i < l; i++)/* SCOPE: i -> Let [28:8 - 28:9], l -> Let [28:15 - 28:16] */
  {/* SCOPE: j -> Let [30:6 - 30:7] */
  
    console.log(i);
    let j = 1;
    
  }
export function exportF()/* SCOPE:  */ {/* SCOPE:  */

  
}
;
export class exportC {
  
};
export let exportVar = 25;
;
export { a, a1 as A1 };
// re-exports are not getting into scope
export { reexp1, reexp2 as Reexp2 } from "./other";
export default function doSomethingUseful()/* SCOPE:  */ {/* SCOPE:  */

  
}
;
let {z1: z11, z2, z3} = {};
for (let p in {a: 1})/* SCOPE: p -> Let [45:9 - 45:10] */
  {/* SCOPE:  */
  
    console.log(p);
    
  }
for (let p of {a: 1})/* SCOPE: p -> Let [49:9 - 49:10] */
  {/* SCOPE:  */
  
    console.log(p);
    
  }
try {/* SCOPE: a -> Let [54:6 - 54:7] */

  let a = 1;
  throw "test";
  
} catch ({e1, e2, ...e3}) {/* SCOPE: 
e1 -> Let [56:9 - 56:11]
e2 -> Let [56:13 - 56:15]
e3 -> Let [56:20 - 56:22]
 */

  console.log(e1, e2, e3);
  
} finally {/* SCOPE: f -> Let [59:6 - 59:7] */

  let f = 1;
  
}
function S()/* SCOPE:  */ {/* SCOPE: S1 -> Var [63:6 - 63:8] */

  var S1 = 1;
  
}
(function ()/* SCOPE:  */ {/* SCOPE: SS1 -> Var [67:6 - 67:9] */

  var SS1 = 1;
  
}
)();
|}]
