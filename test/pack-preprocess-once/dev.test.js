
module.exports = ({ bundle }) => bundle(`
fpack build index.js \
    --dev \
    --preprocess=^log1\\.js$:./logSource \
    --preprocess=\\.js$:builtin
`);
