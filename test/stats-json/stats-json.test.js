const { expectOK } = require("../helpers.js");

process.chdir(__dirname);

test("--stats=json add modulesPaths in prod", async () => {
  const { stdout } = await expectOK(["index.js", "--stats=json"]);
  expect(JSON.parse(stdout)).toMatchSnapshot();
});

test("--stats=json add modulesPaths in dev", async () => {
  const { stdout } = await expectOK(["index.js", "--dev", "--stats=json"]);
  expect(JSON.parse(stdout)).toMatchSnapshot();
});
