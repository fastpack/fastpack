cd app
$FPACK index.js \
  --dev \
  --no-cache \
  --project-root="../" \
  --mock="mocked:./mock" \
  --preprocess="babel-transpile:babel-loader" \
  --preprocess="builtin-transpile:builtin" \
  --nm ./nm \
  --nm node_modules
