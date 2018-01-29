const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const { spawn } = require('child_process');
const fpackFile = path.join(__dirname, '..', '_build/install/default/bin/fpack');

const removeDir = promisify(fs.rmdir);
const removeFile = promisify(fs.unlink);
const readFile = promisify(fs.readFile);
const makeTempDir = promisify(fs.mkdtemp);

const getArgs = (options = {}) => {
  const args = [];
  if (typeof options.input === 'string') {
    args.push(options.input);
  }
  if (typeof options.output === 'string') {
    args.push(`--output=${options.output}`);
  }
  if (options.development === true) {
    args.push('--development');
  }
  if (typeof options.target === 'string') {
    args.push(`--target=${options.target}`);
  }
  if (options.noCache === true) {
    args.push('--no-cache');
  }
  if (options.debug === true) {
    args.push('--debug');
  }
  if (typeof options.preprocess === 'string') {
    args.push(`--preprocess=${options.preprocess}`);
  }
  if (typeof options.postprocess === 'string') {
    args.push(`--postprocess=${options.postprocess}`);
  }
  if (typeof options.stats === 'string') {
    args.push(`--stats=${options.stats}`);
  }
  return args;
};

const fpack = options => {
  const proc = spawn(fpackFile, getArgs(options), {
    cwd: process.cwd()
  });

  let out = [];
  let err = [];

  proc.stdout.on('data', data => {
    out.push(data.toString());
  });

  proc.stderr.on('data', data => {
    err.push(data.toString());
  });

  return new Promise((resolve, reject) => {
    proc.on('close', () => {
      if (out.length !== 0) {
        resolve(out.join('\n'));
      }
      if (err.length !== 0) {
        reject(Error(err.join('\n')));
      }
    });
  })
};

const loadFpackStdio = async options => {
  const bundleDir = await makeTempDir(process.cwd());
  const bundleFile = path.join(bundleDir, 'index.js');
  try {
    const result = await fpack({
      ...options,
      output: bundleDir
    });
    await removeFile(bundleFile);
    await removeDir(bundleDir);
    return result;
  } catch (error) {
    await removeFile(bundleFile);
    await removeDir(bundleDir);
    throw error;
  }
};

const loadFpackBundle = async options => {
  const bundleDir = await makeTempDir(process.cwd());
  const bundleFile = path.join(bundleDir, 'index.js');
  await fpack({
    ...options,
    output: bundleDir
  });
  const bundle = await readFile(bundleFile, 'utf8');
  await removeFile(bundleFile);
  await removeDir(bundleDir);

  return bundle;
};

module.exports = {
  fpack,
  loadFpackStdio,
  loadFpackBundle,
  readFile
};
