

export let x = 1;

export default function () {
  x = 1;
};

export function updateX() {
  x++;
  console.log('updated X', x);
}
