#!/bin/sh
# Fails if any dune file links C, or an opam dependency is not allowlisted.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
bad=$(find "$root/programs" -name dune -type f -exec grep -l -E 'foreign_stubs|foreign_archives|extra_objects|ctypes' {} + || true)
if [ -n "$bad" ]; then
    echo "C linkage in dune files (forbidden):"; echo "$bad"; exit 1
fi
for opam in "$root"/programs/*.opam; do
    [ -f "$opam" ] || continue
    for dep in $(sed -n '/^depends:/,/^\]/p' "$opam" | grep -o '^ *"[a-z0-9_-]*"' | tr -d ' "'); do
        if ! grep -qx "$dep" "$root/tools/opam-allowlist.txt"; then
            echo "$opam: dependency '$dep' is not in tools/opam-allowlist.txt"; exit 1
        fi
    done
done
echo "lint_dune: ok"
