import * as exportsPair from './dep-cjs-exports.js';
import { a, b } from './dep-cjs-exports.js';
import modulePair from './dep-cjs-module.js';

if (a < b) {
  console.log(a, b);
}
if (modulePair.a < modulePair.b) {
  console.log(modulePair);
}
if (exportsPair.a < exportsPair.b) {
  console.log(exportsPair);
}

export default 'default';
export const named = 'named';
