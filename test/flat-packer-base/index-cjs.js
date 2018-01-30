const exportsPair = require('./dep-cjs-exports.js');
const { a, b } = require('./dep-cjs-exports.js');
const modulePair = require('./dep-cjs-module.js');

if (a < b) {
  console.log(a, b);
}
if (modulePair.a < modulePair.b) {
  console.log(modulePair);
}
if (exportsPair.a < exportsPair.b) {
  console.log(exportsPair);
}

exports.named = 'named';
