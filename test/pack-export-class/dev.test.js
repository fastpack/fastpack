
module.exports = ({ bundle }) => bundle(`
fpack --dev --preprocess='\\.js$:builtin' index.js
`);
