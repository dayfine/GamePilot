#!/bin/sh
# Prints each open PR's gates and its one next step (the loop in AGENTS.md, "PR gate loop"):
#   PR  CI  STRUCT  NEXT  DRAFT  TITLE
# CI is pass / fail / pending / none; STRUCT is the qc-structural verdict at the PR's tip: ok /
# rework / stale(<sha>) / none / skip (docs-only). NEXT is fix CI / wait for CI /
# run qc-structural / rework / merge (structural: reason) / user review. DRAFT is what the PR's
# draft flag should be: ready once only a merge or the user's review is left, else draft.
# dev/review/gate_row.py reads the verdicts.
#   sh dev/review/pr_gate_status.sh            every open PR
#   sh dev/review/pr_gate_status.sh 25 26      these PRs
#   sh dev/review/pr_gate_status.sh --sync-draft [PR...]
#                                              also sets each PR's draft flag to its DRAFT column
# GAMEPILOT_REPO overrides the repository (default dayfine/GamePilot).
# The file list comes from the REST API, paged: `gh pr view --json files` stops at 100 files,
# which hid a large refactor's structural changes.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=${GAMEPILOT_REPO:-dayfine/GamePilot}
sync=0
if [ "${1:-}" = "--sync-draft" ]; then
    sync=1
    shift
fi
if [ $# -eq 0 ]; then
    set -- $(gh pr list --repo "$repo" --state open --limit 100 --json number --jq '.[].number')
fi
files=$(mktemp)
trap 'rm -f "$files"' EXIT
printf 'PR\tCI\tSTRUCT\tNEXT\tDRAFT\tTITLE\n'
for pr in "$@"; do
    gh api --paginate "repos/$repo/pulls/$pr/files?per_page=100" \
        --jq '.[] | {path: .filename, status: .status}' >"$files"
    row=$(gh pr view "$pr" --repo "$repo" \
        --json number,title,headRefOid,reviews,statusCheckRollup,mergeable |
        python3 -I "$here/gate_row.py" "$files")
    printf '%s\n' "$row"
    [ "$sync" -eq 1 ] || continue
    want=$(printf '%s\n' "$row" | cut -f 5)
    is_draft=$(gh pr view "$pr" --repo "$repo" --json isDraft --jq .isDraft)
    if [ "$want" = ready ] && [ "$is_draft" = true ]; then
        gh pr ready "$pr" --repo "$repo" >/dev/null && echo "#$pr: marked ready"
    elif [ "$want" = draft ] && [ "$is_draft" = false ]; then
        gh pr ready "$pr" --repo "$repo" --undo >/dev/null && echo "#$pr: back to draft"
    fi
done
