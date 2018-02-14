const { expectOK } = require("../helpers.js");

process.chdir(__dirname);

test("ts-loader in development mode", async () => {
  const { bundle, stderr } = await expectOK(
    ["index.ts", "--dev", "--preprocess=\\.ts$:ts-loader"],
    { copyOutputTo: "build-dev" }
  );
  expect(bundle).toMatchSnapshot();
});

test("ts-loader in production mode", async () => {
  const { bundle, stderr } = await expectOK(
    ["index.ts", "--preprocess=\\.ts$:ts-loader"],
    { copyOutputTo: "build-prod" }
  );
  expect(bundle).toMatchSnapshot();
});
