const fs = require("fs");
const path = require("path");
const writeLinkFile = opts => {
  fs.writeFileSync(path.join(__dirname, "..", "FastpackUtil", "c_link_flags"), opts);
};

switch (process.platform) {
  case "win32":
    writeLinkFile("(-D_WIN32)");
    break;
  default:
    writeLinkFile("()");
}
