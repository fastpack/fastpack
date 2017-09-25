/* Entry point: d31116a79821b0cf41ac93abe249fc4d */
({
"9ac1a10900aa3f1c9a41b85a77459bd8": function(module, exports, __fastpack_require__) {
Object.assign(exports, {default: 1});
},
"236e9c0761015ee1871421a78316fb8e": function(module, exports, __fastpack_require__) {
Object.assign(exports, {default: 1});

let a = 1;
Object.assign(exports, {a: a});


function updateA (newA) {
  a = newA;
}
Object.assign(exports, {updateA: updateA});

},
"e575b1ec1676ae03493e1f7e4fcfec56": function(module, exports, __fastpack_require__) {
const ZModule = __fastpack_require__(/* "./z" */ "9ac1a10900aa3f1c9a41b85a77459bd8");


let z = 1, zz = 1;
Object.assign(exports, {z: z, Z: zz});

let x = 1, y = 2;
Object.assign(exports, {x: x, y: y});


// export default function () {
//   x = 1;
// };
// export default class {};
class F {}
Object.assign(exports, {default: F});
;

function updateX() {
  x++;
  console.log('updated X', x);
}
Object.assign(exports, {updateX: updateX});


const $lib1 = __fastpack_require__(/* "./y" */ "236e9c0761015ee1871421a78316fb8e");
Object.assign(exports, {X: $lib1.default, xA: $lib1.a, updateA: $lib1.updateA});
Object.assign(exports, {ZM: ZModule.default});
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
