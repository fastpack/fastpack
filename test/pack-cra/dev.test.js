
/*
 * We are using bundleNoDiff here since babel-loader adds absolute path
 * when transpiling JSX, hence we can't have the idempotent bundle
 * The best we can check here is the return code and also manual inspection
 * of the changes
 */

module.exports = ({ bundleNoDiff }) => bundleNoDiff(`
fpack build src/index.js \
    --dev \
    --preprocess=^src.+\\.js$:babel-loader \
    --preprocess=\\.svg$:url-loader \
    --preprocess=\\.css$:style-loader!css-loader!postcss-loader?path=postcss.config.js
`);
