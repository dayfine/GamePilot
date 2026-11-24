#!/bin/sh
# Remakes fixtures/switch.probes.jsonl from images/: console B's captures
# (1920x1080, copied byte-for-byte), probed by the daemon's probe_images with
# the switch backend's viewport (nso-gba).
#
#   sh core/switch_home/test/regen_fixture.sh
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
spec=$(mktemp)
trap 'rm -f "$spec"' EXIT
(cd "$SRC" && dune exec core/switch_home/test/write_probe_spec.exe) >"$spec"
(cd "$HERE/images" && "$PROBE_IMAGES" --spec "$spec" --viewport nso-gba ./*.png) \
    >"$HERE/fixtures/switch.probes.jsonl"
