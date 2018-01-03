
let cInternal1 = 100;
let cInternal2 = 200;

function c1() {
  let b = require('./b');
  let cInternal2 = 300;
  return b.b1() + b.b2() + cInternal1 + cInternal2;
}

function c2() {
  let b = require('./b');
  return b.default.b1() + b.default.b2() + cInternal2;
}

function c3() {
  ({cInternal1, cInternal2} = {cInternal1: cInternal2, cInternal2: cInternal1});
  [cInternal1, cInternal2] = [1,2];
  cInternal1 = null;
}

Object.assign(module.exports, {c1, c2, c3});
