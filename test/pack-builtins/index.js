const path = require('path');
const module = require('module');
const es6 = require('./es6');

const {delimiter, ...rest} = path;

console.log(path, module, delimiter, rest, es6);
