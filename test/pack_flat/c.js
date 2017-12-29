
let cInternal1 = 100;
let cInternal2 = 200;

function c1() {
  let b = require('./b');
  return b.b1() + b.b2() + cInternal1;
}

function c2() {
  let b = require('./b');
  return b.default.b1() + b.default.b2() + cInternal2;
}

Object.assign(module.exports, {c1, c2});
