const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("ts-loader in development mode", async () => {
  const { bundle, stderr } = await fpack(
    ["index.ts", "--dev", "--preprocess=\\.ts$:ts-loader"],
    { copyOutputTo: "build-dev" }
  );
  expect(bundle).toMatchSnapshot();
});
