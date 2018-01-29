#!/bin/bash
FPACK=$1

$FPACK index.js --output bundle --stats=json

$FPACK index.js --output bundle --development --stats=json
