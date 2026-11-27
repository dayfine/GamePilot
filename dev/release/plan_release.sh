#!/bin/sh
# Compute release metadata for GitHub Actions and write it to GITHUB_OUTPUT.
#
# Environment:
#   GITHUB_EVENT_NAME  Triggering event ("schedule", "push", "workflow_dispatch", ...).
#   GITHUB_REF_TYPE    Ref type ("tag" or "branch").
#   GITHUB_REF_NAME    Tag or branch name.
#   INPUT_VERSION      Optional version label for workflow_dispatch dry runs (default: "dev").
#   GITHUB_OUTPUT      Path to the GitHub Actions step output file.
set -eu

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

EVENT_NAME=${GITHUB_EVENT_NAME:-}
REF_TYPE=${GITHUB_REF_TYPE:-}
REF_NAME=${GITHUB_REF_NAME:-}
INPUT_VER=${INPUT_VERSION:-}

write_outputs() {
  {
    echo "short_sha=$1"
    echo "should_build=$2"
    echo "should_publish=$3"
    echo "version=$4"
    echo "release_kind=$5"
  } >> "$GITHUB_OUTPUT"
}

HEAD_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)

if [ "$EVENT_NAME" = "schedule" ]; then
  VERSION="nightly-$(date -u +%Y-%m-%d)"
  LAST_NIGHTLY=$(git tag -l 'nightly-*' --sort=-refname | head -n 1)
  if [ -n "$LAST_NIGHTLY" ]; then
    LAST_SHA=$(git rev-parse "${LAST_NIGHTLY}^{commit}")
    if [ "$LAST_SHA" = "$HEAD_SHA" ]; then
      echo "No new commits on main since ${LAST_NIGHTLY} (${HEAD_SHA}); skipping nightly."
      write_outputs "$SHORT_SHA" "false" "false" "$VERSION" "nightly"
      exit 0
    fi
  fi
  if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null 2>&1; then
    echo "Tag ${VERSION} already exists; skipping duplicate nightly."
    write_outputs "$SHORT_SHA" "false" "false" "$VERSION" "nightly"
    exit 0
  fi
  write_outputs "$SHORT_SHA" "true" "true" "$VERSION" "nightly"
elif [ "$REF_TYPE" = "tag" ]; then
  : "${REF_NAME:?GITHUB_REF_NAME must be set for tag refs}"
  VERSION="$REF_NAME"
  case "$VERSION" in
    *-*) KIND="rc" ;;
    *)   KIND="stable" ;;
  esac
  write_outputs "$SHORT_SHA" "true" "true" "$VERSION" "$KIND"
else
  VERSION=${INPUT_VER:-dev}
  write_outputs "$SHORT_SHA" "true" "false" "$VERSION" "dry-run"
fi
