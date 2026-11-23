#!/bin/sh
# Starts the GamePilot mGBA instance, runs `gamepilot checkpoints` against it, and closes it again
# (user rule: the instance stays closed whenever nothing runs on it). Arguments go to
# `gamepilot checkpoints` as they are, e.g.:
#
#   sh tools/run_checkpoints_on_mgba.sh src/games/frlg/programs/mail_glitch/plans \
#       --from mg-01 --to mg-03 --mode verification
#
# Refuses (exit 3) when the instance or the daemon port is already in use: another run owns it.
# The ROM is GAMEPILOT_ROM, or the one .gba file in the mGBA folder; its path never enters the repo.
#
#   GAMEPILOT_MGBA_DIR  mGBA folder: run_bridge.lua, saves, states (~/FRLGLab/mgba/gamepilot)
#   GAMEPILOT_MGBA_APP  mGBA.app (~/FRLGLab/mgba/nightly/mGBA.app)
#   GAMEPILOT_BIN       the gamepilot binary (src/_build/default/bin/gamepilot.exe; dune build first)
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${GAMEPILOT_MGBA_DIR:-$HOME/FRLGLab/mgba/gamepilot}
app=${GAMEPILOT_MGBA_APP:-$HOME/FRLGLab/mgba/nightly/mGBA.app}
bin=${GAMEPILOT_BIN:-$root/src/_build/default/bin/gamepilot.exe}
bridge_port=47810
daemon_port=47900
# The trailing space keeps the pattern from matching a longer savegamePath.
instance="savegamePath=$dir "

rom=${GAMEPILOT_ROM:-}
if [ -z "$rom" ]; then
    rom=$(find "$dir" -maxdepth 1 -name '*.gba')
    if [ -z "$rom" ] || [ "$(printf '%s\n' "$rom" | wc -l)" -ne 1 ]; then
        echo "set GAMEPILOT_ROM: not exactly one .gba in $dir" >&2
        exit 2
    fi
fi

if pgrep -f "$instance" >/dev/null || lsof -nP -iTCP:$daemon_port -sTCP:LISTEN >/dev/null \
    || lsof -nP -iTCP:$bridge_port -sTCP:LISTEN >/dev/null; then
    echo "the GamePilot mGBA instance or port $daemon_port/$bridge_port is in use; not sharing it" >&2
    exit 3
fi
[ -x "$bin" ] || { echo "no $bin: run dune build in src/" >&2; exit 2; }

close_mgba() {
    pids=$(pgrep -f "$instance" || true)
    if [ -n "$pids" ]; then
        kill $pids
        echo "closed mGBA ($instance)"
    fi
}
trap close_mgba EXIT
trap 'exit 130' INT TERM

open -n "$app" --args -C audioSync=1 -C videoSync=0 -C fpsTarget=120 -C "savegamePath=$dir" \
    --script "$dir/run_bridge.lua" "$rom"
tries=0
until lsof -nP -iTCP:$bridge_port -sTCP:LISTEN >/dev/null; do
    tries=$((tries + 1))
    [ $tries -le 60 ] || { echo "the mGBA bridge did not listen on $bridge_port in 30 s" >&2; exit 1; }
    sleep 0.5
done

cd "$root"
"$bin" checkpoints "$@"
