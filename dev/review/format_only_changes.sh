#!/bin/sh
# Lists the files a branch changes without changing what they say, so a reviewer (qc-structural
# row S2) and CI can flag edits a PR is not about. One line per file:
#   format-only <path>    the file's text differs but not its content: JSON files that parse to
#                         the same value, any other file whose only difference is whitespace
#                         (spaces, tabs, line breaks: a reflow or reindent)
#   moved <old> -> <new>  a rename with no content change
# Added and deleted files are never listed. Compares the merge base of BASE and HEAD with HEAD,
# as a PR's diff does. Always exits 0 unless git fails: this is a report, the reviewer decides.
#   sh dev/review/format_only_changes.sh [BASE [HEAD]]    (defaults: origin/main, HEAD)
set -eu
base=${1:-origin/main}
head=${2:-HEAD}
from=$(git merge-base "$base" "$head")

same_json() { # two blob specs
    python3 -I -c '
import json, subprocess, sys
def load(spec):
    return json.loads(subprocess.run(["git", "show", spec], check=True, capture_output=True).stdout)
try:
    sys.exit(0 if load(sys.argv[1]) == load(sys.argv[2]) else 1)
except ValueError:
    sys.exit(1)
' "$1" "$2"
}

same_text_but_whitespace() { # two blob specs
    [ "$(git show "$1" | tr -d ' \t\r\n')" = "$(git show "$2" | tr -d ' \t\r\n')" ]
}

git diff --name-status -M "$from" "$head" | while IFS="$(printf '\t')" read -r status path new; do
    case "$status" in
        R100) echo "moved $path -> $new" ;;
        M*)
            # A binary file (a .gz replay, a .png) has no text to compare: its bytes changed.
            if [ "$(git diff --numstat "$from" "$head" -- "$path" | cut -f1)" = "-" ]; then
                continue
            fi
            case "$path" in
                *.json) if same_json "$from:$path" "$head:$path"; then echo "format-only $path"; fi ;;
                *) if same_text_but_whitespace "$from:$path" "$head:$path"; then
                    echo "format-only $path"
                fi ;;
            esac
            ;;
    esac
done
