export function d1() {
  let c;
  if(true) {
    c = import('./c');
  }
  else {
    c = import('././c');
  }
  return c;
}

export let d2 = d1;
