import "./yz";
import "./yz_reimport.js";
import "./test.css";
import CJS from "./cjs";

const util = require("./util");

if (true) {
  let yz = import('./yz');
}
else {
  CJS();
}

