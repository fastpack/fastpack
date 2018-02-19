import * as namedPair from './dep-esm-named.js';
import { a, b } from './dep-esm-named.js';
import defaultPair from './dep-esm-default.js';

if (a < b) {
  console.log(a, b);
}
if (defaultPair.a < defaultPair.b) {
  console.log(defaultPair);
}
if (namedPair.a < namedPair.b) {
  console.log(namedPair);
}

export default 'default';
export const named = 'named';
