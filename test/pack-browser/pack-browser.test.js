const { expectOK } = require("../helpers.js");

process.chdir(__dirname);

test("development mode", async () => {
  const { bundle } = await expectOK(["--dev"]);
  expect(bundle).toMatchSnapshot();
});

test("production mode", async () => {
  const { bundle } = await expectOK([]);
  expect(bundle).toMatchSnapshot();
});
