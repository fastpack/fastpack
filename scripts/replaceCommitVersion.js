const path = require("path");
const fs = require("fs");
const { spawnSync } = require("child_process");

let repoRoot = path.dirname(__dirname);
let VersionRe = path.join(repoRoot, "Fastpack", "Version.re");

let data = fs.readFileSync(VersionRe).toString();
let { status, stdout, stderr } = spawnSync(
  "git log --pretty=format:'%h' -n 1",
  [],
  { shell: true, cwd: repoRoot }
);
if (status !== 0) {
  process.stderr.write(stderr);
  process.exit(1);
}

let commit = stdout instanceof Buffer ? stdout.toString() : stdout;
fs.writeFileSync(VersionRe, data.replace('%%COMMIT%%', commit));
console.log(`${VersionRe} updated`);
