#!/bin/sh

FPACK="../../_build/default/bin/fpack.exe"
EXAMPLE="examples/$1"
ENTRY_POINT="$2"
FLAGS="${@:3}"

TC='\033[0;34m'
C='\033[0;32m'
NC='\033[0m'

cd $EXAMPLE
rm -rf fpack-test

run() {
    echo "${C}$1${NC}"
    time $FPACK $ENTRY_POINT $FLAGS ${@:2}
    echo ""
}

echo "${TC}==========================================================${NC}"
echo "${TC}$1${NC}"
echo "${TC}==========================================================${NC}"
echo ""


run "Regular / Production / Cache Purged" \
    --purge-cache \
    -o fpack-test/regular.prod.purge.js \
    --bundle regular \
    --mode production
run "Regular / Development / Cache Purged" \
    --purge-cache \
    -o fpack-test/regular.dev.purge.js \
    --bundle regular \
    --mode development
run "Regular / Production / Cache Used" \
    -o fpack-test/regular.prod.cache.js \
    --bundle regular \
    --mode production
run "Regular / Development / Cache Used" \
    -o fpack-test/regular.dev.cache.js \
    --bundle regular \
    --mode development
run "Regular / Production / Cache Ignored" \
    --no-cache \
    -o fpack-test/regular.prod.no-cache.js \
    --bundle regular \
    --mode production
run "Regular / Development / Cache Ignored" \
    --no-cache \
    -o fpack-test/regular.dev.no-cache.js \
    --bundle regular \
    --mode development
run "Flat / Production" \
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
