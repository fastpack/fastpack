
module.exports = ({ bundle }) => bundle(`
fpack index.js \
    --dev \
    --preprocess='^log1\\.js$:./logSource' \
    --preprocess='\\.js$:builtin'
`);
