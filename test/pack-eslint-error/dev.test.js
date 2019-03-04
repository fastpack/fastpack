module.exports = ({ error }) =>
  error(`
fpack --preprocess=\.js$:eslint-loader --dev index.js
`);
