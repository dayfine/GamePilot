#!/bin/sh
# Prints each open PR's gates and its one next step (the loop in AGENTS.md, "PR gate loop"):
#   PR  CI  STRUCT  NEXT  TITLE
# CI is pass / fail / pending / none; STRUCT is the qc-structural verdict at the PR's tip: ok /
# rework / stale(<sha>) / none / skip (docs-only). NEXT is fix CI / wait for CI /
# run qc-structural / rework / user review. dev/review/gate_row.py reads the verdicts.
#   sh dev/review/pr_gate_status.sh            every open PR
#   sh dev/review/pr_gate_status.sh 25 26      these PRs
# GAMEPILOT_REPO overrides the repository (default dayfine/GamePilot).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=${GAMEPILOT_REPO:-dayfine/GamePilot}
if [ $# -eq 0 ]; then
    set -- $(gh pr list --repo "$repo" --state open --limit 100 --json number --jq '.[].number')
fi
printf 'PR\tCI\tSTRUCT\tNEXT\tTITLE\n'
for pr in "$@"; do
    gh pr view "$pr" --repo "$repo" \
        --json number,title,headRefOid,files,reviews,statusCheckRollup,mergeable |
        python3 -I "$here/gate_row.py"
done
