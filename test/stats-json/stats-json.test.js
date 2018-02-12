const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("--stats=json add modulesPaths in prod", async () => {
  const { stdout } = await fpack({
    input: "index.js",
    stats: "json"
  });
  expect(JSON.parse(stdout)).toMatchSnapshot();
});

test("--stats=json add modulesPaths in dev", async () => {
  const { stdout } = await fpack({
    input: "index.js",
    development: true,
    stats: "json"
  });
  expect(JSON.parse(stdout)).toMatchSnapshot();
});
