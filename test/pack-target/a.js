export let a = 1;
function f() { a = a + 1};
export {f as changeA};
