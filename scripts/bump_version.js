const fs = require("fs");
const readline = require("readline");
const package = require("../package.json");
const distPackage = require("../dist/package.json");

let versionReFile = fs.readFileSync("Fastpack/Version.re");
let versionReRegexp = /let\s+version\s+=\s+"(.+?)"/;
let versionRe = versionReRegexp.exec(versionReFile);
if (versionRe === null) {
  console.error(
    "Fastpack/Version.re doesn't have the expected version declaration"
  );
  process.exit(1);
} else {
  versionRe = versionRe[1];
}

console.log("");
console.log("Following versions are set:");
console.log(`package.json: ${package.version}`);
console.log(`dist/package.json: ${package.version}`);
console.log(`Fastpack/Version.re: ${versionRe}`);
console.log("");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function replace(filename, what, sub) {
  let content = fs.readFileSync(filename).toString();
  let newContent = content.replace(what, sub);
  if (content === newContent) {
    console.error(`Nothing was replaced in the file: ${filename}`);
    process.exit(1);
  } else {
    return newContent;
  }
}

let validVersionRegexp = /^\d+\.\d+\.\d+$/;
function askNewVersion() {
  rl.question("Set the new version (Ctrl-C to quit): ", version => {
    version = version.trim();
    if (validVersionRegexp.test(version)) {
      [
        {
          filename: "package.json",
          what: `"version": "${package.version}"`,
          sub: `"version": "${version}"`
        },
        {
          filename: "dist/package.json",
          what: `"version": "${distPackage.version}"`,
          sub: `"version": "${version}"`
        },
        {
          filename: "Fastpack/Version.re",
          what: versionReRegexp,
          sub: `let version = "${version}"`
        }
      ].map(({ filename, what, sub }) => ({
        filename,
        content: replace(filename, what, sub)
      })).forEach(({filename, content}) => {
        fs.writeFileSync(filename, content, {mode: 0o644});
        console.log(`${filename} updated`);
      });
      console.log("Version updated. Check `git diff` output");

      rl.close();
    } else {
      console.log(`Invalid version: ${version}\n`);
      askNewVersion();
    }
  });
}
askNewVersion();
