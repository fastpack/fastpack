
module.exports = ({ bundle }) => bundle(`
fpack index.js --dev --preprocess='\\.css$:style-loader!css-loader'
`);
