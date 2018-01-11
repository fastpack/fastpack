#!/bin/sh

FPACK="../../_build/default/bin/fpack.exe"
EXAMPLE="examples/$1"
ENTRY_POINT="$2"
FLAGS="${@:3}"

cd $EXAMPLE

echo "Cache purged:"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.prod.js \
    --bundle regular \
    --mode production
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.dev.js \
    --bundle regular \
    --mode development
echo "Cache used:"
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.prod.js \
    --bundle regular \
    --mode production
time $FPACK $ENTRY_POINT $FLAGS \
    -o fpack-test/regular.dev.js \
    --bundle regular \
    --mode development
echo "Cache ignored"
