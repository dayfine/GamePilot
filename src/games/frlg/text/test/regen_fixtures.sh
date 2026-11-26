#!/bin/sh
# Remakes the probe_images fixtures of the FRLG text reader test from the
# source images. images.map has one image per line:
#
#   <screen> <backend> <root> <path under the root>|<tagged name in the fixture>
#
# <screen> is one of write_text_probe_spec's screens, <backend> switch or mgba,
# <root> clt (CommandLineTests, $COMMANDLINETESTS_DIR, default
# ~/Projects/CommandLineTests) or repo (a file in this repository, given from
# its root: lab captures live under games/frlg/readers/test/images/, shared
# with the screen reader tests; that folder's regen_fixtures.sh says how to add
# one), or shift=<shift> (that repo file with its colors shifted by
# dev/reader_fixtures/shift_frame.py, which needs Pillow: $SHIFT_PYTHON, default
# python3, e.g. "uv run --with pillow python3"). The tagged name is what
# fixtures/expected.txt names.
#
#   sh games/frlg/text/test/regen_fixtures.sh
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images). Switch captures use the fork's FRLG GAME_BOX as
# the viewport; mGBA frames are the picture. Each line keeps only its
# $KEEP_BEST (default 4) best-scoring candidates per image: the reader picks the
# best one, so the rest never decide a reading, and the fixtures stay small.
set -eu

CLT=${COMMANDLINETESTS_DIR:-$HOME/Projects/CommandLineTests}
KEEP_BEST=${KEEP_BEST:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../../.." && pwd)
REPO=$(cd "$SRC/.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SWITCH_VIEWPORT=0.09375,0.00462963,0.8125,0.962963
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

(cd "$SRC" && dune exec games/frlg/text/test/write_text_probe_spec.exe -- "$WORK")

# Keeps each line's best candidates (lowest score) on every image.
keep_best() {
  python3 -c '
import json, sys
keep = int(sys.argv[1])
for text in sys.stdin:
    image = json.loads(text)
    by_line = {}
    for probe, result in image["probes"].items():
        by_line.setdefault(probe.split("/", 1)[0], []).append((result["score"], probe))
    best = {p for scored in by_line.values() for _, p in sorted(scored)[:keep]}
    image["probes"] = {p: r for p, r in image["probes"].items() if p in best}
    print(json.dumps(image, ensure_ascii=False, separators=(",", ":")))
' "$KEEP_BEST"
}

# Probes one screen's images of one backend, in map order.
probe() {
  screen=$1 backend=$2
  shift 2
  images=
  while IFS='|' read -r source tagged; do
    set -- $source
    [ "$1" = "$screen" ] && [ "$2" = "$backend" ] || continue
    mkdir -p "$WORK/images/$(dirname "$tagged")"
    case $3 in
    clt) cp "$CLT/$4" "$WORK/images/$tagged" ;;
    repo) cp "$REPO/$4" "$WORK/images/$tagged" ;;
    shift=*)
      (cd "$REPO" && $SHIFT_PYTHON dev/reader_fixtures/shift_frame.py "$WORK/shifted" "$4")
      cp "$WORK/shifted/${3#shift=}/$4" "$WORK/images/$tagged"
      ;;
    *) echo "unknown root $3" >&2 && exit 1 ;;
    esac
    images="$images $tagged"
  done <"$HERE/images.map"
  [ -n "$images" ] || return 0
  if [ "$backend" = switch ]; then
    set -- --viewport "$SWITCH_VIEWPORT"
  else
    set --
  fi
  # shellcheck disable=SC2086
  (cd "$WORK/images" && "$PROBE_IMAGES" --spec "$WORK/$screen.json" "$@" $images) | keep_best
}

for screen in bag_items bag_key_items tm_case summary_moves battle_opening battle_prompt bag_counts berry_pouch_numbers summary_level mail_editor start_menu card_numbers pc_message pokedex_list pokedex_numbers naming_entry box_title; do
  {
    probe "$screen" switch
    probe "$screen" mgba
  } >"$HERE/fixtures/$screen.probes.jsonl"
done
