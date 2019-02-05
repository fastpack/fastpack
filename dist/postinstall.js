var path = require("path");
var fs = require("fs");
var platform = process.platform;

const targetPath = path.join(__dirname, "fpack");

function getPlatformBinaryPath(platform) {
  return path.join(__dirname, "vendor-" + platform, "fpack.exe");
}

function movePlatformBinary(platform) {
  const sourcePath = getPlatformBinaryPath(platform);
  fs.renameSync(sourcePath, targetPath);
}

switch (platform) {
  case "win32":
  case "linux":
  case "darwin":
    movePlatformBinary(platform);
    break;
  default:
    console.warn("error: no release built for the " + platform + " platform");
    process.exit(1);
}
