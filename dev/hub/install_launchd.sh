#!/bin/sh
# Install or uninstall macOS launchd LaunchAgents for the GamePilot Control Hub
# (`gamepilot ui`) and its optional periodic auto-updater (`dev/hub/update_hub.sh`).
#
# All paths and ports are parameterized via environment variables (zero hardcoded
# user/home paths). Run with --help for usage and variable defaults.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_HUB_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

HUB_DIR=${GAMEPILOT_HUB_DIR:-$DEFAULT_HUB_DIR}
RUNS_DIR=${GAMEPILOT_RUNS:-$HOME/.local/share/gamepilot/runs}
DAEMON_BIN=${GAMEPILOT_DAEMON:-}
LISTEN_ADDR=${GAMEPILOT_HUB_LISTEN:-0.0.0.0}
PORT=${GAMEPILOT_HUB_PORT:-47902}
UPDATE_INTERVAL=${GAMEPILOT_HUB_UPDATE_INTERVAL:-600}
LABEL=${GAMEPILOT_HUB_LABEL:-com.dayfine.gamepilot.hub}
BRANCH=${GAMEPILOT_HUB_BRANCH:-main}
LAUNCH_PATH=${GAMEPILOT_HUB_PATH:-/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}

UPDATER_LABEL="${LABEL}.updater"
AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/.local/share/gamepilot/hub"
HUB_PLIST="$AGENTS_DIR/${LABEL}.plist"
UPDATER_PLIST="$AGENTS_DIR/${UPDATER_LABEL}.plist"

