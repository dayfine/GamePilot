#!/bin/sh
# Tests dev/ci/report_test_failures.sh on a small dune test log: only the executables dune
# reports as failed are listed, each with its own FAILED / Fatal error lines.
#   sh dev/ci/test_report_test_failures.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/dune-test.log" <<'LOG'
(cd _build/default/core/a/test && ./test_ok.exe)
ok a - passes
FAILED looks like a failure but its test passed
File "games/b/test/dune", line 7, characters 7-24:
7 |  (name test_b)
           ^^^^^^
(cd _build/default/games/b/test && .\test_b.exe)
ok b - one passes
FAILED b - one fails:
expected:
1
Fatal error: exception Failure("x")
File "core/c/test/dune", line 3, characters 2-8:
3 |   test_c)
      ^^^^^^
(cd _build/default/core/c/test && ./test_c.exe)
Fatal error: exception Assert_failure("test_c.ml", 4, 2)
LOG
printf '(cd _build/default/x && ./y.exe)\r\nok\r\n' >"$tmp/crlf.log"
expected='::error::test failed: games/b/test/test_b.exe
::error::games/b/test/test_b.exe: FAILED b - one fails:
::error::games/b/test/test_b.exe: Fatal error: exception Failure("x")
::error::test failed: core/c/test/test_c.exe
::error::core/c/test/test_c.exe: Fatal error: exception Assert_failure("test_c.ml", 4, 2)'
failures=0
got=$(GITHUB_STEP_SUMMARY="$tmp/summary.md" sh "$here/report_test_failures.sh" "$tmp/dune-test.log")
if [ "$got" = "$expected" ]; then echo "ok   annotations"; else
    echo "FAIL annotations: expected"; echo "$expected"; echo "got"; echo "$got"; failures=1; fi
if grep -q '^- `core/c/test/test_c.exe`$' "$tmp/summary.md"; then echo "ok   summary"; else
    echo "FAIL summary:"; cat "$tmp/summary.md"; failures=1; fi
got=$(sh "$here/report_test_failures.sh" "$tmp/crlf.log")
if [ "$got" = "::error::dune test failed; no failing test executable found in the log" ]; then
    echo "ok   nothing found"; else echo "FAIL nothing found: got [$got]"; failures=1; fi
exit $failures
