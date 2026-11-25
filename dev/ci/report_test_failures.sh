#!/bin/sh
# Lists what failed in a `dune test` log, so a CI run page shows it: each failing test
# executable (dune prints `File ".../dune", line N` and then its "(cd _build/default/<dir> &&
# ./<exe>)" line only for a test that failed) and, under it, its lines that start with FAIL,
# FAILED or "Fatal error". Appends them to $GITHUB_STEP_SUMMARY when set and prints each
# as a ::error:: annotation. Exits 0; the caller keeps the step failing.
#
#   sh dev/ci/report_test_failures.sh dune-test.log
set -eu
log=$1
# "exe<TAB>" for a failing executable, "exe<TAB>line" for each failure line in its output.
found=$(sed 's/\r$//' "$log" | awk '
    /^File ".*dune", line [0-9]+/ { failing = 1; next }
    /^\(cd _build\/default\/.* && \.[\/\\].*\)$/ {
        exe = ""
        if (failing) {
            exe = $0
            sub(/^\(cd _build\/default\//, "", exe)
            sub(/ && \.[\/\\]/, "/", exe)
            sub(/\)$/, "", exe)
            print exe "\t"
        }
        failing = 0
        next
    }
    exe != "" && /^(FAIL|FAILED|Fatal error)/ { print exe "\t" $0 }
')
if [ -z "$found" ]; then
    # A build error, or a failure this script does not recognize: the step's output has it.
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        echo "### dune test failed; no failing test executable found in the log" >>"$GITHUB_STEP_SUMMARY"
    fi
    echo "::error::dune test failed; no failing test executable found in the log"
    exit 0
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
        echo "### Failed tests"
        echo
        printf '%s\n' "$found" | awk -F '\t' '
            $2 == "" { print "- `" $1 "`"; next }
            { print "  - " $2 }'
    } >>"$GITHUB_STEP_SUMMARY"
fi
# Annotation text: % escaped as the runner expects.
printf '%s\n' "$found" | while IFS="$(printf '\t')" read -r exe line; do
    if [ -z "$line" ]; then
        message="test failed: $exe"
    else
        message="$exe: $line"
    fi
    printf '::error::%s\n' "$(printf '%s' "$message" | sed 's/%/%25/g')"
done
exit 0
