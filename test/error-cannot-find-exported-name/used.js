import {a, b} from "./a";
// b is not exported from './a', so this fails even with --export-check-used-imports-only
console.log(a, b);
