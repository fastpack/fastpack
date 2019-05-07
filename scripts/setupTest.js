const path = require("path");
const fs = require("fs");
// const fs = require("fs-extra"); // we do not use fs-extra since to avoid `esy x`
const { spawnSync } = require("child_process");

const testDir = path.join(path.dirname(__dirname), "test");

fs.readdirSync(testDir).forEach(test => {
  let testPath = path.join(testDir, test);
  if (fs.statSync(testPath).isDirectory()) {
    let packageJson = path.join(testPath, "package.json");
    if (fs.existsSync(packageJson)) {
      console.log(`Installing ${testPath}`);
      let { status, stdout, stderr } = spawnSync("yarn", [], {
        cwd: testPath,
        shell: true
      });
      if (status !== 0) {
        process.stderr.write(stderr);
        process.exit(1);
      }
      process.stdout.write(stdout);
    }
  }
});
