module.exports = ({ stdout }) =>
  stdout(`
fpack --preprocess=\.js$:eslint-loader --dev index.js
`);
