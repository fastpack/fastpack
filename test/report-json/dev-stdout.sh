
output="$($FPACK index.js --dev --report=json)"
echo "$(printf "$output\n" | sed "s/0\\.[0-9]*/0.005/")"
