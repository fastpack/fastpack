const fs = require("fs-extra");

module.exports = ({fpack, bundle, outputDir}) => {
  // initial build - cache is empty
  fpack("fpack --dev index.js");

  // this one is done completely using cache
  // and we want to make sure that static file is emitted
  fs.removeSync(outputDir);
  bundle("fpack --dev index.js");
}
