#!/bin/bash

set -euo pipefail

cwd=`pwd -L`
pattern="${1:-}"
base_dir=`dirname $cwd`
mode=`basename $0 .sh`

if which colordiff >/dev/null; then
    diff_cmd="colordiff -r"
else
    diff_cmd="diff -r"
fi

if [ "$(uname -s)" == "Darwin" ]; then
    sed_cmd="sed -i ''"
else
    sed_cmd="sed -i"
fi

total=0
failed=0

ERROR="\033[0;31m"
OK="\033[0;32m"
NC="\033[0m"

report() {
    printf "$1$2${NC} $3\n"
}

for file in `ls */*.sh | grep "$pattern"`; do
    title="$file"
    file="$cwd/$file"
    tmp_dir=`mktemp -d -t XXXfpack`
    tmp_stdout=`mktemp -t XXXfpack-stdout`
    tmp_stderr=`mktemp -t XXXfpack-stderr`
    test_dir=`dirname $file`
    test_name=`basename $file .sh`
    rm -rf "$test_dir/.cache"
    rm -rf "$test_dir/node_modules/.cache"
    output_dir="$test_dir/$test_name"
    cd $test_dir
    set +e
    env FPACK="../../_build/default/bin/fpack.exe --output=$tmp_dir"\
        bash $file >$tmp_stdout 2>$tmp_stderr
    result="$?"
    set -e
    $sed_cmd "s-$base_dir-/...-" $tmp_stdout
    $sed_cmd "s-$base_dir-/...-" $tmp_stderr
    if ! [ "$result" -eq "0" ]; then
        mv $tmp_stderr "$tmp_dir/stderr.txt"
    fi
    if [ -e $output_dir ] && ! [ "$mode" == "update" ]; then
        if [ "$result" -eq "0" ] && [ "$(echo $test_name | grep stdout)" ]; then
            mv $tmp_stdout "$tmp_dir/stdout.txt"
        fi
        if $diff_cmd $output_dir $tmp_dir; then
            report $OK $title "[OK]"
        else
            failed=$(( $failed + 1 ))
            report $ERROR $title "[Fail] See above ^^^"
        fi
    else
        if [ "$result" -eq "0" ] && [ "$(echo $test_name | grep stdout)" ]; then
            mv $tmp_stdout "$tmp_dir/stdout.txt"
        fi
        rm -rf $output_dir
        mv $tmp_dir $output_dir
        report $OK $title "[OK] Snapshot saved"
    fi
    rm -rf $tmp_dir
    rm -rf $tmp_stdout
    rm -rf $tmp_stderr
    echo "-------------------------------------------"
    total=$(( $total + 1 ))
done

if [ "$failed" -eq "0" ]; then
    exit_code="0"
    color="$OK"
else
    color="$ERROR"
    exit_code="1"
fi
if [ -n "$pattern" ]; then
    message="Pattern used. Consider running all tests"
fi
report $color "Total: $total. Failed: $failed." "${message:-}"
exit "$exit_code"
