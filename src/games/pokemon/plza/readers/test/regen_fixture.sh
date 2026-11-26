#!/bin/sh
# Remakes fixtures/<folder>.probes.jsonl for each image folder: every frame
# in images/switch/<folder> (console captures from the fork's
# CommandLineTests, jpg; box-cells' png, redacted to the Boxes' probes as its
# README says) or, for the folder synthetic, the fork's synthetic
# test frames (draw_synthetic_frames.py), probed by the daemon's probe_images
# on the native viewport with every PLZA reader's probes (write_probe_spec.exe, its
# find templates copied from assets/templates beside the spec). Also
# fixtures/<folder>.shifted.probes.jsonl: every frame again with its colors
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
# Also fixtures/<folder>.second.probes.jsonl: every frame again, probed by what
# a two-frame read subscribes from what the frame shows (write_probe_spec.exe
# --second): the party bars' tests made from its cards, the caught mark's box
# above its plate. And fixtures/<folder>.shifted.second.probes.jsonl likewise
# for every shifted frame, from its own first read.
# Also, for the new game, fixtures/intro/intro.probes.jsonl: images/new-game's
# frames (the fork's AutoStoryNewGame/2026-11-15 captures, JPEG quality 80 at
# 1080p: at 640x360 the look picker's corners and the keyboard's cursor no
# longer read; and home-*, console B's Switch HOME of 2026-11-24 and -25, png,
# redacted as images/new-game/README.md says) probed by the new game's readers
# alone (write_probe_spec.exe --intro, PLZA's HOME title template from
# assets/), and fixtures/intro/intro.shifted.probes.jsonl: each of them once
# shifted (--one). Remade with every folder, or alone as the FOLDER intro.
# Also fixtures/gifts/: the Mystery Gift steps' readers alone
# (write_probe_spec.exe --gifts en, the gift name's template from
# assets/gift-name-vivillon-poke-ball-en.png) on every capture and images/mystery-gift's
# (console B's own, png, redacted as its README says) in gifts.probes.jsonl; the main menu's frame
# (tutorial-cards/it-menu-no-card) and images/mystery-gift's, all nine shifts
# each, in gifts.shifted.probes.jsonl; and images/mystery-gift's frames and
# their nine shifts each, the gift's name matched by its French template
# (--gifts fr), in gifts.fr.probes.jsonl, and by its Japanese one (--gifts
# ja) in gifts.ja.probes.jsonl. Remade with every folder, or alone as the
# FOLDER gifts.
# The Python steps need Pillow ($SHIFT_PYTHON, default python3; e.g.
# "uv run --with pillow python3").
#
#   sh games/pokemon/plza/readers/test/regen_fixture.sh [FOLDER...]
#
# remakes the named folders' four files (e.g. party-bar, synthetic; intro its
# two), or with
# no FOLDER every folder's (dropping the files of folders no longer there).
# Run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images).

