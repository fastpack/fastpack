import 'style-loader!css-loader!less-loader!./test.less'


document.body.innerHTML =
  `<div class="less">LESS: this text is green
  <span class="badge badge-secondary">With Bootstrap!</span></div>
  `;
