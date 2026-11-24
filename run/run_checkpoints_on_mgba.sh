#!/bin/sh
# Starts the GamePilot mGBA instance, runs `gamepilot checkpoints` against it, and closes it again
# (the instance stays closed whenever nothing runs on it). Arguments go to
# `gamepilot checkpoints` as they are, e.g.:
#
#   sh run/run_checkpoints_on_mgba.sh --program frlg.mail_glitch \
#       --from mg-01 --to mg-03 --mode verification
#
# A plan folder in place of --program ID still works (`gamepilot checkpoints PLAN_DIR ...`).
#
# One run at a time: the runner takes the lock $GAMEPILOT_RUNS/.lock (run/run_lock.sh) and waits,
# saying who holds it, while another runner does; a lock whose holder died is taken over. Once it
# holds the lock it also waits while the instance or its bridge port is still in use (a runner
# without the lock). Exit 4 when --lock-timeout SECONDS ran out first (default: wait for ever).
# The daemons pick free ports (one per run), so runs on other backends do not collide with this
# one.
#
# --speed S runs the game S times as fast (default 1): mGBA starts with audio and video sync off,
# so it never throttles itself, and the daemon steps it at S x 59.7275 frames a second. Presses,
# waits and timeouts stay in game time (protocol/v1/README.md, Clock and frames).
#
# The run's watch page is served (`--watch` is passed unless an argument already sets the page or
# `--no-watch` turns it off). GAMEPILOT_WATCH_LISTEN=0.0.0.0 in the env file opens the watch
# pages to the LAN.
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
#   GAMEPILOT_MGBA_SHOW  1 opens mGBA in front (default: hidden, in the background)
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

[ -x "$bin" ] || { echo "no $bin: run dune build in src/" >&2; exit 2; }

# The runner's own flags out, --watch in unless the page is set or turned off.
lock_timeout=0
speed=1
watch=--watch
n=$#
while [ $n -gt 0 ]; do
    a=$1
    shift
    n=$((n - 1))
    case $a in
    --lock-timeout)
        lock_timeout=$1
        shift
        n=$((n - 1))
        continue
        ;;
    --no-watch)
        watch=""
        continue
        ;;
    --speed)
        speed=$1
        shift
        n=$((n - 1))
        continue
        ;;
    --watch | --watch-port | --listen) watch="" ;;
    esac
    set -- "$@" "$a"
done
if [ -n "$watch" ]; then
    set -- "$@" "$watch"
fi
# At 1x mGBA paces itself by its audio, as before; faster, the daemon paces it.
if [ "$speed" = 1 ]; then
    sync="-C audioSync=1 -C videoSync=0 -C fpsTarget=120"
else
    sync="-C audioSync=0 -C videoSync=0"
    set -- "$@" --speed "$speed"
fi

. "$root/run/run_lock.sh"
lock=$GAMEPILOT_RUNS/.lock
close_mgba() {
    pids=$(pgrep -f "$instance" || true)
    if [ -n "$pids" ]; then
        kill $pids
        echo "closed mGBA ($instance)"
    fi
}
# Closes only an instance this runner opened.
opened=""
on_exit() {
    if [ -n "$opened" ]; then
        close_mgba
    fi
    run_lock_release "$lock"
}
trap on_exit EXIT
trap 'exit 130' INT TERM
run_lock_acquire "$lock" "$lock_timeout" "$0 $*" || exit $?

waited=0
while pgrep -f "$instance" >/dev/null || lsof -nP -iTCP:$bridge_port -sTCP:LISTEN >/dev/null; do
    if [ $waited -eq 0 ]; then
        echo "[Lock] waiting: the GamePilot mGBA instance or port $bridge_port is in use"
    fi
    if [ "$lock_timeout" -gt 0 ] && [ $waited -ge "$lock_timeout" ]; then
        echo "[Lock] gave up after ${lock_timeout}s: the instance is still in use" >&2
        exit 4
    fi
    sleep 2
    waited=$((waited + 2))
done
echo "mGBA dir: $dir"
echo "states:   $GAMEPILOT_STATES"
echo "runs:     $GAMEPILOT_RUNS"
echo "speed:    ${speed}x"

opened=1
# -g -j: start in the background, hidden, so a run never takes the screen or the
# focus (the bridge reads frames from the core, not the window). App Nap would
# throttle a hidden app: `defaults write com.endrift.mgba-qt NSAppSleepDisabled
# -bool YES` once per machine. GAMEPILOT_MGBA_SHOW=1 opens it in front instead.
if [ "${GAMEPILOT_MGBA_SHOW:-0}" = 1 ]; then open_flags="-n"; else open_flags="-n -g -j"; fi
# shellcheck disable=SC2086
open $open_flags "$app" --args $sync -C "savegamePath=$dir" \
    --script "$dir/run_bridge.lua" "$rom"
tries=0
until lsof -nP -iTCP:$bridge_port -sTCP:LISTEN >/dev/null; do
    tries=$((tries + 1))
    [ $tries -le 60 ] || { echo "the mGBA bridge did not listen on $bridge_port in 30 s" >&2; exit 1; }
    sleep 0.5
done

cd "$root"
"$bin" checkpoints "$@"
