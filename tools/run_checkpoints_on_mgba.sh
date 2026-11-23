#!/bin/sh
# Starts the GamePilot mGBA instance, runs `gamepilot checkpoints` against it, and closes it again
# (the instance stays closed whenever nothing runs on it). Arguments go to
# `gamepilot checkpoints` as they are, e.g.:
#
#   sh tools/run_checkpoints_on_mgba.sh src/games/frlg/programs/mail_glitch/plans \
#       --from mg-01 --to mg-03 --mode verification
#
# Refuses (exit 3) when the instance or the daemon port is already in use: another run owns it.
#
# Settings come from the environment. A machine can keep them in an env file (sh syntax, one
# `export NAME=value` per line), read first if it exists; variables already set win over it.
#
#   GAMEPILOT_ENV_FILE  the env file ($HOME/.config/gamepilot/env)
#   GAMEPILOT_MGBA_DIR  mGBA folder: run_bridge.lua, saves ($HOME/.local/share/gamepilot/mgba)
#   GAMEPILOT_STATES    checkpoint start states, <ID>.start.ss ($HOME/.local/share/gamepilot/states)
#   GAMEPILOT_RUNS      run records, one folder per run ($HOME/.local/share/gamepilot/runs)
#   GAMEPILOT_ROM       the FireRed ROM (else the one .gba file in GAMEPILOT_MGBA_DIR); its path
#                       never enters the repo or a log
#   GAMEPILOT_MGBA_APP  mGBA.app (/Applications/mGBA.app)
#   GAMEPILOT_BIN       the gamepilot binary (src/_build/default/bin/gamepilot.exe; dune build first)
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
env_file=${GAMEPILOT_ENV_FILE:-$HOME/.config/gamepilot/env}
if [ -f "$env_file" ]; then
    # Variables set by the caller win over the file.
    saved=$(export -p | grep -E '^export GAMEPILOT_' || true)
    . "$env_file"
    eval "$saved"
fi
data=$HOME/.local/share/gamepilot
dir=${GAMEPILOT_MGBA_DIR:-$data/mgba}
export GAMEPILOT_STATES="${GAMEPILOT_STATES:-$data/states}"
export GAMEPILOT_RUNS="${GAMEPILOT_RUNS:-$data/runs}"
app=${GAMEPILOT_MGBA_APP:-/Applications/mGBA.app}
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
echo "mGBA dir: $dir"
echo "states:   $GAMEPILOT_STATES"
echo "runs:     $GAMEPILOT_RUNS"

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
