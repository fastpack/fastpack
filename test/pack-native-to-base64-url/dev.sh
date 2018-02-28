
$FPACK src/index.js \
    --dev \
    --preprocess='^src.+\.js$' \
    --preprocess='\.svg$:to-base64-url' \
    --preprocess='\.css$:style-loader!css-loader?importLoaders=1!postcss-loader?path=postcss.config.js'
