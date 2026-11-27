#!/bin/sh
# Verify that all CI workflow runs on GITHUB_SHA have completed and succeeded.
#
# Environment:
#   GITHUB_REPOSITORY  owner/repo slug (e.g. "dayfine/GamePilot").
#   GITHUB_SHA         Full commit SHA to check.
#   GH_TOKEN           GitHub token with actions:read permission.
set -eu

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
: "${GITHUB_SHA:?GITHUB_SHA must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

RUNS_JSON=$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs?head_sha=${GITHUB_SHA}&per_page=100")
CI_WORKFLOWS='[".github/workflows/ocaml.yml", ".github/workflows/daemon.yml", ".github/workflows/review-tools.yml"]'

MATCHED=$(printf '%s\n' "$RUNS_JSON" | jq --argjson wfs "$CI_WORKFLOWS" '
  [.workflow_runs[] | select(.path as $p | $wfs | index($p))]
  | group_by(.path)
  | map(max_by(.id))
')

COUNT=$(printf '%s\n' "$MATCHED" | jq 'length')
if [ "$COUNT" -eq 0 ]; then
  echo "::error::No completed CI workflow runs found for ${GITHUB_SHA}; refusing to release." >&2
  exit 1
fi

echo "CI runs for ${GITHUB_SHA}:"
printf '%s\n' "$MATCHED" | jq -r '.[] | "  \(.path): status=\(.status) conclusion=\(.conclusion)"'

BAD=$(printf '%s\n' "$MATCHED" | jq '[.[] | select(.status != "completed" or .conclusion != "success")] | length')
if [ "$BAD" -ne 0 ]; then
  echo "::error::One or more CI workflows are not green on ${GITHUB_SHA}; refusing to release." >&2
  exit 1
fi
