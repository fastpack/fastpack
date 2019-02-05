
module.exports = ({ bundle }) => bundle(`
fpack index.js \
    --dev \
    --preprocess='\\.(svg|ttf|woff|woff2|eot)$:file-loader?name=static/media/[name].[hash:8].[ext]'
`);
