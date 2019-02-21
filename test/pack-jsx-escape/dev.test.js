module.exports = ({bundle}) => bundle(`
fpack --preprocess=src/.*\.js$ --dev src/index.js
`);
