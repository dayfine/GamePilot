#!/bin/sh
# Tests `gamepilot ctl` against a real daemon on the fakes: the switch backend with its fake
# controller board (no --serial) and a replayed capture of FireRed's Start menu (--replay). Checks
# reads without the lease, presses with it, a refusal naming the holder while another client holds
# it, the lease ending with its client, the wire log's owner, shots and script errors.
# Needs the daemon built (daemon/build, or GAMEPILOT_DAEMON), `dune build` in src, and ffmpeg:
#   sh run/test_ctl.sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
daemon=${GAMEPILOT_DAEMON:-$root/daemon/build/gamepilot_daemon}
gamepilot=$root/src/_build/default/bin/gamepilot.exe
tmp=$(mktemp -d)
pid=""
cleanup() {
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
failures=0

check() {
    if printf '%s' "$3" | grep -q -- "$2"; then
        echo "ok   $1"
    else
        echo "FAIL $1: expected [$2] in:"
        printf '%s\n' "$3" | sed 's/^/     /'
        failures=$((failures + 1))
    fi
}

# The Start menu frame where nso_gba_viewport() puts the GBA picture: 1560x1040 at (180, 5).
frame=$root/src/games/frlg/readers/test/images/mgba/mail-glitch-04-inspect/mg05-start-menu.png
ffmpeg -loglevel error -loop 1 -i "$frame" -t 120 -r 10 \
    -vf "scale=1560:1040:flags=neighbor,pad=1920:1080:180:5:black" \
    -c:v libx264 -pix_fmt yuv420p "$tmp/replay.mp4"

"$daemon" --backend switch --replay "$tmp/replay.mp4" --port 0 --log "$tmp/wire.jsonl" \
    2>"$tmp/daemon.err" &
pid=$!
port=""
for _ in $(seq 1 100); do
    port=$(sed -n 's/^daemon: listening on 127.0.0.1:\([0-9]*\).*/\1/p' "$tmp/daemon.err")
    [ -n "$port" ] && break
    sleep 0.1
done
[ -n "$port" ] || { echo "FAIL the daemon did not start"; cat "$tmp/daemon.err"; exit 1; }
ctl() { "$gamepilot" ctl --port "$port" "$@" 2>&1 || true; }

check "status: the lease is free" "input lease: free" "$(ctl status)"
read_out=$(ctl read start_menu)
check "read start_menu: open" "open: yes" "$read_out"
check "read start_menu: the rows' names" "rows: .*BAG.*SAVE" "$read_out"
check "an unknown reader" "error 1 read nothing: unknown reader nothing" "$(ctl read nothing)"
check "press takes the lease and ends" "ok 1 press A" "$(ctl --owner tester press A --hold 50 --wait 100)"
check "shot" "ok 1 shot" "$(ctl shot "$tmp/menu.png")"
[ -s "$tmp/menu.png" ] && echo "ok   shot wrote a PNG" || { echo "FAIL no PNG"; failures=$((failures + 1)); }

# A script that holds the lease for a while; meanwhile others are refused, reads still work.
printf '# hold the lease\npress B 50 50\nwait 3000\ndpad DOWN 2 --wait 100\n' >"$tmp/hold.txt"
"$gamepilot" ctl --port "$port" --owner holder run "$tmp/hold.txt" >"$tmp/hold.out" 2>&1 &
holder=$!
sleep 1.5
check "another press is refused, naming the holder" \
    "refused: input lease held by holder (gamepilot-ctl/0.1), held [0-9]* s" \
    "$(ctl --owner other press A)"
check "status names the holder" "input lease: holder" "$(ctl status)"
check "reads need no lease" "open: yes" "$(ctl read start_menu)"
wait "$holder"
check "the script ran every line" "ok 2 press B 50 50.*ok 3 wait 3000.*ok 4 dpad DOWN 2" \
    "$(tr '\n' ' ' <"$tmp/hold.out")"
check "the lease ended with its client" "ok 1 press A" "$(ctl --owner other press A)"
check "the wire log names each press's owner" '"owner":"holder"' "$(cat "$tmp/wire.jsonl")"

printf 'press A 50 50\npress HOME\n' >"$tmp/bad.txt"
check "a bad line stops the script before it connects" "line 2: unknown button" \
    "$(ctl run "$tmp/bad.txt")"
printf 'press A 50 50\nread nothing\npress B\n' >"$tmp/stop.txt"
stop_out=$(ctl run "$tmp/stop.txt")
check "run stops at the first error" "ok 1 press A 50 50.*error 2 read nothing" \
    "$(printf '%s' "$stop_out" | tr '\n' ' ')"
case "$stop_out" in *"press B"*) echo "FAIL ran past the error"; failures=$((failures + 1)) ;; esac

[ "$failures" -eq 0 ] && echo "test_ctl: all passed" || { echo "test_ctl: $failures failed"; exit 1; }
