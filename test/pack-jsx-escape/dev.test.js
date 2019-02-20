module.exports = ({bundle}) => bundle(`
fpack --preprocess='\.js$' --dev index.js
`);
