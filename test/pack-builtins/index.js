const path = require('path');
const module = require('module');
const esm = require('./esm');

const {delimiter, ...rest} = path;

console.log(path, module, delimiter, rest, esm);
