// On Windows it doesn't strip quotes
// On Mac - quotes are required here
const config = '\\.css$:style-loader!css-loader';


module.exports = ({ bundle }) => bundle(`
fpack build index.js --dev --preprocess=${process.platform === 'win32' ? config : "'" + config + "'"}
`);
