#!/bin/sh
# Remakes the probe_images fixtures of the FRLG reader tests from the source
# images. Each fixture set has a map per backend, one image per line:
#
#   <root> <path under the root>|<tagged name in the fixture>
#
# <root> is clt (CommandLineTests, $COMMANDLINETESTS_DIR, default
# ~/Projects/CommandLineTests), clt@<commit> (a file at that commit of the
# CommandLineTests repo, for images not on its main), or shots (lab
# screenshots, $FRLG_SHOTS_DIR, default ~/FRLGLab). The tagged name is what
# the test reads its expectations from. Sets: screen (test_screen_readers.ml,
# the write_probe_spec default), menus (test_menu_readers.ml) and battle
# (test_battle_readers.ml).
#
#   sh games/frlg/readers/test/regen_fixtures.sh [screen|menus|battle ...]
#
# run from src/, with probe_images at $PROBE_IMAGES (default the repo's
# daemon/build/probe_images). Switch captures use the fork's FRLG GAME_BOX as
# the viewport; mGBA frames are the picture.
set -eu

CLT=${COMMANDLINETESTS_DIR:-$HOME/Projects/CommandLineTests}
SHOTS=${FRLG_SHOTS_DIR:-$HOME/FRLGLab}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../../.." && pwd)
PROBE_IMAGES=${PROBE_IMAGES:-$SRC/../daemon/build/probe_images}
SWITCH_VIEWPORT=0.09375,0.00462963,0.8125,0.962963
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
    shots) cp "$SHOTS/$path" "$2/$tagged" ;;
    *) echo "unknown root $root" >&2 && exit 1 ;;
    esac
  done <"$1"
}

# Probes one backend's images, in map order, into its fixture.
probe() {
  set_name=$1 backend=$2 spec=$3 fixture=$4
  shift 4
  map=$HERE/$set_name.$backend.map
  stage "$map" "$WORK/$set_name.$backend"
  images=$(cut -d'|' -f2 "$map")
  # shellcheck disable=SC2086
  (cd "$WORK/$set_name.$backend" && "$PROBE_IMAGES" --spec "$spec" "$@" $images) \
    >"$HERE/fixtures/$fixture"
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
}

[ $# -gt 0 ] || set -- screen menus battle
for set_name in "$@"; do
  regen "$set_name"
done
