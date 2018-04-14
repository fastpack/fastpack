import * as ZModule from "./z";


let z = 1, zz = 1;
export {z, zz as Z};

export let x = 1, y = 2;

// export default function () {
//   x = 1;
// };
// export default class {};
export default class F {};

export function updateX() {
  x++;
  console.log('updated X', x);
}

export {default as X, a as xA, updateA} from "./y";
export {default as ZM} from "./z";
