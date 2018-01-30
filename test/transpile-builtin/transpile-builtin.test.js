const { loadFpackBundle } = require('../helpers.js');

process.chdir(__dirname);

test('transpile flow inside jsx', async () => {
  expect(
    await loadFpackBundle({
      input: 'index-1.js',
      preprocess: "^.*"
    })
  ).toMatchSnapshot();
});
