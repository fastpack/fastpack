const path = require("path");
const appDir = path.join(__dirname, "app");
module.exports = ({ bundle }) =>
  bundle(`
fpack index.js \
  --dev \
  --no-cache \
  --project-root="../" \
  --mock="mocked:./mock" \
  --preprocess="babel-transpile:babel-loader" \
  --preprocess="builtin-transpile:builtin" \
  --nm ./nm \
  --nm node_modules
`, {cwd: appDir});
