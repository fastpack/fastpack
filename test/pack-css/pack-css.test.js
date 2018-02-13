const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("css-loader & style-loader in development mode", async () => {
  const { bundle } = await fpack([
    "index.js",
    "--dev",
    "--preprocess=css$:style-loader!css-loader"
  ]);
  expect(bundle).toMatchSnapshot();

  // same configuration, just another form
  const { bundle: bundle1 } = await fpack([
    "index.js",
    "--dev",
    "--preprocess=css$:style-loader",
    "--preprocess=css$:css-loader"
  ]);
  expect(bundle1).toEqual(bundle);
});

test("css-loader & style-loader in production mode", async () => {
  const { bundle } = await fpack([
    "index.js",
    "--preprocess=css$:style-loader!css-loader"
  ]);
  expect(bundle).toMatchSnapshot();

  const { bundle: bundle1 } = await fpack([
    "index.js",
    "--preprocess=css$:style-loader",
    "--preprocess=css$:css-loader"
  ]);
  expect(bundle1).toEqual(bundle);
});
