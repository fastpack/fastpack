const { fpack } = require('../helpers.js');

process.chdir(__dirname);

test('--stats=json add modulesPaths in prod', async () => {
  expect(
    JSON.parse(
      await fpack({
        input: 'index.js',
        output: 'bundle-1',
        stats: 'json'
      })
    )
  ).toMatchSnapshot();
});

test('--stats=json add modulesPaths in dev', async () => {
  expect(
    JSON.parse(
      await fpack({
        input: 'index.js',
        output: 'bundle-2',
        development: true,
        stats: 'json'
      })
    )
  ).toMatchSnapshot();
});
