const fs = require("fs-extra");
const { spawnSync } = require("child_process");
const path = require("path");
const chalk = require("chalk");

let args = process.argv.slice(2);

const SAVE_SNAPSHOT_MODE = args.indexOf("--train") !== -1;
const NO_COLOR = args.indexOf("--no-color") !== -1;
const PATTERNS = args
  .filter(arg => arg !== "--train" && arg !== "--no-color")
  .map(pattern => new RegExp(pattern));
const matchPatterns = fn =>
  PATTERNS.length === 0
    ? true
    : PATTERNS.reduce((result, pattern) => result || pattern.test(fn), false);

const repoRoot = path.dirname(__dirname);
const sandbox = path.join(repoRoot, ".sandbox");
fs.ensureDirSync(sandbox);
fs.emptyDirSync(sandbox);

function exe(cmd, opts) {
  let { status, stdout, stderr } = spawnSync(cmd, [], {
    cwd: opts.cwd,
    env: opts.env,
    shell: true,
    timeout: 5000
  });
  return {
    stdout: stdout instanceof Buffer ? stdout.toString() : stdout,
    stderr: stderr instanceof Buffer ? stderr.toString() : stderr,
    code: status
  };
}

function diff(dir1, dir2) {
  let cmd = `git --no-pager diff --no-index ${
    NO_COLOR ? "--no-color" : "--color"
  } ${dir1} ${dir2}`;
  return exe(cmd, { cwd: repoRoot });
}

function fpack(cmd, { cwd, outputDir, env }) {
  const prefix = "fpack";
  cmd = cmd.trim();
  if (!cmd.startsWith(prefix)) {
    console.error(`Command should start with "fpack". Received:\n${cmd}`);
    process.exit(1);
  }

  const binPath = path.join(
    __dirname,
    "..",
    "_build",
    "default",
    "bin",
    "fpack.exe"
  );

  cmd = `${binPath} -o ${outputDir} ${cmd
    .substr(prefix.length)
    .replace(/\\\n/g, " ")
    .replace(/\s{2,}/g, " ")}`;

  return exe(cmd, { cwd, env });
}

const all = {};

