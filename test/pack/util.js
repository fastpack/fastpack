import {x} from "./x";
import {updateX} from './x';
import initX from "./x";
import * as allX from "./x";

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
  initX();
  console.log("x before update", x);
  updateX();
  console.log("x after update:", x);
};