usage() {
    cat <<EOF
Usage: sh dev/hub/install_launchd.sh [--no-updater] [--uninstall] [--help]

Install macOS launchd LaunchAgents for the long-running GamePilot Control Hub
(\`gamepilot ui\`) and, unless --no-updater is given, a periodic updater that
fetches origin/\$GAMEPILOT_HUB_BRANCH, rebuilds, and restarts the Hub when no
Hub-spawned run is active.

Options:
  --no-updater  Install the Hub LaunchAgent only (remove any existing updater).
  --uninstall   Boot out and remove both LaunchAgent plists.
  -h, --help    Show this help message and exit.

Environment variables:
  GAMEPILOT_HUB_DIR              Repo/worktree root (default: $DEFAULT_HUB_DIR)
  GAMEPILOT_RUNS                 Runs directory (default: \$HOME/.local/share/gamepilot/runs)
  GAMEPILOT_DAEMON               Optional path to gamepilot_daemon binary (exported if set)
  GAMEPILOT_HUB_LISTEN           Bind address for gamepilot ui (default: 0.0.0.0)
  GAMEPILOT_HUB_PORT             TCP port for gamepilot ui (default: 47902)
  GAMEPILOT_HUB_UPDATE_INTERVAL  Updater poll interval in seconds (default: 600)
  GAMEPILOT_HUB_LABEL            Base launchd label (default: com.dayfine.gamepilot.hub)
  GAMEPILOT_HUB_BRANCH           Git branch tracked by updater (default: main)
EOF
}

xml_escape() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

require_pos_int() {
    name=$1
    val=$2
    case "$val" in
        ''|*[!0-9]*)
            printf 'install_launchd: %s must be a positive integer (got %s)\n' "$name" "$val" >&2
            exit 1
            ;;
    esac
    if [ "$val" -le 0 ]; then
        printf 'install_launchd: %s must be > 0 (got %s)\n' "$name" "$val" >&2
        exit 1
    fi
}

bootout_service() {
    uid_num=$1
    svc_label=$2
    launchctl bootout "gui/${uid_num}/${svc_label}" >/dev/null 2>&1 || true
}

write_hub_plist() {
    esc_label=$(xml_escape "$LABEL")
    esc_bin=$(xml_escape "$HUB_BIN")
    esc_listen=$(xml_escape "$LISTEN_ADDR")
    esc_port=$(xml_escape "$PORT")
    esc_runs=$(xml_escape "$RUNS_DIR")
    esc_dir=$(xml_escape "$HUB_DIR")
    esc_home=$(xml_escape "$HOME")
    esc_path=$(xml_escape "$LAUNCH_PATH")
    esc_stdout=$(xml_escape "$LOG_DIR/hub.stdout.log")
    esc_stderr=$(xml_escape "$LOG_DIR/hub.stderr.log")

    daemon_env=""
    if [ -n "$DAEMON_BIN" ]; then
        esc_daemon=$(xml_escape "$DAEMON_BIN")
        daemon_env="        <key>GAMEPILOT_DAEMON</key>
        <string>${esc_daemon}</string>
"
    fi

    cat >"$HUB_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${esc_label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${esc_bin}</string>
        <string>ui</string>
        <string>--listen</string>
        <string>${esc_listen}</string>
        <string>--port</string>
        <string>${esc_port}</string>
        <string>--runs-dir</string>
        <string>${esc_runs}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${esc_dir}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${esc_home}</string>
        <key>PATH</key>
        <string>${esc_path}</string>
        <key>GAMEPILOT_RUNS</key>
        <string>${esc_runs}</string>
${daemon_env}    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${esc_stdout}</string>
    <key>StandardErrorPath</key>
    <string>${esc_stderr}</string>
</dict>
</plist>
EOF
}

write_updater_plist() {
    esc_label=$(xml_escape "$UPDATER_LABEL")
    esc_script=$(xml_escape "$HUB_DIR/dev/hub/update_hub.sh")
    esc_dir=$(xml_escape "$HUB_DIR")
    esc_home=$(xml_escape "$HOME")
    esc_path=$(xml_escape "$LAUNCH_PATH")
    esc_port=$(xml_escape "$PORT")
    esc_hub_label=$(xml_escape "$LABEL")
    esc_branch=$(xml_escape "$BRANCH")
    esc_stdout=$(xml_escape "$LOG_DIR/updater.stdout.log")
    esc_stderr=$(xml_escape "$LOG_DIR/updater.stderr.log")

    cat >"$UPDATER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${esc_label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>${esc_script}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${esc_dir}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${esc_home}</string>
        <key>PATH</key>
        <string>${esc_path}</string>
        <key>GAMEPILOT_HUB_DIR</key>
        <string>${esc_dir}</string>
        <key>GAMEPILOT_HUB_PORT</key>
        <string>${esc_port}</string>
        <key>GAMEPILOT_HUB_LABEL</key>
        <string>${esc_hub_label}</string>
        <key>GAMEPILOT_HUB_BRANCH</key>
        <string>${esc_branch}</string>
    </dict>
    <key>StartInterval</key>
    <integer>${UPDATE_INTERVAL}</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${esc_stdout}</string>
    <key>StandardErrorPath</key>
    <string>${esc_stderr}</string>
</dict>
</plist>
EOF
}

UNINSTALL=0
NO_UPDATER=0

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --no-updater)
            NO_UPDATER=1
            ;;
        *)
            printf 'install_launchd: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'install_launchd: macOS (Darwin) is required for launchd\n' >&2
    exit 1
fi

UID_NUM=$(id -u)

if [ "$UNINSTALL" -eq 1 ]; then
    bootout_service "$UID_NUM" "$UPDATER_LABEL"
    bootout_service "$UID_NUM" "$LABEL"
    rm -f "$UPDATER_PLIST" "$HUB_PLIST"
    printf 'Uninstalled LaunchAgents:\n  %s\n  %s\n' "$HUB_PLIST" "$UPDATER_PLIST"
    exit 0
fi

require_pos_int "GAMEPILOT_HUB_PORT" "$PORT"
require_pos_int "GAMEPILOT_HUB_UPDATE_INTERVAL" "$UPDATE_INTERVAL"

HUB_BIN="$HUB_DIR/src/_build/default/bin/gamepilot.exe"
if [ ! -x "$HUB_BIN" ]; then
    printf 'install_launchd: gamepilot binary not found at %s\n' "$HUB_BIN" >&2
    printf 'Build it first: (cd "%s/src" && opam exec -- dune build bin/gamepilot.exe)\n' "$HUB_DIR" >&2
    exit 1
fi

mkdir -p "$AGENTS_DIR" "$LOG_DIR" "$RUNS_DIR"

write_hub_plist
bootout_service "$UID_NUM" "$LABEL"
launchctl bootstrap "gui/${UID_NUM}" "$HUB_PLIST"
printf 'Installed Hub LaunchAgent: %s\n' "$HUB_PLIST"
printf '  Listening: http://%s:%s (logs: %s)\n' "$LISTEN_ADDR" "$PORT" "$LOG_DIR"

if [ "$NO_UPDATER" -eq 1 ]; then
    bootout_service "$UID_NUM" "$UPDATER_LABEL"
    rm -f "$UPDATER_PLIST"
    printf 'Skipped updater LaunchAgent (--no-updater).\n'
else
    write_updater_plist
    bootout_service "$UID_NUM" "$UPDATER_LABEL"
    launchctl bootstrap "gui/${UID_NUM}" "$UPDATER_PLIST"
    printf 'Installed Updater LaunchAgent: %s (every %ss, branch %s)\n' \
        "$UPDATER_PLIST" "$UPDATE_INTERVAL" "$BRANCH"
fi
