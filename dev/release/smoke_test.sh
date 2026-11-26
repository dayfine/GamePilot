#!/bin/sh
# Out-of-tree smoke test for a staged GamePilot release directory.
#
# Usage:
#   sh dev/release/smoke_test.sh <staged-dir>
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: sh dev/release/smoke_test.sh <staged-dir>" >&2
  exit 2
fi

STAGED=$(cd "$1" && pwd)

if [ -x "$STAGED/gamepilot" ]; then
  GP="$STAGED/gamepilot"
elif [ -f "$STAGED/gamepilot.exe" ]; then
  GP="$STAGED/gamepilot.exe"
else
  echo "smoke_test.sh: gamepilot binary not found in $STAGED" >&2
  exit 1
fi

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

(
  cd "$TMPDIR_TEST"
  unset GAMEPILOT_DATA GAMEPILOT_DAEMON

  echo "[smoke] gamepilot usage"
  "$GP" 2>&1 | grep -q "usage:" || {
    echo "smoke_test.sh: expected usage output from gamepilot" >&2
    exit 1
  }

  echo "[smoke] gamepilot programs (out of tree)"
  OUT=$("$GP" programs)
  echo "$OUT" | grep -q "frlg.supplies" || {
    echo "smoke_test.sh: expected frlg.supplies in 'gamepilot programs' output" >&2
    exit 1
  }
  echo "$OUT" | grep -q "frlg.dex_collection" || {
    echo "smoke_test.sh: expected frlg.dex_collection in 'gamepilot programs' output" >&2
    exit 1
  }

  echo "[smoke] gamepilot guide frlg.supplies (loads bundled plans out of tree)"
  "$GP" guide frlg.supplies | grep -q "su-01" || {
    echo "smoke_test.sh: expected su-01 from bundled plans out of tree" >&2
    exit 1
  }

  if [ -x "$STAGED/bin/gamepilot_daemon" ]; then
    echo "[smoke] bin/gamepilot_daemon --help"
    "$STAGED/bin/gamepilot_daemon" --help >/dev/null
  elif [ -f "$STAGED/bin/gamepilot_daemon.exe" ]; then
    echo "[smoke] bin/gamepilot_daemon.exe --help"
    "$STAGED/bin/gamepilot_daemon.exe" --help >/dev/null
  fi
)

echo "smoke_test.sh: ok ($STAGED)"
