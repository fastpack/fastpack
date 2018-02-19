
$FPACK src/index.js \
    --preprocess='^src.+\.js$:babel-loader?filename=.babelrc' \
    --preprocess='\.svg$:file-loader?name=static/media/[name].[hash:8].[ext]&publicPath=http://localhost:4321/pack-cra/build-prod/' \
    --preprocess='\.css$:style-loader!css-loader?importLoaders=1!postcss-loader?path=postcss.config.js'
