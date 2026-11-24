#!/bin/sh
# Runs `gamepilot checkpoints` on the Switch (console B): takes the console's lab lock, refuses
# while the lab app holds the controller board's serial port or the capture card, runs the
# bring-up checks (the board's mode, one frame and its geometry), the pre-flight of the loaded
# save, then the checkpoints with --backend switch, and always hands the console back: the
# daemons stopped (which releases the keys and closes the port and the card) and the lab lock
# released, also on a failure or Ctrl-C.
#
#   sh tools/run_checkpoints_on_switch.sh --program frlg.mail_glitch | PLAN_DIR \
#       --from mg-01 --to mg-03 [--runs N] [--no-save-after-pass] [--no-preflight | --preflight-only] \
#       [--no-watch] [--dry-run] [other `gamepilot checkpoints` flags, e.g. --party ...]
#
# --program takes a program registry id (`gamepilot programs` lists them); a plan folder in its
# place still works.
#
# Policy (docs/switch-bring-up.md): each checkpoint runs once (--runs 1) from the game's last
# save, which a soft reset returns to; a run that passes, its end checks included, is saved in
# the game (--save-after-pass, the default) and the next checkpoint starts from it; a run that
# fails soft-resets back to the last save and the series stops, for a fix and a rerun from that
# save. A failed or stopped run never saves.
#
# --dry-run runs the whole script on the fakes, touching no console: the daemon's fake controller
# board (no --serial) and a replay of a recorded frame (--replay, docs: daemon/src/main.cpp) in
# place of the capture card, a lab lock of its own in a scratch lab folder, and the device checks
# against a scratch serial file. It needs ffmpeg to make the replay (or GAMEPILOT_DRY_RUN_VIDEO).
#
# Settings come from the environment, an env file first (as tools/run_checkpoints_on_mgba.sh):
#
#   GAMEPILOT_ENV_FILE        the env file ($HOME/.config/gamepilot/env)
#   GAMEPILOT_SWITCH_SERIAL   the board's serial port (gamepilot switch-devices)
#   GAMEPILOT_SWITCH_CAPTURE  the capture card's index (swift tools/list_capture_devices.swift)
#   GAMEPILOT_LABLOCK         the lab's lablock.sh (one user of a lab console at a time)
#   GAMEPILOT_LAB_CONSOLE     the console's lock name (B)
#   GAMEPILOT_LAB_APP         a pgrep -f pattern for the lab app that drives the console and holds
#                             its capture card ('SerialPrograms.*--profile lab-B')
#   GAMEPILOT_STATES, GAMEPILOT_RUNS   start frames and run records, as for mGBA
#   GAMEPILOT_BIN             the gamepilot binary (src/_build/default/bin/gamepilot.exe)
#   GAMEPILOT_DAEMON          the daemon (daemon/build/gamepilot_daemon)
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
env_file=${GAMEPILOT_ENV_FILE:-$HOME/.config/gamepilot/env}
if [ -f "$env_file" ]; then
    saved=$(export -p | grep -E '^export GAMEPILOT_' || true)
    . "$env_file"
    eval "$saved"
fi
bin=${GAMEPILOT_BIN:-$root/src/_build/default/bin/gamepilot.exe}
daemon=${GAMEPILOT_DAEMON:-$root/daemon/build/gamepilot_daemon}
console=${GAMEPILOT_LAB_CONSOLE:-B}
lab_app=${GAMEPILOT_LAB_APP:-SerialPrograms.*--profile lab-B}

usage() {
    sed -n '9,11p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

# Our flags out; the rest go to `gamepilot checkpoints`.
[ $# -gt 0 ] || usage
# The program: --program ID, else the plan folder.
program_flag=""
if [ "$1" = --program ]; then
    [ $# -gt 1 ] || usage
    program_flag=--program
    shift
fi
plan_dir=$1
shift
dry_run="" watch=--watch preflight=--preflight save=--save-after-pass runs=1 from="" locked=""
n=$#
while [ $n -gt 0 ]; do
    a=$1
    shift
    n=$((n - 1))
    case $a in
    --dry-run) dry_run=1; continue ;;
    --locked) locked=1; continue ;;
    --no-watch) watch=""; continue ;;
    --no-preflight) preflight=""; continue ;;
    --preflight | --preflight-only) preflight=$a; continue ;;
    --save-after-pass | --no-save-after-pass) save=$a; continue ;;
    --runs) runs=$1; shift; n=$((n - 1)); continue ;;
    --from) from=$1 ;;
    --watch | --watch-port | --listen) watch="" ;;
    esac
    set -- "$@" "$a"
done
[ -n "$from" ] || usage
[ -x "$bin" ] || { echo "no $bin: run dune build in src/" >&2; exit 2; }
[ -x "$daemon" ] || { echo "no $daemon: build the daemon" >&2; exit 2; }

