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
    time $FPACK $ENTRY_POINT -o fpack-test $FLAGS ${@:3}
    mv fpack-test/index.js fpack-test/$2
    echo ""
}

echo "${TC}==========================================================${NC}"
echo "${TC}$1${NC}"
echo "${TC}==========================================================${NC}"
echo ""


run "Development / With Cache" dev.cache.js --development
run "Development / No Cache" dev.no-cache.js --no-cache --development
run "Production" prod.js

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
