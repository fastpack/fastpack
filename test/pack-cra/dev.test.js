
module.exports = ({ bundle }) => bundle(`
fpack build src/index.js \
    --dev \
    --preprocess=^src.+\\.js$:babel-loader \
    --preprocess=\\.svg$:url-loader \
    --preprocess=\\.css$:style-loader!css-loader!postcss-loader?path=postcss.config.js
`);
