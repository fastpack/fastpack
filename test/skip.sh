#!/bin/bash

declare -a skip=(
"cache-reporting/stdout.sh"
"error-cannot-find-exported-name/prod.sh"
"error-dependency-cycle/prod.sh"
"error-scope-naming-collision/prod.sh"
"error-scope-previously-undefined-export/prod.sh"
"pack-all-static/prod.sh"
"pack-browser/test.sh"
"pack-builtins/prod.sh"
"pack-cra/prod.sh"
"pack-custom-loader/prod.sh"
"pack-file-cached/prod.sh"
"pack-flat-collisions/prod.sh"
"pack-flat-reexport/prod.sh"
"pack-less/prod.sh"
"pack-mode/prod.sh"
"pack-raw/prod.sh"
"pack-sass/prod.sh"
"pack-scoped-require/prod.sh"
"pack-transpiler-runtime/prod.sh"
"pack-ts/prod.sh"
"pack-utf8/prod.sh"
"report-json/prod-stdout.sh"
"transpile-builtin/test.sh"
"pack-scoped-hoisted-function-export/prod.sh"
)

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for i in "${!skip[@]}"
do
    skip[$i]="$tests_dir/${skip[$i]}"
done

is_skipped() {
    if [[ " ${skip[@]} " =~ " $1 " ]]; then
        return 0
    else
        return 1
    fi
}
