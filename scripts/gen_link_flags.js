const fs = require("fs");
const path = require("path");

const writeLinkFile = (opts) => {
    fs.writeFileSync(path.join(__dirname, "..", "bin", "link_flags"), opts);
};

switch(process.platform) {
  case "linux":
    writeLinkFile("(-ccopt -static)");
    break;
  default:
    writeLinkFile("(-ccopt -L/usr/lib)");
}
