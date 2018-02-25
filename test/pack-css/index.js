import * as css from "./test.css";
import 'style-loader!css-loader!sass-loader!./test.scss'


console.log(css);

document.body.innerHTML =
  `this text is red
  <div class="x">this text is blue</div>
  <div class="scss">SASS: this text is green
  <span class="badge badge-secondary">With Bootstrap!</span></div>
  `;
