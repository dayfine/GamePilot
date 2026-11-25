#!/bin/sh
# Remakes fixtures/home.probes.jsonl from images/: console B's captures of
# Pokémon HOME and the Switch's HOME menu (1920x1080, 2026-11-24 and -25, copied
# byte-for-byte), probed by the daemon's probe_images on the whole frame
# (native), with the templates from pokemon/home/assets and PLZA's HOME icon.
# Also fixtures/home.shifted.probes.jsonl: every capture again with its colors
# shifted as another capture card might show them, by
# dev/reader_fixtures/shift_frame.py, named <shift>/<image>. shift_frame.py
# needs Pillow ($SHIFT_PYTHON, default python3).
#
#   sh pokemon/home/test/regen_fixture.sh
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SHIFT_FRAME=$SRC/../dev/reader_fixtures/shift_frame.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/spec" "$work/shifted"
(cd "$SRC" && dune exec pokemon/home/test/write_probe_spec.exe) >"$work/spec/spec.json"
cp "$SRC"/pokemon/home/assets/*.png "$work/spec/"
cp "$SRC/games/pokemon/plza/assets/home-game-icon.png" "$work/spec/"
(cd "$HERE/images" && "$PROBE_IMAGES" --spec "$work/spec/spec.json" --viewport native ./*.png) \
    >"$HERE/fixtures/home.probes.jsonl"
(cd "$HERE/images" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted" ./*.png)
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$work/spec/spec.json" --viewport native ./*/*.png) \
    >"$HERE/fixtures/home.shifted.probes.jsonl"
