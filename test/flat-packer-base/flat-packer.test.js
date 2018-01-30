const { loadFpackBundle } = require('../helpers.js');

process.chdir(__dirname);

test('flat packer with single js', async () => {
  expect(
    await loadFpackBundle({ input: 'index-single.js', target: 'app' })
  ).toMatchSnapshot('target: app');
  expect(
    await loadFpackBundle({ input: 'index-single.js', target: 'esm' })
  ).toMatchSnapshot('target: esm');
  expect(
    await loadFpackBundle({ input: 'index-single.js', target: 'cjs' })
  ).toMatchSnapshot('target: cjs');
});

test('flat packer with only esm', async () => {
  expect(
    await loadFpackBundle({ input: 'index-esm.js', target: 'app' })
  ).toMatchSnapshot('target: app');
  expect(
    await loadFpackBundle({ input: 'index-esm.js', target: 'esm' })
  ).toMatchSnapshot('target: esm');
  expect(
    await loadFpackBundle({ input: 'index-esm.js', target: 'cjs' })
  ).toMatchSnapshot('target: cjs');
});

test('flat packer with only cjs', async () => {
  expect(
    await loadFpackBundle({ input: 'index-cjs.js', target: 'app' })
  ).toMatchSnapshot('target: app');
  expect(
    await loadFpackBundle({ input: 'index-cjs.js', target: 'esm' })
  ).toMatchSnapshot('target: esm');
  expect(
    await loadFpackBundle({ input: 'index-cjs.js', target: 'cjs' })
  ).toMatchSnapshot('target: cjs');
});

test('flat packer with esm in cjs', async () => {
  expect(
    await loadFpackBundle({ input: 'index-esm-in-cjs.js', target: 'app' })
  ).toMatchSnapshot('target: app');
  expect(
    await loadFpackBundle({ input: 'index-esm-in-cjs.js', target: 'esm' })
  ).toMatchSnapshot('target: esm');
  expect(
    await loadFpackBundle({ input: 'index-esm-in-cjs.js', target: 'cjs' })
  ).toMatchSnapshot('target: cjs');
});

test('flat packer with cjs in esm', async () => {
  expect(
    await loadFpackBundle({ input: 'index-cjs-in-esm.js', target: 'app' })
  ).toMatchSnapshot('target: app');
  expect(
    await loadFpackBundle({ input: 'index-cjs-in-esm.js', target: 'esm' })
  ).toMatchSnapshot('target: esm');
  expect(
    await loadFpackBundle({ input: 'index-cjs-in-esm.js', target: 'cjs' })
  ).toMatchSnapshot('target: cjs');
});
