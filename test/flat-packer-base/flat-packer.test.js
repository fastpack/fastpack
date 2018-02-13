const { fpack } = require("../helpers.js");

process.chdir(__dirname);

test("flat packer with single js", async () => {
  expect(
    (await fpack(["index-single.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");

  expect(
    (await fpack(["index-single.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");

  expect(
    (await fpack(["index-single.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});

test("flat packer with only esm", async () => {
  expect(
    (await fpack(["index-esm.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");
  expect(
    (await fpack(["index-esm.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");
  expect(
    (await fpack(["index-esm.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});

test("flat packer with only cjs", async () => {
  expect(
    (await fpack(["index-cjs.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");
  expect(
    (await fpack(["index-cjs.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");
  expect(
    (await fpack(["index-cjs.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});

test("flat packer with esm in cjs", async () => {
  expect(
    (await fpack(["index-esm-in-cjs.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");
  expect(
    (await fpack(["index-esm-in-cjs.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");
  expect(
    (await fpack(["index-esm-in-cjs.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});

test("flat packer with cjs in esm", async () => {
  expect(
    (await fpack(["index-cjs-in-esm.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");
  expect(
    (await fpack(["index-cjs-in-esm.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");
  expect(
    (await fpack(["index-cjs-in-esm.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});

test("flat packer with dynamic esm dep", async () => {
  expect(
    (await fpack(["index-dynamic.js", "--target=app"])).bundle
  ).toMatchSnapshot("target: app");
  expect(
    (await fpack(["index-dynamic.js", "--target=esm"])).bundle
  ).toMatchSnapshot("target: esm");
  expect(
    (await fpack(["index-dynamic.js", "--target=cjs"])).bundle
  ).toMatchSnapshot("target: cjs");
});
