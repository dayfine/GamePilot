#!/bin/sh
# Create a GitHub Release from staged artifacts and prune superseded prereleases.
#
# Environment:
#   RELEASE_VERSION    Release tag/version (e.g. "v0.1.0", "v0.1.0-rc.1", "nightly-2026-11-27").
#   RELEASE_KIND       One of "stable", "rc", or "nightly".
#   ARTIFACTS_DIR      Directory containing release archives and SHA256SUMS.txt.
#   GH_TOKEN           GitHub token with contents:write permission.
#   GITHUB_REPOSITORY  Optional owner/repo slug passed to gh --repo.
#   GITHUB_SHA         Target commit SHA (required for "nightly" releases).
set -eu

: "${RELEASE_VERSION:?RELEASE_VERSION must be set}"
: "${RELEASE_KIND:?RELEASE_KIND must be set}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

if [ ! -d "$ARTIFACTS_DIR" ]; then
  echo "publish_release.sh: artifacts directory not found: $ARTIFACTS_DIR" >&2
  exit 1
fi

set -- "$ARTIFACTS_DIR"/*
if [ ! -e "$1" ]; then
  echo "publish_release.sh: no artifacts found in $ARTIFACTS_DIR" >&2
  exit 1
fi

gh_release() {
  subcmd=$1
  shift
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    gh release "$subcmd" --repo "$GITHUB_REPOSITORY" "$@"
  else
    gh release "$subcmd" "$@"
  fi
}

case "$RELEASE_KIND" in
  stable)
    gh_release create "$RELEASE_VERSION" "$@" \
      --title "GamePilot $RELEASE_VERSION" \
      --generate-notes \
      --draft
    ;;
  nightly)
    TARGET_SHA=${GITHUB_SHA:-}
    : "${TARGET_SHA:?GITHUB_SHA must be set for nightly releases}"
    gh_release create "$RELEASE_VERSION" "$@" \
      --target "$TARGET_SHA" \
      --title "GamePilot $RELEASE_VERSION" \
      --generate-notes \
      --prerelease
    ;;
  rc)
    gh_release create "$RELEASE_VERSION" "$@" \
      --title "GamePilot $RELEASE_VERSION" \
      --generate-notes \
      --prerelease
    ;;
  *)
    echo "publish_release.sh: unsupported RELEASE_KIND '$RELEASE_KIND'" >&2
    exit 1
    ;;
esac

if [ "$RELEASE_KIND" = "nightly" ]; then
  gh_release list --limit 200 --json tagName \
    | jq -r '[.[] | .tagName | select(startswith("nightly-"))] | sort | reverse | .[7:] | .[]' \
    | while IFS= read -r old_tag; do
        [ -n "$old_tag" ] || continue
        echo "Pruning old nightly release: $old_tag"
        gh_release delete "$old_tag" --yes --cleanup-tag
      done
elif [ "$RELEASE_KIND" = "stable" ]; then
  gh_release list --limit 200 --json tagName \
    | jq -r --arg prefix "${RELEASE_VERSION}-rc." '[.[] | .tagName | select(startswith($prefix))] | .[]' \
    | while IFS= read -r rc_tag; do
        [ -n "$rc_tag" ] || continue
        echo "Pruning superseded RC release: $rc_tag"
        gh_release delete "$rc_tag" --yes --cleanup-tag
      done
fi
