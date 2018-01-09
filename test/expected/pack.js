/* Entry point: index */
({
"z": function(module, exports, __fastpack_require__) {
exports.default = 1;
},
"y": function(module, exports, __fastpack_require__) {
exports.default = 1;

let a = 1;
Object.defineProperty(exports, "a", {get: () => a});


function updateA (newA) {
  a = newA;
}
Object.defineProperty(exports, "updateA", {get: () => updateA});

},
"yz": function(module, exports, __fastpack_require__) {

const $lib1 = __fastpack_require__(/* "./z" */ "z");
Object.defineProperty(exports, "Z", {get: () => $lib1});
const $lib2 = __fastpack_require__(/* "./y" */ "y");
Object.defineProperty(exports, "default", {get: () => $lib2.default}); Object.defineProperty(exports, "a", {get: () => $lib2.a}); Object.defineProperty(exports, "updateA", {get: () => $lib2.updateA});
},
"yz_reimport": function(module, exports, __fastpack_require__) {
const $lib1 = __fastpack_require__(/* "./y" */ "y");
const $lib2 = __fastpack_require__(/* "./z" */ "z");

exports.default = {a: $lib1.a, updateA: $lib1.updateA, Z: $lib2.default};
},
"x": function(module, exports, __fastpack_require__) {
const ZModule = __fastpack_require__(/* "./z" */ "z");


let z = 1, zz = 1;
Object.defineProperty(exports, "z", {get: () => z}); Object.defineProperty(exports, "Z", {get: () => zz});

let x = 1, y = 2;
Object.defineProperty(exports, "x", {get: () => x}); Object.defineProperty(exports, "y", {get: () => y});


// export default function () {
//   x = 1;
// };
// export default class {};
class F {}
exports.default = F;
;

function updateX() {
  x++;
  console.log('updated X', x);
}
Object.defineProperty(exports, "updateX", {get: () => updateX});


const $lib1 = __fastpack_require__(/* "./y" */ "y");
Object.defineProperty(exports, "X", {get: () => $lib1.default}); Object.defineProperty(exports, "xA", {get: () => $lib1.a}); Object.defineProperty(exports, "updateA", {get: () => $lib1.updateA});
Object.defineProperty(exports, "ZM", {get: () => ZModule.default});
},
"util": function(module, exports, __fastpack_require__) {
const $lib2 = __fastpack_require__(/* "./x" */ "x");


const allX = $lib2;
const YZ = __fastpack_require__(/* "./yz" */ "yz");

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
"index": function(module, exports, __fastpack_require__) {
__fastpack_require__(/* "./yz" */ "yz");

__fastpack_require__(/* "./yz_reimport.js" */ "yz_reimport");


const util = __fastpack_require__(/* "./util" */ "util");
if (true) {
  let yz = __fastpack_require__(/* "./yz" */ "yz");
}

},

})
