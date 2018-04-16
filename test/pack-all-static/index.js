const a = require('./a');

(function() {
  import('./b').then(b => {
    console.log('b in promise');
    b();
  })

  let b = require('./b');
  a();
  console.log('b in index');
  b();
})();

/*
$ node <bundle.js>
side effect of b
b in a
b
b in index
b
b in promise
b
*/
