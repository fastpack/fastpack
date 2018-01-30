const namedPair = require('./dep-esm-named.js');
const { a, b } = require('./dep-esm-named.js');
const defaultPair = require('./dep-esm-default.js');

if (a < b) {
  console.log(a, b);
}
if (defaultPair.a < defaultPair.b) {
  console.log(defaultPair);
}
if (namedPair.a < namedPair.b) {
  console.log(namedPair);
}
