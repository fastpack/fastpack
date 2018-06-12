module.exports = function(source) {
  source = JSON.stringify(source);
  let ret = `
  export default function () {console.log(${source})};
  `;
  this.callback(null, ret, null);
};
