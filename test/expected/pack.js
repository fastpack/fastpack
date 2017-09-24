/* Entry point: d31116a79821b0cf41ac93abe249fc4d */
({
"e575b1ec1676ae03493e1f7e4fcfec56": function(module, exports, __fastpack_require__) {


export let x = 1;

export default function () {
  x = 1;
};

export function updateX() {
  x++;
  console.log('updated X', x);
}
},
"8a3f3828d61694d58796e8412f7d4141": function(module, exports, __fastpack_require__) {
const $lib2 = __fastpack_require__(/* "./x" */ "e575b1ec1676ae03493e1f7e4fcfec56");


const allX = $lib2;

function xShouldRemain() {
  let x = "this is not updated";
  let updateX = () => console.log(x);
}

if(false) {
  let x = "this is not updated as well";
  let updateX = () => console.log(x);
  updateX();
}

let $lib1 = {};
console.log($lib1.x);

module.exports.sayHello = function() {
  $lib2.default();
  console.log("x before update", $lib2.x);
  $lib2.updateX();
  console.log("x after update:", $lib2.x);
};
},
"d31116a79821b0cf41ac93abe249fc4d": function(module, exports, __fastpack_require__) {
const util = __fastpack_require__(/* "./util" */ "8a3f3828d61694d58796e8412f7d4141");
},

})
