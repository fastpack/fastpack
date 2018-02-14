const { expectOK } = require("../helpers.js");

process.chdir(__dirname);

test("custom-loader in development mode", async () => {
  const { bundle } = await expectOK(
    ["index.js", "--dev"],
    { copyOutputTo: "build-dev" }
  );
  expect(bundle).toMatchSnapshot();
});

test("custom-loader in production mode", async () => {
  const { bundle } = await expectOK(
    ["index.js"],
    { copyOutputTo: "build-prod" }
  );
  expect(bundle).toMatchSnapshot();
});
