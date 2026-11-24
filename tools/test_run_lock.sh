#!/bin/sh
# Tests tools/run_lock.sh with real processes: two runners never hold the lock at once, a waiter
# gets it when the holder exits, a stale lock (dead holder) is taken over, and a timeout gives up
# with exit 4. Needs no emulator: sh tools/test_run_lock.sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
lock=$tmp/runs/.lock
export RUN_LOCK_POLL=1
failures=0

check() {
    if [ "$2" = "$3" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: expected [$2], got [$3]"
        failures=$((failures + 1))
    fi
}

# A runner: takes the lock, notes its start and end in the shared log, holds it [hold] seconds.
runner() {
    sh -c '
        . "$1/tools/run_lock.sh"
        trap "run_lock_release \"$2\" >/dev/null" EXIT
        run_lock_acquire "$2" "$4" "runner $3" >/dev/null || exit $?
        echo "start $3" >>"$5"
        sleep "$6"
        echo "end $3" >>"$5"
    ' runner "$root" "$lock" "$1" "$2" "$tmp/log" "$3"
}

# Two at once: the second starts only after the first ended.
runner a 0 2 &
a=$!
runner b 0 2 &
b=$!
wait $a
wait $b
sequence=$(sed 's/ .*//' "$tmp/log" | tr '\n' ' ')
check "two runners take turns" "start end start end " "$sequence"
check "the lock is gone after both" "no" "$([ -d "$lock" ] && echo yes || echo no)"

# A dead holder's lock is taken over.
mkdir -p "$lock"
sh -c 'exit 0' &
dead=$!
wait $dead
printf '%s %s\n' "$dead" "a runner that died" >"$lock/owner"
: >"$tmp/log"
runner c 5 0
check "a stale lock is taken over" "start c" "$(head -n 1 "$tmp/log")"

# A live holder and a 2 s timeout: exit 4, the holder's lock kept.
runner d 0 6 &
d=$!
sleep 1
status=0
runner e 2 0 || status=$?
check "a timeout gives up with 4" "4" "$status"
check "the holder keeps its lock" "runner d" "$(cut -d' ' -f2- "$lock/owner")"
wait $d

[ $failures -eq 0 ] && echo "all passed"
exit $failures
