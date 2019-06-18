import {a, b} from "./a";
// b is not exported from './a', but not used in the code
// - fails without additional flags
// - passes with --export-check-used-imports-only
console.log(a);
