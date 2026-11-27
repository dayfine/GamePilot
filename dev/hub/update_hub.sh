#!/bin/sh
# Periodic updater invoked by the GamePilot Control Hub updater LaunchAgent.
#
# Fetches origin/$GAMEPILOT_HUB_BRANCH; when a newer commit is available and no
# Hub-spawned run is currently running, fast-forwards the checkout, updates
# third_party/PokemonSimulation, rebuilds bin/gamepilot.exe, and restarts the
# Hub LaunchAgent.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_HUB_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

HUB_DIR=${GAMEPILOT_HUB_DIR:-$DEFAULT_HUB_DIR}
PORT=${GAMEPILOT_HUB_PORT:-47902}
LABEL=${GAMEPILOT_HUB_LABEL:-com.dayfine.gamepilot.hub}
BRANCH=${GAMEPILOT_HUB_BRANCH:-main}

export PATH="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}:/opt/homebrew/bin:/usr/local/bin"

log() {
    printf '%s update_hub: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

has_active_hub_runs() {
    api_url="http://127.0.0.1:${PORT}/api/runs"
    if ! payload=$(curl -fsS --max-time 5 "$api_url" 2>/dev/null); then
        # Hub is not reachable; safe to update and restart.
        return 1
    fi
    printf '%s' "$payload" | python3 -I -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    # Fail safe if the response is unreadable so we do not kill an active run.
    sys.exit(0)
runs = data.get("runs") if isinstance(data, dict) else None
if not isinstance(runs, list):
    sys.exit(0)
active = any(
    isinstance(r, dict)
    and r.get("status") == "running"
    and not r.get("external")
    for r in runs
)
sys.exit(0 if active else 1)
'
}

cd "$HUB_DIR"

git fetch --quiet origin "$BRANCH"
local_sha=$(git rev-parse HEAD)
remote_sha=$(git rev-parse "origin/$BRANCH")

if [ "$local_sha" = "$remote_sha" ]; then
    exit 0
fi

if has_active_hub_runs; then
    log "update ${local_sha} -> ${remote_sha} deferred: active Hub-spawned run(s) in progress"
    exit 0
fi

log "updating ${BRANCH}: ${local_sha} -> ${remote_sha}"
git reset --hard "origin/$BRANCH"
git submodule update --init third_party/PokemonSimulation
(cd "$HUB_DIR/src" && opam exec -- dune build bin/gamepilot.exe)

uid_num=$(id -u)
launchctl kickstart -k "gui/${uid_num}/${LABEL}"
log "restarted ${LABEL} at ${remote_sha}"
