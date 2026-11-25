#!/bin/sh
# Remakes fixtures/switch.probes.jsonl: every frame in images/switch (console
# captures from the fork's CommandLineTests, jpg) and the fork's synthetic test
# frames (draw_synthetic_frames.py), probed by the daemon's probe_images on the
# native viewport with every PLZA reader's probes (write_probe_spec.exe, its
# find templates copied from assets/templates beside the spec). Also
# fixtures/switch.shifted.probes.jsonl: every frame again with its colors
# shifted as another capture card might show them, by
# dev/reader_fixtures/shift_frame.py --one (one shift per frame, picked from
# its name: brightness times 0.9 or 1.1, one channel plus or minus 12, or 10%
# toward mid-grey), named <shift>/<folder>/<frame>.png: the jpg frames are
# decoded to png first, so a shift adds no JPEG loss. The shifted frames are
# probed without the minimap's cells (write_probe_spec.ml). All nine shifts of
# every frame would be about 85 MB.
# The fork's 1080p captures are kept at 640x360 where every reader test still
# passes on them, at 1280x720 where one does not, and at 1080p (JPEG quality
# 80) where 720p fails too, and as captured where the daemon's blob_find_test
# reads them at 1080p (arrival-to-ad's 0001, 0033 and 0040); the scaled frames' arrow bearings moved by up to 6
# degrees (the fork's tolerance is 10), their expectations with them.
# Also fixtures/switch.second.probes.jsonl: every frame again, probed by what
# a two-frame read subscribes from what the frame shows (write_probe_spec.exe
# --second): the party bars' tests made from its cards, the caught mark's box
# above its plate.
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
(cd "$work/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" --one "$work/shifted" \
    ./*/*.png)
(cd "$work/shifted" && "$PROBE_IMAGES" --spec "$work/spec/shifted.probes.json" \
    --viewport native ./*/*/*.png) >"$HERE/fixtures/switch.shifted.probes.jsonl"
