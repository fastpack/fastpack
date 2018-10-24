
module.exports = ({ bundle }) => bundle(`
fpack src/index.js \
    --dev \
    --preprocess='^src.+\\.js$' \
    --preprocess='\\.svg$:url-loader' \
    --preprocess='\\.css$:style-loader!css-loader?importLoaders=1!postcss-loader?path=postcss.config.js'
`);