if [ -n "$dry_run" ]; then
    scratch=${GAMEPILOT_DRY_RUN_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/gamepilot-switch-dry.XXXXXX")}
    export LAB_DIR=$scratch/lab
    lablock=${GAMEPILOT_LABLOCK:-}
    serial_check=$scratch/serial
    : >"$serial_check"
    lab_app="gamepilot-dry-run-lab-app-$$"
    # Its run records and start frames stay in the scratch folder.
    export GAMEPILOT_RUNS="$scratch/runs"
    export GAMEPILOT_STATES="$scratch/states"
    mkdir -p "$GAMEPILOT_RUNS" "$GAMEPILOT_STATES"
else
    lablock=${GAMEPILOT_LABLOCK:?set GAMEPILOT_LABLOCK to the lab\'s lablock.sh}
    serial=${GAMEPILOT_SWITCH_SERIAL:?set GAMEPILOT_SWITCH_SERIAL (gamepilot switch-devices)}
    capture=${GAMEPILOT_SWITCH_CAPTURE:?set GAMEPILOT_SWITCH_CAPTURE (tools/list_capture_devices.swift)}
    serial_check=$serial
fi

# Outside the lock: take it, and run this script again inside it. The lock is released when the
# inner run exits, however it exits (lablock.sh's own trap).
if [ -z "$locked" ]; then
    if [ -n "$dry_run" ]; then
        echo "[Dry run] scratch $scratch; console $console's real lock, untouched:"
        if [ -n "$lablock" ]; then
            LAB_DIR= sh "$lablock" -c "$console" status || true
            lock_cmd="sh $lablock"
        else
            lock_cmd=""
        fi
    else
        lock_cmd="sh $lablock"
    fi
    if [ -n "$lock_cmd" ]; then
        # shellcheck disable=SC2086
        exec $lock_cmd -c "$console" run gamepilot-switch -- \
            sh "$0" ${program_flag:+"$program_flag"} "$plan_dir" --locked ${dry_run:+--dry-run} --runs "$runs" "$save" \
            ${preflight:---no-preflight} ${watch:---no-watch} "$@"
    fi
    echo "[Dry run] no GAMEPILOT_LABLOCK: running without a lab lock"
fi
echo "[Lock] holding console $console's lab lock${LAB_DIR:+ (in $LAB_DIR)}"

# Nothing else may hold the board's port or the card.
holders=$(lsof -t "$serial_check" 2>/dev/null || true)
app=$(pgrep -f "$lab_app" || true)
if [ -n "$holders" ] || [ -n "$app" ]; then
    [ -z "$holders" ] || echo "the serial port $serial_check is open in pid(s) $holders" >&2
    [ -z "$app" ] || echo "the lab app (pid $app) holds the capture card" >&2
    echo "Release them first (docs/switch-bring-up.md, step 0): stop the lab app's program, turn" >&2
    echo "keepawake off, quit the lab app; then check: lsof $serial_check  # prints nothing" >&2
    exit 3
fi
echo "[Devices] nothing holds $serial_check; the lab app is not running"

if [ -n "$dry_run" ]; then
    video=${GAMEPILOT_DRY_RUN_VIDEO:-$scratch/replay.mp4}
    if [ ! -f "$video" ]; then
        frame=$root/src/games/frlg/readers/test/images/mgba/mail-glitch-04-inspect/mg05-overworld.png
        # The GBA picture where nso_gba_viewport() puts it: 1560x1040 at (180, 5) of 1920x1080.
        ffmpeg -loglevel error -loop 1 -i "$frame" -t 600 -r 10 \
            -vf "scale=1560:1040:flags=neighbor,pad=1920:1080:180:5:black" \
            -c:v libx264 -pix_fmt yuv420p "$video"
    fi
    board_args=""
    frames_args="--replay $video"
else
    board_args="--serial $serial"
    frames_args="--capture $capture"
fi

# Hand the console back on every exit: the run stopped, every daemon on our board or frames
# stopped (SIGTERM: it releases the keys, closes the port and the card), then checked.
child=""
release() {
    status=$?
    trap - EXIT INT TERM HUP
    if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then
        kill -TERM "$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
    fi
    pattern="gamepilot_daemon --backend switch.*(${board_args:-x^}|$frames_args)"
    pids=$(pgrep -f "$pattern" || true)
    if [ -n "$pids" ]; then
        kill -TERM $pids 2>/dev/null || true
        tries=0
        while pgrep -f "$pattern" >/dev/null && [ $tries -lt 50 ]; do
            sleep 0.2
            tries=$((tries + 1))
        done
    fi
    if pgrep -f "$pattern" >/dev/null; then
        echo "[Release] a daemon is still running: pgrep -fl gamepilot_daemon" >&2
        status=1
    elif [ -n "$(lsof -t "$serial_check" 2>/dev/null || true)" ]; then
        echo "[Release] $serial_check is still open: lsof $serial_check" >&2
        status=1
    else
        echo "[Release] daemons stopped, keys released, $serial_check and the card closed"
    fi
    echo "[Release] console $console's lab lock goes when this exits (status $status)"
    exit $status
}
trap release EXIT
trap 'exit 130' INT TERM HUP

# Runs a step in the background, so a signal reaches the trap at once.
step() {
    "$@" &
    child=$!
    wait "$child"
}

cd "$root"
echo "[Bring-up] the board"
# shellcheck disable=SC2086
step "$daemon" --backend switch $board_args --board-check
echo "[Bring-up] one frame and its geometry"
mkdir -p "$GAMEPILOT_RUNS"
# shellcheck disable=SC2086
step "$daemon" --backend switch $frames_args --capture-check "$GAMEPILOT_RUNS/bring-up-frame.png"

# shellcheck disable=SC2086
set -- ${program_flag:+"$program_flag"} "$plan_dir" "$@" --backend switch $board_args $frames_args
if [ -n "$preflight" ]; then
    echo "[Preflight] $from"
    step "$bin" checkpoints "$@" --preflight
    [ "$preflight" != --preflight-only ] || exit 0
fi
echo "[Checkpoints] --runs $runs $save"
# shellcheck disable=SC2086
step "$bin" checkpoints "$@" --mode testing --runs "$runs" "$save" $watch
