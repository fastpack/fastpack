const { fpack, readFile } = require('../helpers.js');

process.chdir(__dirname);

test('transpile flow inside jsx', async () => {
  await fpack({
    input: 'index-1.js',
    output: 'bundle-1',
    preprocess: "^.*"
  });
  expect(await readFile('bundle-1/index.js', 'utf8')).toMatchSnapshot();
});
