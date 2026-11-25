#!/bin/sh
# Remakes fixtures/switch.probes.jsonl from images/: console B's captures
# (1920x1080, copied byte-for-byte), probed by the daemon's probe_images with
# the switch backend's viewport (nso-gba). Also fixtures/switch.shifted.probes.jsonl:
# every capture again with its colors shifted as another capture card might
# show them, by dev/reader_fixtures/shift_frame.py (brightness times 0.9 and 1.1,
# one channel plus or minus 12, 10% toward mid-grey), named <shift>/<image>.
# shift_frame.py needs Pillow ($SHIFT_PYTHON, default python3; e.g.
# "uv run --with pillow python3").
#
#   sh core/switch_home/test/regen_fixture.sh
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SHIFT_FRAME=$SRC/../dev/reader_fixtures/shift_frame.py
spec=$(mktemp)
shifted=$(mktemp -d)
trap 'rm -rf "$spec" "$shifted"' EXIT
(cd "$SRC" && dune exec core/switch_home/test/write_probe_spec.exe) >"$spec"
(cd "$HERE/images" && "$PROBE_IMAGES" --spec "$spec" --viewport nso-gba ./*.png) \
    >"$HERE/fixtures/switch.probes.jsonl"
(cd "$HERE/images" && $SHIFT_PYTHON "$SHIFT_FRAME" "$shifted" ./*.png)
(cd "$shifted" && "$PROBE_IMAGES" --spec "$spec" --viewport nso-gba ./*/*.png) \
    >"$HERE/fixtures/switch.shifted.probes.jsonl"
