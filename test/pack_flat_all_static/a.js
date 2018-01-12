const b = require('./b');

module.exports = function() {
  console.log('b in a');
  b();
};
