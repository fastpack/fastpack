$FPACK index.js \
    --preprocess='\.(svg|ttf|woff|woff2|eot)$:file-loader?name=static/media/[name].[hash:8].[ext]&publicPath=http://localhost:4321/pack-cra/build-prod/'
