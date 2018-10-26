const path = require("path");
const fs = require("fs-extra");

const testDir = path.join(path.dirname(__dirname), "test");

fs.readdirSync(testDir).forEach(test => {
  let testPath = path.join(testDir, test);
  if (fs.statSync(testPath).isDirectory()) {
    let packageJson = path.join(testPath, "package.json");
    if (fs.existsSync(packageJson)) {
      let nodeModules = path.join(testPath, "node_modules");
      console.log(`Deleting ${nodeModules}`);
      fs.removeSync(nodeModules);
    }
  }
});
