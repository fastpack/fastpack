var dep = require("./dep");

function f(require) {
  return require("./dep");
}

function g() {
  var s = f(x => x);
  var dep2 = require("./dep");
  document.body.innerHTML = `Imported: ${dep.default} Imported: ${
    dep2.default
  } Untouched: ${s}`;
}

g();
