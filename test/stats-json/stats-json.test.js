const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("--stats=json add modulesPaths in prod", async () => {
  const { stdout } = await fpack(["index.js", "--stats=json"]);
  expect(JSON.parse(stdout)).toMatchSnapshot();
});

test("--stats=json add modulesPaths in dev", async () => {
  const { stdout } = await fpack(["index.js", "--dev", "--stats=json"]);
  expect(JSON.parse(stdout)).toMatchSnapshot();
});
