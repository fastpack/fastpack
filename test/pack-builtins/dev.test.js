
module.exports = ({ bundle }) => bundle(`
fpack index.js \
    --dev \
    --preprocess=\\.js$:builtin
`);
