const { loadFpackStdio } = require('../helpers.js');

process.chdir(__dirname);

test('--stats=json add modulesPaths in prod', async () => {
  expect(
    JSON.parse(
      await loadFpackStdio({
        input: 'index.js',
        stats: 'json'
      })
    )
  ).toMatchSnapshot();
});

test('--stats=json add modulesPaths in dev', async () => {
  expect(
    JSON.parse(
      await loadFpackStdio({
        input: 'index.js',
        development: true,
        stats: 'json'
      })
    )
  ).toMatchSnapshot();
});
