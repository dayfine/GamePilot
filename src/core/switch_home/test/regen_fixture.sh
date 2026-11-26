#!/bin/sh
# Remakes fixtures/switch.probes.jsonl from images/: console B's captures
# (1920x1080, copied byte-for-byte), probed by the daemon's probe_images with
# the switch backend's viewport (nso-gba). Also fixtures/switch.shifted.probes.jsonl:
# every capture again with its colors shifted as another capture card might
# show them, by dev/reader_fixtures/shift_frame.py (brightness times 0.9 and 1.1,
# one channel plus or minus 12, 10% toward mid-grey), named <shift>/<image>.
# Likewise fixtures/delete_save.probes.jsonl and delete_save.shifted.probes.jsonl
# from images/delete-save/ with the native viewport (System Settings, the whole
# frame) and the games' delete-save icons (the delete-save-icon*.png under src/games).
# Likewise fixtures/code_keyboard.probes.jsonl and
# code_keyboard.shifted.probes.jsonl from images/keyboard/ and the HOME captures
# in images/ (no keyboard there) with the native viewport, the keyboards alone
# shifted.
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
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/home" "$work/delete_save" "$work/shifted" "$work/shifted_delete_save"
spec=$work/home/spec.json
ds_spec=$work/delete_save/spec.json
(cd "$SRC" && dune exec core/switch_home/test/write_probe_spec.exe) >"$spec"
(cd "$SRC" && dune exec core/switch_home/test/write_probe_spec.exe delete-save) >"$ds_spec"
cp "$SRC/games/pokemon/plza/assets/delete-save-icon.png" "$work/delete_save/plza-icon.png"
cp "$SRC/games/frlg/assets/delete-save-icon-firered.png" "$work/delete_save/firered-icon.png"
(cd "$HERE/images" && "$PROBE_IMAGES" --spec "$spec" --viewport nso-gba ./*.png) \
    >"$HERE/fixtures/switch.probes.jsonl"
(cd "$HERE/images" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted" ./*.png)
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$spec" --viewport nso-gba ./*/*.png) \
    >"$HERE/fixtures/switch.shifted.probes.jsonl"
(cd "$HERE/images/delete-save" && "$PROBE_IMAGES" --spec "$ds_spec" --viewport native ./*.png) \
    >"$HERE/fixtures/delete_save.probes.jsonl"
(cd "$HERE/images/delete-save" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted_delete_save" ./*.png)
(cd "$work/shifted_delete_save" && "$PROBE_IMAGES" --spec "$ds_spec" --viewport native ./*/*.png) \
    >"$HERE/fixtures/delete_save.shifted.probes.jsonl"
kb_spec=$work/code_keyboard.json
mkdir "$work/kb" "$work/shifted_kb"
(cd "$SRC" && dune exec core/switch_home/test/write_probe_spec.exe code-keyboard) >"$kb_spec"
cp "$HERE"/images/keyboard/*.png "$HERE"/images/home-cursor-on-last-played.png "$HERE"/images/user-select.png "$work/kb/"
(cd "$work/kb" && "$PROBE_IMAGES" --spec "$kb_spec" --viewport native ./*.png) \
    >"$HERE/fixtures/code_keyboard.probes.jsonl"
(cd "$work/kb" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted_kb" ./*-cursor-on-1.png)
(cd "$work/shifted_kb" && "$PROBE_IMAGES" --spec "$kb_spec" --viewport native ./*/*.png) \
    >"$HERE/fixtures/code_keyboard.shifted.probes.jsonl"
