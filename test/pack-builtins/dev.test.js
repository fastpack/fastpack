
module.exports = ({ bundle }) => bundle(`
fpack build index.js \
    --dev \
    --preprocess=\\.js$:builtin
`);
