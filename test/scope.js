var a = 1;
let b = 2;
function F(a, b, c) {
  let c = 2;
};
let f = (x,y,z) => x + y + z;
let f1 = (x,y,z) => {
  return x;
};
if (true) {
  // should be in the program scope
  var a1 = 2;
  // should not be in program scope
  let b1 = 2;

  class C {}
}
