// @flow

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { promisify } = require('util');

const writeFile = promisify(fs.writeFile);
const readFile = promisify(fs.readFile);
const readdir = promisify(fs.readdir);

const testRoot = path.join(process.cwd(), 'test/cli');
const fpackFile = path.join(process.cwd(), '_build/install/default/bin/fpack');

(async () => {
  const dirs = await readdir(testRoot);
  let passed = [];
  let failed = [];

  for (const name of dirs) {
    const testDir = path.join(testRoot, name);
    const testFile = path.join(testDir, 'test.sh');
    const testExpFile = path.join(testDir, name + '.exp');
    const testOutFile = path.join(testDir, name + '.out');
    const testExp = await readFile(testExpFile, 'utf8');

    const proc = spawn('bash', [testFile, fpackFile], {
      cwd: testDir
    });

    const result = [];

    const handleData = data => {
      result.push(data.toString());
    };

    proc.stdout.on('data', handleData);

    proc.stderr.on('data', handleData);

    await new Promise(resolve => proc.on('close', () => {
      const testOut = result.join('\n\n');
      if (testExp === testOut) {
        passed.push(name);
        console.info(`Test '${name}' is passed`);
      } else {
        writeFile(testOutFile, testOut);
        failed.push(name);
        console.error(`Test '${name}' is not passed`);
      }
      resolve()
    }));
  }

  console.info(`Passed ${passed.length} tests. Failed ${failed.length} tests.`);
})().catch(console.error);