function Test(testPath) {
  let parts = testPath.split(path.sep);
  let [p2, p1] = [...parts].reverse();

  let name = `${p1}${path.sep}${p2}`;
  let workingDir = path.dirname(testPath);
  let resultDir = path.join(workingDir, p2.replace(/\.test\.js$/, ""));
  let sandboxOutputDir = path.join(sandbox, `${p1}---${p2}`);

  const saveSnapshot = () => {
    fs.removeSync(resultDir);
    fs.moveSync(sandboxOutputDir, resultDir);
  };

  // load previous result
  let previousResult = false;
  if (fs.existsSync(resultDir)) {
    let stats = fs.statSync(resultDir);
    if (stats.isDirectory()) {
      previousResult = true;
    } else {
      throw `Expected ${resultDir} to be a directory`;
    }
  }

  const start = () => {
    process.stdout.write(`${chalk.cyan(name)} `);
  };

  const mark = result => {
    if (all[name] === undefined) {
      all[name] = result;
    } else {
      throw `
There should be one and only one call of one of those functions in the test:
  bundle, error, result
Check test: ${name}
      `;
    }
  };

  const markOk = (message = "OK") => {
    mark(true);
    process.stdout.write(`[${chalk.green(message)}]\n`);
  };

  const markError = (message = "Error") => {
    mark(false);
    process.stdout.write(`[${chalk.red(message)}]\n`);
  };

  const runDiff = () => {
    let diffResult = diff(resultDir, sandboxOutputDir);
    if (diffResult.code === 0) {
      markOk();
    } else {
      markError("Diff");
      process.stdout.write(diffResult.stdout);
    }
  };

  const expectBundle = result => {
    if (!result.code && result.stderr) {
      markError("Error, unexpected stderr");
      process.stdout.write(result.stderr);
      process.stdout.write("\n");
    } else {
      if (!previousResult || SAVE_SNAPSHOT_MODE) {
        saveSnapshot();
        markOk("Snapshot saved");
      } else {
        runDiff();
      }
    }
  };

  const expectError = result => {
    if (result.code === 0) {
      markError("Error, unexpected successful build");
    } else {
      fs.ensureDirSync(sandboxOutputDir);
      fs.emptyDirSync(sandboxOutputDir);
      fs.writeFileSync(
        path.join(sandboxOutputDir, "stderr.txt"),
        result.stderr.replace(new RegExp(repoRoot, "g"), "/...")
      );
      if (!previousResult || SAVE_SNAPSHOT_MODE) {
        saveSnapshot();
        markOk("Sanpshot saved");
      } else {
        runDiff();
      }
    }
  };

  const expectResult = result => {
    fs.ensureDirSync(sandboxOutputDir);
    fs.emptyDirSync(sandboxOutputDir);
    fs.writeFileSync(
      path.join(sandboxOutputDir, "result.txt"),
      result.replace(new RegExp(repoRoot, "g"), "/...")
    );
    if (!previousResult || SAVE_SNAPSHOT_MODE) {
      saveSnapshot();
      markOk("Sanpshot saved");
    } else {
      runDiff();
    }
  };

  let f = require(testPath);
  this.run = () => {
    if (!matchPatterns(name)) {
      return;
    }
    try {
      fs.removeSync(path.join(workingDir, ".cache"));
      fs.removeSync(path.join(workingDir, "node_modules", ".cache"));
      start();
      f({
        outputDir: sandboxOutputDir,
        fpack: (cmd, opts = {}) =>
          fpack(cmd, { cwd: workingDir, outputDir: sandboxOutputDir, ...opts }),
        bundle: (cmd, opts = {}) =>
          expectBundle(
            fpack(cmd, {
              cwd: opts.cwd ? opts.cwd : workingDir,
              env: opts.env,
              outputDir: sandboxOutputDir
            })
          ),
        error: (cmd, opts = {}) =>
          expectError(
            fpack(cmd, {
              cwd: opts.cwd ? opts.cwd : workingDir,
              env: opts.env,
              outputDir: sandboxOutputDir
            })
          ),
        result: result => expectResult(result)
      });
      let result = all[name];
      if (result === undefined) {
        throw `
        Result was not collected. This likely means that none of the following
        functions was called:
          bundle, error, result
        `;
      }
    } catch (e) {
      console.error(e);
      console.warn(`
      Test file is expected to export 1 function of the following signature:

      module.exports = function({fpack, bundle, error, result}) {
        ...
      };

      All the arguments are functions as well:
      fpack :: (cmd: string) => {code, stderr, stdout}
      bundle :: (cmd: string) => undefined
      error :: (cmd: string) => undefined
      result :: (msg: string) => undefined

      // Example 1. Expect to bundle ok
      module.exports = ({bundle}) => bundle('fpack index.js');

      // Example 2. Expect error
      module.exports = ({error}) => error('fpack bad-entry-point.js');

      // Example 3. Don't care about the bundle itself, check stdout
      module.exports = function ({fpack, ok, fail}) {
        let stdout = fpack("fpack index.js").then(({code, stdout, stderr}) => stdout);
        return result(stdout);
      }
      `);
      process.exit(1);
    }
  };
}

function runAll(testPaths) {
  testPaths.forEach(testPath => {
    let test = new Test(testPath);
    test.run();
  });

  let { total, failed } = Object.keys(all).reduce(
    (acc, key) => ({
      total: acc.total + 1,
      failed: acc.failed + (all[key] ? 0 : 1)
    }),
    { total: 0, failed: 0 }
  );

  let [colorFunc, code] =
    failed > 0 ? [chalk.red, 1] : [chalk.green, 0];
  console.log(`
${colorFunc(`Total: ${total}. Failed: ${failed}. `)}${
    PATTERNS.length
      ? chalk.yellow("Selected tests only, consider running all the tests")
      : ""
  }
`);
  process.exit(code);
}

function collect(dir) {
  const filter = fn => fn.endsWith(".test.js");

  return fs.readdirSync(dir).reduce((acc, fn) => {
    fn = path.join(dir, fn);
    let stats = fs.statSync(fn);
    if (stats.isDirectory()) {
      return fs.readdirSync(fn).reduce((acc, fn2) => {
        fn2 = path.join(fn, fn2);
        let stats = fs.statSync(fn2);
        return stats.isFile() && filter(fn2)
          ? [...acc, path.resolve(fn2)]
          : acc;
      }, acc);
    } else {
      return acc;
    }
  }, []);
}

runAll(collect("test"));
