const a = require('./a');

(function() {
  let b = require('./b');
  a();
  console.log('b in index');
  b();
})();
