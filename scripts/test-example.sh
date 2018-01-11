#!/bin/sh

FPACK="../../_build/default/bin/fpack.exe"
EXAMPLE="examples/$1"
ENTRY_POINT="$2"
FLAGS="${@:3}"

C='\033[0;32m'
NC='\033[0m'

cd $EXAMPLE
rm -rf fpack-test

echo "${C}Regular / Production / Cache Purged${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --purge-cache \
    -o fpack-test/regular.prod.purge.js \
    --bundle regular \
    --mode production
echo "${C}Regular / Development / Cache Purged${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --purge-cache \
    -o fpack-test/regular.dev.purge.js \
    --bundle regular \
    --mode development
echo "${C}Regular / Production / Cache Used${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.prod.cache.js \
    --bundle regular \
    --mode production
echo "${C}Regular / Development / Cache Used${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.dev.cache.js \
    --bundle regular \
    --mode development
echo "${C}Regular / Production / Cache Ignored${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --no-cache \
    -o fpack-test/regular.prod.no-cache.js \
    --bundle regular \
    --mode production
echo "${C}Regular / Development / Cache Ignored${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --no-cache \
    -o fpack-test/regular.dev.no-cache.js \
    --bundle regular \
    --mode development
echo "${C}Flat / Production${NC}"
time $FPACK $ENTRY_POINT $FLAGS \
    --purge-cache \
    -o fpack-test/flat.prod.js \
    --bundle flat \
    --mode production

INDEX="fpack-test/index.html"
cat <<HTML > $INDEX
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>$1</title>
  </head>
  <body>
    <h2>$1</h2>
    <ul>
HTML

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
    echo "<li><a href='${FILE%.*}.html'>$FILE</a></li>" >> $INDEX
done


cat <<HTML >> $INDEX
    </ul>
  </body>
</html>
HTML
