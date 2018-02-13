const os = require("os");
const fs = require("fs");
const path = require("path");
const { promisify } = require("util");
const child_process = require("child_process");
const fpackFile = path.join(
  __dirname,
  "..",
  "_build/install/default/bin/fpack"
);

const exec = promisify(child_process.exec);
const removeDir = async dir => {
  await exec("rm -rf " + dir);
};
const readFile = promisify(fs.readFile);
const makeTempDir = promisify(fs.mkdtemp);


const validateOptions = options => {
  let ret = { ...options };
  ret.keepCache = !!ret.keepCache;

  const allowedOptions = [
    "keepCache" // do not remove cache before the execution
  ];
  const allowedOptionsSet = new Set(allowedOptions);
  const allowedOptionsStr = allowedOptions.join(", ");

  Object.keys(ret).forEach(option => {
    if (!allowedOptionsSet.has(option)) {
      throw `"${option}" is not expected. Use one of: ${allowedOptionsStr}`;
    }
  });
  return ret;
};

const fpack = async (args, options) => {
  const { keepCache } = validateOptions(options || {});

  const bundleDir = await makeTempDir(path.join(os.tmpdir(), "fpack-"));
  const bundleFile = path.join(bundleDir, "index.js");

  if (!keepCache) {
    await removeDir(path.join(__dirname, ".cache"));
    await removeDir(path.join(__dirname, "node_modules", ".cache"));
  }

  const proc = child_process.spawn(
    fpackFile,
    [...args, `--output=${bundleDir}`],
    { cwd: process.cwd() }
  );

  let out = [];
  let err = [];

  proc.stdout.on("data", data => {
    out.push(data.toString());
  });

  proc.stderr.on("data", data => {
    err.push(data.toString());
  });

  return new Promise((resolve, reject) => {
    proc.on("close", async code => {
      let bundle = "";
      try {
        bundle = await readFile(bundleFile, "utf8");
      } catch (e) {
      } finally {
        await removeDir(bundleDir);
      }
      resolve({
        code,
        bundle,
        stdout: out.join("").replace(new RegExp(process.cwd(), "g"), "/..."),
        stderr: err.join("").replace(new RegExp(process.cwd(), "g"), "/...")
      });
    });
  });
};

module.exports = {
  fpack
};
