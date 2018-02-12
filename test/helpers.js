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

const getArgs = (options = {}) => {
  const args = [];
  if (typeof options.input === "string") {
    args.push(options.input);
  }
  if (typeof options.output === "string") {
    args.push(`--output=${options.output}`);
  }
  if (options.development === true) {
    args.push("--development");
  }
  if (typeof options.target === "string") {
    args.push(`--target=${options.target}`);
  }
  if (options.noCache === true) {
    args.push("--no-cache");
  }
  if (options.debug === true) {
    args.push("--debug");
  }
  if (typeof options.preprocess === "string") {
    args.push(`--preprocess=${options.preprocess}`);
  }
  if (typeof options.postprocess === "string") {
    args.push(`--postprocess=${options.postprocess}`);
  }
  if (typeof options.stats === "string") {
    args.push(`--stats=${options.stats}`);
  }
  return args;
};

const fpack = async options => {
  const bundleDir = await makeTempDir(path.join(os.tmpdir(), "fpack-"));
  const bundleFile = path.join(bundleDir, "index.js");
  await removeDir(path.join(__dirname, ".cache"));
  await removeDir(path.join(__dirname, "node_modules", ".cache"));

  const proc = child_process.spawn(
    fpackFile,
    getArgs({ ...options, output: bundleDir }),
    {
      cwd: process.cwd()
    }
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
      let bundle = null;
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
