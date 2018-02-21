# initial build - cache is empty
$FPACK --dev index.js

# removing the output as we're going to rebuild from scratch
rm -rf $FPACK_OUTPUT

# running this build happens completely with cache
# we want to see that the static file is emitted again
$FPACK --dev index.js
