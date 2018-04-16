output1="$($FPACK index.js --dev)"
rm -rf $FPACK_OUTPUT
output2="$($FPACK index.js --dev)"
rm -rf $FPACK_OUTPUT
output3="$($FPACK index.js --dev --no-cache)"
rm -rf $FPACK_OUTPUT
output4="$($FPACK index.js)"
rm -rf $FPACK_OUTPUT
mkdir $FPACK_OUTPUT
echo "$(printf "$output1\n$output2\n$output3\n$output4\n" | sed "s/\\.[0-9][0-9][0-9]/.XXX/")"
