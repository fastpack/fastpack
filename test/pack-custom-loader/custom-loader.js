module.exports = function(source) {
  let ret = `
document.body.innerHTML = document.body.innerHTML
+ "<div>Source: " + ${source ? '"not empty"' : '"empty"'} + ". Query: ${this.query}.</div>";
module.exports = {};
  `;
  this.callback(null, ret, null);
};
