/* Entry point: index.js-d31116a79821b0cf41ac93abe249fc4d */
({
"z.js-9ac1a10900aa3f1c9a41b85a77459bd8": function(module, exports, __fastpack_require__) {
Object.defineProperty(exports, "default", {get: () => 1});
},
"y.js-236e9c0761015ee1871421a78316fb8e": function(module, exports, __fastpack_require__) {
Object.defineProperty(exports, "default", {get: () => 1});

let a = 1;
Object.defineProperty(exports, "a", {get: () => a});


function updateA (newA) {
  a = newA;
}
Object.defineProperty(exports, "updateA", {get: () => updateA});

},
"x.js-e575b1ec1676ae03493e1f7e4fcfec56": function(module, exports, __fastpack_require__) {
const ZModule = __fastpack_require__(/* "./z" */ "z.js-9ac1a10900aa3f1c9a41b85a77459bd8");


let z = 1, zz = 1;
Object.defineProperty(exports, "z", {get: () => z}); Object.defineProperty(exports, "Z", {get: () => zz});

let x = 1, y = 2;
Object.defineProperty(exports, "x", {get: () => x}); Object.defineProperty(exports, "y", {get: () => y});


// export default function () {
//   x = 1;
// };
// export default class {};
class F {}
Object.defineProperty(exports, "default", {get: () => F});
;

function updateX() {
  x++;
  console.log('updated X', x);
}
Object.defineProperty(exports, "updateX", {get: () => updateX});


const $lib1 = __fastpack_require__(/* "./y" */ "y.js-236e9c0761015ee1871421a78316fb8e");
Object.defineProperty(exports, "X", {get: () => $lib1.default}); Object.defineProperty(exports, "xA", {get: () => $lib1.a}); Object.defineProperty(exports, "updateA", {get: () => $lib1.updateA});
Object.defineProperty(exports, "ZM", {get: () => ZModule.default});
},
"yz.js-de84e93847b6569f34aa614a3ce78835": function(module, exports, __fastpack_require__) {

const $lib1 = __fastpack_require__(/* "./z" */ "z.js-9ac1a10900aa3f1c9a41b85a77459bd8");
Object.defineProperty(exports, "Z", {get: () => $lib1});
const $lib2 = __fastpack_require__(/* "./y" */ "y.js-236e9c0761015ee1871421a78316fb8e");
Object.defineProperty(exports, "a", {get: () => $lib2.a}); Object.defineProperty(exports, "updateA", {get: () => $lib2.updateA});
},
"util.js-8a3f3828d61694d58796e8412f7d4141": function(module, exports, __fastpack_require__) {
const $lib2 = __fastpack_require__(/* "./x" */ "x.js-e575b1ec1676ae03493e1f7e4fcfec56");


const allX = $lib2;
const YZ = __fastpack_require__(/* "./yz" */ "yz.js-de84e93847b6569f34aa614a3ce78835");

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
"index.js-d31116a79821b0cf41ac93abe249fc4d": function(module, exports, __fastpack_require__) {
__fastpack_require__(/* "./yz" */ "yz.js-de84e93847b6569f34aa614a3ce78835");


const util = __fastpack_require__(/* "./util" */ "util.js-8a3f3828d61694d58796e8412f7d4141");

},

})
