
const { expectOK } = require("../helpers.js");

process.chdir(__dirname);

test("pack CRA-based app in development mode", async () => {
  const { bundle } = await expectOK(
    ["src/index.js",
      "--dev",
      "--preprocess=^src.+\\.js$",
      "--preprocess=\\.svg$:url-loader",
      "--preprocess=\\.css$:style-loader!css-loader?importLoaders=1!postcss-loader?path=postcss.config.js"
    ],
    { copyOutputTo: "build-dev" }
  );
});

test("pack CRA-based app in production mode", async () => {
  const { bundle, stderr } = await expectOK(
    ["src/index.js",
      "--preprocess=^src.+\\.js$:babel-loader?filename=.babelrc",
      "--preprocess=\\.svg$:file-loader?name=static/media/[name].[hash:8].[ext]&publicPath=http://localhost:4321/pack-cra/build-prod/",
      "--preprocess=\\.css$:style-loader!css-loader?importLoaders=1!postcss-loader?path=postcss.config.js"
    ],
    { copyOutputTo: "build-prod" }
  );
});
