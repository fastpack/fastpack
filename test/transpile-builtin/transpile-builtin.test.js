const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("transpile flow inside jsx", async () => {
  expect(
    (await fpack(["index-1.js", "--preprocess=^.*"])).bundle
  ).toMatchSnapshot();
});
