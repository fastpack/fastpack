import babelTranspile from './babel-transpile.js';
import builtinTranspile from './builtin-transpile.js';

export default function () {
  console.log('package-1')
  console.log(babelTranspile, builtinTranspile)
}
