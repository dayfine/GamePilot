#!/bin/sh
# Tests dev/review/format_only_changes.sh on a scratch git repo with one commit per side: a JSON
# file reformatted, a JSON file whose value changed, an OCaml file reflowed, an OCaml file with a
# real edit, a file moved unchanged, a file moved and edited, and a new file. Only the reformatted
# JSON, the reflowed OCaml and the unchanged move are listed.
#   sh dev/review/test_format_only_changes.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main
git config user.email test@example.com
git config user.name test
printf '{"a": 1, "b": [1, 2]}\n' >same.json
printf '{"a": 1}\n' >changed.json
printf 'let f x =\n  x + 1\n' >reflowed.ml
printf 'let g x = x\n' >edited.ml
printf 'kept\n' >old_name.txt
printf 'first\n' >old_edited.txt
printf 'a\0b c\n' >replay.bin
git add . && git commit -qm base
git checkout -qb pr
printf '{\n  "a": 1,\n  "b": [1, 2]\n}\n' >same.json
printf '{"a": 2}\n' >changed.json
printf 'let f x = x + 1\n' >reflowed.ml
printf 'let g x = x + 0\n' >edited.ml
git mv old_name.txt new_name.txt
git mv old_edited.txt new_edited.txt
printf 'first\nsecond\n' >new_edited.txt
printf 'a\0bc\n' >replay.bin
printf 'new\n' >added.txt
git add -A && git commit -qm pr

failures=0
check() { # name, expected, got
    if [ "$2" = "$3" ]; then echo "ok   $1"; else
        echo "FAIL $1: expected"; echo "$2"; echo "got"; echo "$3"; failures=1; fi
}
got=$(sh "$here/format_only_changes.sh" main pr | sort)
check "reformatted JSON is listed" "format-only same.json" "$(echo "$got" | grep 'json' || true)"
check "reflowed OCaml is listed" "format-only reflowed.ml" "$(echo "$got" | grep '\.ml' || true)"
check "unchanged move is listed" "moved old_name.txt -> new_name.txt" \
    "$(echo "$got" | grep '^moved' || true)"
check "a changed binary file is not listed" "" "$(echo "$got" | grep 'replay' || true)"
check "nothing else is listed" "3" "$(echo "$got" | wc -l | tr -d ' ')"
check "no changes, no lines" "" "$(sh "$here/format_only_changes.sh" main main)"
exit $failures
