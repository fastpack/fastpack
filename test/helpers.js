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
const move = promisify(fs.rename);

const validateOptions = options => {
  let ret = { ...options };
  ret.keepCache = !!ret.keepCache;
  ret.copyOutputTo = ret.copyOutputTo || null;

  if (typeof ret.copyOutputTo !== "string" && ret.copyOutputTo !== null) {
    throw `"copyOutputTo" is expected to be string or null.` +
      `Got ${typeof copyOutputTo}`;
  }

  const allowedOptions = [
    "keepCache", // Boolean. Do not remove cache before the execution
    "copyOutputTo" // String | null.
    // Copy output directory to the specified location
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
  const { keepCache, copyOutputTo } = validateOptions(options || {});

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
        if (copyOutputTo) {
          await move(bundleDir, copyOutputTo);
        }
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