set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SHIFT_FRAME=$SRC/../dev/reader_fixtures/shift_frame.py
FIXTURES=$HERE/fixtures
if [ $# -eq 0 ]; then
    set -- $(ls "$HERE/images/switch") synthetic intro gifts
    rm -f "$FIXTURES"/*.probes.jsonl
fi
for folder in "$@"; do
    case $folder in synthetic | intro | gifts) continue ;; esac
    if [ ! -d "$HERE/images/switch/$folder" ]; then
        echo "no image folder images/switch/$folder" >&2
        exit 1
    fi
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/spec" "$work/frames" "$work/lossless" "$work/shifted" \
    "$work/second"
cp "$SRC/games/pokemon/plza/assets/templates/"*.png "$work/spec/"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe) \
    >"$work/spec/probes.json"
(cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
    -- --no-minimap) >"$work/spec/shifted.probes.json"

# Prints the folder's frames, ./<folder>/<frame>.<ext>, run in $work/frames.
folder_frames() {
    for f in "./$1"/*.jpg "./$1"/*.png; do
        if [ -e "$f" ]; then echo "$f"; fi
    done
}

# second_reads FIXTURE FRAMES OUT: each frame's second read, as FIXTURE's
# first reads ask for it, its frames under FRAMES.
second_reads() {
    rm -rf "$work/second"
    mkdir "$work/second"
    (cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
        -- --second "$1" "$work/second")
    : >"$3"
    find "$work/second" -name '*.json' | sort | while read -r spec; do
        rel=${spec#"$work/second/"}
        frame=$(cd "$2" && ls "./${rel%.json}".* | head -n 1)
        (cd "$2" && "$PROBE_IMAGES" --spec "$spec" --viewport native \
            "$frame") >>"$3"
    done
}

regen_folder() {
    folder=$1
    if [ "$folder" = synthetic ]; then
        $SHIFT_PYTHON "$HERE/draw_synthetic_frames.py" "$work/frames"
    else
        cp -R "$HERE/images/switch/$folder" "$work/frames/$folder"
    fi
    frames=$(cd "$work/frames" && folder_frames "$folder")
    (cd "$work/frames" && "$PROBE_IMAGES" --spec "$work/spec/probes.json" \
        --viewport native $frames) >"$FIXTURES/$folder.probes.jsonl"
    second_reads "$FIXTURES/$folder.probes.jsonl" "$work/frames" \
        "$FIXTURES/$folder.second.probes.jsonl"
    (cd "$work/frames" && $SHIFT_PYTHON -c '
import os, sys
from PIL import Image
for path in sys.argv[2:]:
    out = os.path.join(sys.argv[1], os.path.splitext(path)[0] + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(path).convert("RGB").save(out)
' "$work/lossless" $frames)
    (cd "$work/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" --one "$work/shifted" \
        "./$folder"/*.png)
    (cd "$work/shifted" && "$PROBE_IMAGES" \
        --spec "$work/spec/shifted.probes.json" --viewport native \
        ./*/"$folder"/*.png) >"$FIXTURES/$folder.shifted.probes.jsonl"
    second_reads "$FIXTURES/$folder.shifted.probes.jsonl" "$work/shifted" \
        "$FIXTURES/$folder.shifted.second.probes.jsonl"
}

# fixtures/intro/, as the header says.
regen_intro() {
    i=$work/intro
    mkdir -p "$i/frames" "$i/lossless/new-game" "$i/shifted" "$FIXTURES/intro"
    (cd "$SRC" && dune exec games/pokemon/plza/readers/test/write_probe_spec.exe \
        -- --intro) >"$work/spec/intro.probes.json"
    cp "$SRC/games/pokemon/plza/assets/switch-home-title-legends-za.png" \
        "$work/spec/"
    cp -R "$HERE/images/new-game" "$i/frames/"
    rm -f "$i/frames/new-game/README.md"
    (cd "$i/frames" && "$PROBE_IMAGES" --spec "$work/spec/intro.probes.json" \
        --viewport native ./new-game/*.jpg ./new-game/*.png) \
        >"$FIXTURES/intro/intro.probes.jsonl"
    (cd "$i/frames" && $SHIFT_PYTHON -c '
import os, sys
from PIL import Image
for path in sys.argv[2:]:
    out = os.path.join(sys.argv[1], os.path.splitext(path)[0] + ".png")
    Image.open(path).convert("RGB").save(out)
' "$i/lossless" ./new-game/*.jpg ./new-game/*.png)
    (cd "$i/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" --one "$i/shifted" \
        ./new-game/*.png)
    (cd "$i/shifted" && "$PROBE_IMAGES" \
        --spec "$work/spec/intro.probes.json" --viewport native ./*/*/*.png) \
        >"$FIXTURES/intro/intro.shifted.probes.jsonl"
}

# fixtures/gifts/, as the header says.
regen_gifts() {
    mkdir -p "$FIXTURES/gifts" "$work/gifts" "$work/gifts/frames" \
        "$work/gifts/lossless/tutorial-cards" "$work/gifts/shifted"
    cp "$SRC/games/pokemon/plza/assets/"gift-name-vivillon-poke-ball-*.png "$work/spec/"
    for language in en fr ja zh-Hans; do
        (cd "$SRC" && dune exec \
            games/pokemon/plza/readers/test/write_probe_spec.exe \
            -- --gifts "$language") >"$work/spec/gifts.$language.probes.json"
    done
    cp -R "$HERE/images/switch/." "$work/gifts/frames/"
    cp -R "$HERE/images/mystery-gift" "$work/gifts/frames/mystery-gift"
    cp -R "$HERE/images/mystery-gift" "$work/gifts/lossless/mystery-gift"
    $SHIFT_PYTHON -c '
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2])
' "$HERE/images/switch/tutorial-cards/it-menu-no-card.jpg" \
        "$work/gifts/lossless/tutorial-cards/it-menu-no-card.png"
    (cd "$work/gifts/lossless" && $SHIFT_PYTHON "$SHIFT_FRAME" \
        "$work/gifts/shifted" ./*/*.png)
    (cd "$work/gifts/frames" && "$PROBE_IMAGES" \
        --spec "$work/spec/gifts.en.probes.json" --viewport native \
        ./*/*.jpg ./*/*.png) >"$FIXTURES/gifts/gifts.probes.jsonl"
    (cd "$work/gifts/shifted" && "$PROBE_IMAGES" \
        --spec "$work/spec/gifts.en.probes.json" --viewport native \
        ./*/*/*.png) >"$FIXTURES/gifts/gifts.shifted.probes.jsonl"
    for language in fr ja zh-Hans; do
        out=$FIXTURES/gifts/gifts.$language.probes.jsonl
        (cd "$work/gifts/frames" && "$PROBE_IMAGES" \
            --spec "$work/spec/gifts.$language.probes.json" \
            --viewport native ./mystery-gift/*.png) >"$out"
        (cd "$work/gifts/shifted" && "$PROBE_IMAGES" \
            --spec "$work/spec/gifts.$language.probes.json" \
            --viewport native ./*/mystery-gift/*.png) >>"$out"
    done
}

for folder in "$@"; do
    case $folder in
    intro) regen_intro ;;
    gifts) regen_gifts ;;
    *) regen_folder "$folder" ;;
    esac
done
