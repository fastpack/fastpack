#!/bin/bash

set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pattern="${1:-}"
base_dir=`dirname $tests_dir`
mode=`basename $0 .sh`
fpack_bin="$base_dir/_build/default/bin/fpack.exe"


if which colordiff >/dev/null; then
    diff_cmd="colordiff -r"
else
    diff_cmd="diff -r"
fi

if [ "$(uname -s)" == "Darwin" ]; then
    sed_cmd="sed -i .backup"
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

if ! [ -e "$fpack_bin" ]; then
    report $ERROR "fpack binary does not exist: $fpack_bin" ""
    exit 1
fi

tmp_dir="$tests_dir/tmp_output"
tmp_stdout="$tests_dir/tmp_stdout.txt"
tmp_stderr="$tests_dir/tmp_stdout.txt"


for file in `ls $tests_dir/*/*.sh | grep "$pattern"`; do
    rm -rf $tmp_dir
    rm -rf $tmp_stdout
    rm -rf $tmp_stderr
    title="$(dirname $file | xargs basename)/$(basename $file)"
    test_dir=`dirname $file`
    test_name=`basename $file .sh`
    rm -rf "$test_dir/.cache"
    rm -rf "$test_dir/node_modules/.cache"
    output_dir="$test_dir/$test_name"
    cd $test_dir
    set +e
    env FPACK="$fpack_bin --output=$tmp_dir" \
        FPACK_BIN="$fpack_bin" \
        FPACK_OUTPUT="$tmp_dir" \
        bash $file >$tmp_stdout 2>$tmp_stderr
    result="$?"
    set -e
    $sed_cmd "s!$base_dir!/...!g" $tmp_stdout
    $sed_cmd "s!$base_dir!/...!g" $tmp_stderr
    if ! [ "$result" -eq "0" ]; then
        mv $tmp_stderr "$tmp_dir/stderr.txt"
    fi
    if [ -e $output_dir ] && ! [ "$mode" == "update" ]; then
        if [ "$result" -eq "0" ] && [ "$(echo $test_name | grep stdout)" ]; then
            mv $tmp_stdout "$tmp_dir/stdout.txt"
        fi
        if $diff_cmd $output_dir $tmp_dir; then
            if [ -e $tmp_stdout ]; then
                cat $tmp_stdout
            fi
            report $OK $title "[OK]"
        else
            failed=$(( $failed + 1 ))
            if [ -e $tmp_stdout ]; then
                echo "STDOUT"
                cat $tmp_stdout
            fi
            if [ -e "$tmp_dir/stderr.txt" ]; then
                echo "STDERR"
                cat "$tmp_dir/stderr.txt"
            fi
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
    message="Pattern mode. Consider running all the tests."
fi
report $color "Total: $total. Failed: $failed." "${message:-}"
exit "$exit_code"
