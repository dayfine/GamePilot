#!/bin/sh
# Tests dev/review/gate_row.py on hand-written `gh pr view` JSON, one PR per case. Each case
# names the PR's tip, its files, its checks and its reviews; the fakes are plain JSON strings
# built by pr() below, and each expectation checks one column of the row.
#   sh dev/review/test_gate_row.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tip=aaaaaaaa11111111aaaaaaaa11111111aaaaaaaa
old=bbbbbbbb22222222bbbbbbbb22222222bbbbbbbb
green='{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SUCCESS"}'
red='{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "FAILURE"}'
running='{"__typename": "CheckRun", "status": "IN_PROGRESS", "conclusion": ""}'
code='{"path": "src/a.ml"}'
doc='{"path": "docs/a.md"}'

review() { # sha, verdict: a qc-structural review body as JSON
    python3 -I -c 'import json, sys; print(json.dumps({"body": sys.argv[1]}))' \
        "Reviewed SHA: $1

## Structural QC — a PR

## Verdict

$2"
}
quoting() { # a review that only quotes an APPROVED verdict inside a fence
    python3 -I -c 'import json, sys; print(json.dumps({"body": sys.argv[1]}))' \
        "Reviewed SHA: $tip
\`\`\`
## Structural QC
## Verdict
APPROVED
\`\`\`"
}
pr() { # files, checks, reviews (JSON list bodies)
    printf '{"number": 7, "title": "t", "headRefOid": "%s", "files": [%s], "statusCheckRollup": [%s], "reviews": [%s]}' \
        "$tip" "$1" "$2" "$3"
}
column() { # n: the nth tab-separated field of the row read from stdin
    python3 -I "$here/gate_row.py" | cut -f "$1"
}

failures=0
check() { # name, expected, got
    if [ "$2" = "$3" ]; then echo "ok   $1"; else
        echo "FAIL $1: expected [$2] got [$3]"; failures=1; fi
}
check "green CI is pass" pass "$(pr "$code" "$green" "" | column 2)"
check "one red check is fail" fail "$(pr "$code" "$green, $red" "" | column 2)"
check "a running check is pending" pending "$(pr "$code" "$green, $running" "" | column 2)"
check "no checks is none" none "$(pr "$code" "" "" | column 2)"
check "no review is none" none "$(pr "$code" "$green" "" | column 3)"
check "APPROVED at the tip is ok" ok "$(pr "$code" "$green" "$(review "$tip" APPROVED)" | column 3)"
check "a short sha matches the tip" ok \
    "$(pr "$code" "$green" "$(review aaaaaaaa1 APPROVED)" | column 3)"
check "NEEDS_REWORK at the tip is rework" rework \
    "$(pr "$code" "$green" "$(review "$tip" NEEDS_REWORK)" | column 3)"
check "the latest verdict at the tip wins" ok \
    "$(pr "$code" "$green" "$(review "$tip" NEEDS_REWORK), $(review "$tip" APPROVED)" | column 3)"
check "a verdict at an older commit is stale" "stale(bbbbbbbb)" \
    "$(pr "$code" "$green" "$(review "$old" APPROVED)" | column 3)"
check "a fenced quote is not a verdict" none "$(pr "$code" "$green" "$(quoting)" | column 3)"
check "a docs-only PR skips" skip "$(pr "$doc" "$green" "" | column 3)"
check "red CI comes first" "fix CI" "$(pr "$code" "$red" "$(review "$tip" APPROVED)" | column 4)"
check "green CI and no verdict asks for one" "run qc-structural" \
    "$(pr "$code" "$green" "$(review "$old" APPROVED)" | column 4)"
check "ok goes to the user" "user review" \
    "$(pr "$code" "$green" "$(review "$tip" APPROVED)" | column 4)"
exit $failures
