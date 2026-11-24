# The lock that lets one checkpoint run at a time use the GamePilot mGBA instance; sourced by
# run/run_checkpoints_on_mgba.sh (and tested by run/test_run_lock.sh). The lock is a
# directory, made with one atomic mkdir, holding an `owner` file: the holder's pid and command
# line. A runner that finds it waits until it is gone, or until its holder's pid is dead (a stale
# lock, taken over), or until its timeout.
#
#   run_lock_acquire DIR TIMEOUT OWNER   0 once held; 4 after TIMEOUT seconds (0: wait forever)
#   run_lock_release DIR                 removes it when this shell ($$) holds it
#
# RUN_LOCK_POLL (seconds, default 2) is how often a waiting runner looks again.

run_lock_pid() {
    sed -n '1s/ .*//p' "$1/owner" 2>/dev/null
}

# Removes the lock when its holder is still [dead] (empty: it never wrote its owner file), under
# a second short-lived lock, so two waiters can't both remove it and one of them a fresh lock.
# A takeover lock left by a waiter that died inside it goes after [stuck] tries.
run_lock_clear_stale() {
    lock=$1
    dead=$2
    stuck=$3
    if mkdir "$lock.takeover" 2>/dev/null; then
        if [ "$(run_lock_pid "$lock")" = "$dead" ]; then
            echo "[Lock] taking over the stale lock of pid ${dead:-?} (no longer running)"
            rm -rf "$lock"
        fi
        rmdir "$lock.takeover"
    elif [ "$stuck" -ge 5 ]; then
        rmdir "$lock.takeover" 2>/dev/null || true
    fi
}

run_lock_acquire() {
    lock=$1
    timeout=$2
    owner=$3
    poll=${RUN_LOCK_POLL:-2}
    mkdir -p "$(dirname "$lock")"
    waited=0
    unowned=0
    told=""
    while ! mkdir "$lock" 2>/dev/null; do
        pid=$(run_lock_pid "$lock")
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            run_lock_clear_stale "$lock" "$pid" "$unowned"
            unowned=$((unowned + 1))
            if [ -d "$lock" ]; then sleep 1; fi
            continue
        fi
        # mkdir done, owner not written yet: its runner is starting, or died right there.
        if [ -z "$pid" ]; then
            unowned=$((unowned + 1))
            if [ "$unowned" -ge 5 ]; then
                run_lock_clear_stale "$lock" "" "$unowned"
                if [ -d "$lock" ]; then sleep 1; fi
                continue
            fi
        else
            unowned=0
        fi
        if [ "$told" != "$pid" ]; then
            echo "[Lock] waiting: the mGBA instance is held by $(cat "$lock/owner" 2>/dev/null || echo 'a runner starting')"
            told=$pid
        fi
        if [ "$timeout" -gt 0 ] && [ "$waited" -ge "$timeout" ]; then
            echo "[Lock] gave up after ${timeout}s; held by $(cat "$lock/owner" 2>/dev/null)" >&2
            return 4
        fi
        sleep "$poll"
        waited=$((waited + poll))
    done
    printf '%s %s\n' "$$" "$owner" >"$lock/owner"
    echo "[Lock] holding $lock"
}

run_lock_release() {
    lock=$1
    if [ "$(run_lock_pid "$lock")" = "$$" ]; then
        rm -rf "$lock"
        echo "[Lock] released"
    fi
}
