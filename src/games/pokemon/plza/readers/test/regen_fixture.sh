#!/bin/sh
# Remakes fixtures/switch.probes.jsonl: every frame in images/switch (console
# captures from the fork's CommandLineTests, jpg) and the fork's synthetic test
# frames (draw_synthetic_frames.py), probed by the daemon's probe_images on the
# native viewport with every PLZA reader's probes (write_probe_spec.exe, its
# find templates copied from assets/templates beside the spec). Also
# fixtures/switch.shifted.probes.jsonl and switch.shifted.rg.probes.jsonl:
# every frame again with its colors
# shifted as another capture card might show them, by
# dev/reader_fixtures/shift_frame.py (brightness times 0.9 and 1.1, one channel
# plus or minus 12, 10% toward mid-grey), named <shift>/<folder>/<frame>.png:
# the jpg frames are decoded to png first, so a shift adds no JPEG loss. The
# shifted frames are probed without the minimap's cells (write_probe_spec.ml).
# The brightness and blue shifts go to the first file, the red, green and grey
# ones to the second: one file of all nine is over GitHub's 50 MB warning.
# Also fixtures/switch.second.probes.jsonl: every frame again, probed by what
# a two-frame read subscribes from what the frame shows (write_probe_spec.exe
# --second): the party bars' tests made from its cards, the caught mark's box
# above its plate.
# Also fixtures/gifts.probes.jsonl: every capture, and images/mystery-gift's
# (console B's own, png), probed by the Mystery Gift steps' readers alone
# (write_probe_spec.exe --gifts, the gift name's template from
# assets/gift-name-vivillon.png), and fixtures/gifts.shifted.probes.jsonl: the
# main menu's frame and images/mystery-gift's shifted.
# The Python steps need Pillow ($SHIFT_PYTHON, default python3; e.g.
# "uv run --with pillow python3").
#
#   sh games/pokemon/plza/readers/test/regen_fixture.sh
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SHIFT_FRAME=$SRC/../dev/reader_fixtures/shift_frame.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/spec" "$work/frames" "$work/lossless" "$work/shifted"
cp "$SRC/games/pokemon/plza/assets/templates/"*.png "$work/spec/"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe) \
    >"$work/spec/probes.json"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
    -- --no-minimap) >"$work/spec/shifted.probes.json"
cp -R "$HERE/images/switch/." "$work/frames/"
$SHIFT_PYTHON "$HERE/draw_synthetic_frames.py" "$work/frames"
(cd "$work/frames" && "$PROBE_IMAGES" --spec "$work/spec/probes.json" \
    --viewport native ./*/*.jpg ./*/*.png) >"$HERE/fixtures/switch.probes.jsonl"
mkdir "$work/second"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
    -- --second "$HERE/fixtures/switch.probes.jsonl" "$work/second")
: >"$HERE/fixtures/switch.second.probes.jsonl"
for spec in "$work"/second/*/*.json; do
    rel=${spec#"$work/second/"}
    frame=$(cd "$work/frames" && ls "./${rel%.json}".* | head -n 1)
    (cd "$work/frames" && "$PROBE_IMAGES" --spec "$spec" --viewport native \
        "$frame") >>"$HERE/fixtures/switch.second.probes.jsonl"
done
(cd "$work/frames" && $SHIFT_PYTHON -c '
import os, sys
from PIL import Image
for path in sys.argv[2:]:
    out = os.path.join(sys.argv[1], os.path.splitext(path)[0] + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(path).convert("RGB").save(out)
' "$work/lossless" ./*/*)
(cd "$work/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted" ./*/*.png)
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$work/spec/shifted.probes.json" \
    --viewport native ./b*/*/*.png) >"$HERE/fixtures/switch.shifted.probes.jsonl"
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$work/spec/shifted.probes.json" \
    --viewport native ./[gr]*/*/*.png) \
    >"$HERE/fixtures/switch.shifted.rg.probes.jsonl"
cp "$SRC/games/pokemon/plza/assets/gift-name-vivillon.png" "$work/spec/"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
    -- --gifts) >"$work/spec/gifts.probes.json"
mkdir "$work/frames/mystery-gift" "$work/lossless/mystery-gift"
cp "$HERE/images/mystery-gift/"*.png "$work/frames/mystery-gift/"
cp "$HERE/images/mystery-gift/"*.png "$work/lossless/mystery-gift/"
(cd "$work/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" "$work/shifted" \
    ./mystery-gift/*.png)
(cd "$work/frames" && "$PROBE_IMAGES" --spec "$work/spec/gifts.probes.json" \
    --viewport native ./*/*.jpg ./mystery-gift/*.png) \
    >"$HERE/fixtures/gifts.probes.jsonl"
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$work/spec/gifts.probes.json" \
    --viewport native ./*/tutorial-cards/it-menu-no-card.png \
    ./*/mystery-gift/*.png) >"$HERE/fixtures/gifts.shifted.probes.jsonl"
