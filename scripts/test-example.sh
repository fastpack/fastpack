#!/bin/sh

FPACK="../../_build/default/bin/fpack.exe"
EXAMPLE="examples/$1"
ENTRY_POINT="$2"
FLAGS="${@:3}"

C='\033[0;32m'
NC='\033[0m'

cd $EXAMPLE

echo "${C}Production / Cache Purged${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --purge-cache \
    -o fpack-test/regular.prod.js \
    --bundle regular \
    --mode production
echo "${C}Development / Cache Purged${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --purge-cache \
    -o fpack-test/regular.dev.js \
    --bundle regular \
    --mode development
echo "${C}Production / Cache Used${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.prod.js \
    --bundle regular \
    --mode production
echo "${C}Development / Cache Used${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.dev.js \
    --bundle regular \
    --mode development
echo "${C}Production / Cache Ignored${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --no-cache \
    -o fpack-test/regular.prod.js \
    --bundle regular \
    --mode production
echo "${C}Development / Cache Ignored${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --no-cache \
    -o fpack-test/regular.dev.js \
    --bundle regular \
    --mode development

for FILE in `cd fpack-test && ls *.js`; do
    cat  <<HTML > "fpack-test/${FILE%.*}.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>${FILE}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="text/javascript" src="${FILE}"></script>
  </body>
</html>
HTML
done
