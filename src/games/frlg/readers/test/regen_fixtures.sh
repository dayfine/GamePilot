#!/bin/sh
# Remakes the probe_images fixtures of the FRLG reader tests from the source
# images. Each fixture set has a map per backend, one image per line:
#
#   <root> <path under the root>|<tagged name in the fixture>
#
# <root> is clt (CommandLineTests, $COMMANDLINETESTS_DIR, default
# ~/Projects/CommandLineTests), clt@<commit> (a file at that commit of the
# CommandLineTests repo, for images not on its main), or repo (a file in this
# repository, given from its root: the lab's Switch captures and mGBA frames
# live under games/frlg/readers/test/images/, one copy each, shared by every
# map that names them). The tagged name is what the test reads its
# expectations from. Sets: screen (test_screen_readers.ml,
# the write_probe_spec default), menus (test_menu_readers.ml) and battle
# (test_battle_readers.ml); pc (test_pc_readers.ml), card
# (test_card_readers.ml) and ace (test_ace_readers.ml, shifted too) are made
# only when named. A set with no map for a
# backend skips that backend. The card set also writes card.<backend>.shifted:
# its real frames (every image but the renders under pret-trainer-card/)
# with their colors shifted by dev/reader_fixtures/shift_frame.py, which needs Pillow
# ($SHIFT_PYTHON, default python3; e.g. "uv run --with pillow python3"). The
# menus set writes menus.<backend>.shifted likewise, from the Seagallop list's
# frames (seagallop-one-island/), and the battle set battle.<backend>.shifted
# from Route 10's wild battles (dex-route10/).
#
#   sh games/frlg/readers/test/regen_fixtures.sh [screen|menus|battle ...]
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images). Switch captures use the daemon's nso-gba viewport
# (daemon/src/viewport.h, the fork's FRLG GAME_BOX); mGBA frames are the picture.
#
# To add a lab capture: copy the file byte-for-byte (no re-encode, no resize)
# into images/<switch|mgba>/<folder named for what it shows or where it came
# from>/, add a "repo src/games/frlg/readers/test/images/..." line to the map,
# and run this script.
set -eu

CLT=${COMMANDLINETESTS_DIR:-$HOME/Projects/CommandLineTests}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../../.." && pwd)
REPO=$(cd "$SRC/.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SHIFT_PYTHON=${SHIFT_PYTHON:-python3}
SWITCH_VIEWPORT=nso-gba
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Copies one map's images to $2 under their tagged names.
stage() {
  while IFS='|' read -r source tagged; do
    root=${source%% *}
    path=${source#* }
    mkdir -p "$2/$(dirname "$tagged")"
    case $root in
    clt) cp "$CLT/$path" "$2/$tagged" ;;
    clt@*) git -C "$CLT" show "${root#clt@}:$path" >"$2/$tagged" ;;
    repo) cp "$REPO/$path" "$2/$tagged" ;;
    *) echo "unknown root $root" >&2 && exit 1 ;;
    esac
  done <"$1"
}

# Probes one backend's images, in map order, into its fixture.
probe() {
  set_name=$1 backend=$2 spec=$3 fixture=$4
  shift 4
  map=$HERE/$set_name.$backend.map
  [ -f "$map" ] || return 0
  stage "$map" "$WORK/$set_name.$backend"
  images=$(cut -d'|' -f2 "$map")
  # shellcheck disable=SC2086
  (cd "$WORK/$set_name.$backend" && "$PROBE_IMAGES" --spec "$spec" "$@" $images) \
    >"$HERE/fixtures/$fixture"
}

# The tagged names of a set's frames that its shifted fixture holds.
shifted_frames() {
  case $1 in
  card) grep -v '/pret-trainer-card/' "$2" | cut -d'|' -f2 ;;
  menus) grep '/seagallop-one-island/' "$2" | cut -d'|' -f2 ;;
  battle) grep '/dex-route10/' "$2" | cut -d'|' -f2 ;;
  ace) cut -d'|' -f2 "$2" ;;
  esac
}

# Probes one backend's real frames, shifted in color, into its fixture; run
# after probe, which staged them. A backend with none of them is skipped.
probe_shifted() {
  set_name=$1 backend=$2 spec=$3 fixture=$4
  shift 4
  map=$HERE/$set_name.$backend.map
  [ -f "$map" ] || return 0
  out=$WORK/$set_name.$backend.shifted
  frames=$(shifted_frames "$set_name" "$map")
  [ -n "$frames" ] || return 0
  # shellcheck disable=SC2086
  (cd "$WORK/$set_name.$backend" && $SHIFT_PYTHON "$REPO/dev/reader_fixtures/shift_frame.py" "$out" $frames)
  images=$(cd "$out" && for s in *; do for f in $frames; do echo "$s/$f"; done; done)
  # shellcheck disable=SC2086
  (cd "$out" && "$PROBE_IMAGES" --spec "$spec" "$@" $images) >"$HERE/fixtures/$fixture"
}

regen() {
  set_name=$1
  spec=$WORK/$set_name.json
  if [ "$set_name" = screen ]; then
    (cd "$SRC" && dune exec games/frlg/readers/test/write_probe_spec.exe) >"$spec"
    prefix=
  else
    (cd "$SRC" && dune exec games/frlg/readers/test/write_probe_spec.exe -- "$set_name") >"$spec"
    prefix=$set_name.
  fi
  probe "$set_name" switch "$spec" "${prefix}switch.probes.jsonl" --viewport "$SWITCH_VIEWPORT"
  probe "$set_name" mgba "$spec" "${prefix}mgba.probes.jsonl"
  case $set_name in
  card | menus | battle | ace)
    probe_shifted "$set_name" switch "$spec" "${prefix}switch.shifted.probes.jsonl" --viewport "$SWITCH_VIEWPORT"
    probe_shifted "$set_name" mgba "$spec" "${prefix}mgba.shifted.probes.jsonl"
    ;;
  esac
}

[ $# -gt 0 ] || set -- screen menus battle
for set_name in "$@"; do
  regen "$set_name"
done
