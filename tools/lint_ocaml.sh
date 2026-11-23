#!/bin/sh
# Builds the OCaml linters in lint/ and runs them over the roots in tools/ocaml_lint.conf.
# Waived findings live in tools/ocaml_lint_exceptions.conf (one reason per entry).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/lint"
dune build ./bin/main.exe
cd "$root"
lint/_build/default/bin/main.exe tools/ocaml_lint.conf
