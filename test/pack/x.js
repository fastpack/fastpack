

export let x = 1;

// export default function () {
//   x = 1;
// };
// export default class {};
export default class F {};

export function updateX() {
  x++;
  console.log('updated X', x);
}
