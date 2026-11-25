#!/bin/sh
# Builds the OCaml linters in dev/lint/ and runs them over the roots in dev/lint/ocaml_lint.conf.
# Waived findings live in dev/lint/ocaml_lint_exceptions.conf (one reason per entry).
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root/dev/lint"
dune build ./bin/main.exe
cd "$root"
dev/lint/_build/default/bin/main.exe dev/lint/ocaml_lint.conf
