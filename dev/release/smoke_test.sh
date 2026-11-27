#!/bin/sh
# Out-of-tree smoke test for a staged GamePilot release directory.
#
# Usage:
#   sh dev/release/smoke_test.sh <staged-dir> [expected-version]
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: sh dev/release/smoke_test.sh <staged-dir> [expected-version]" >&2
  exit 2
fi

STAGED=$(cd "$1" && pwd)
EXPECTED_VERSION=${2:-}

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

  echo "[smoke] gamepilot --version"
  GP_VER=$("$GP" --version)
  case "$GP_VER" in
    "gamepilot "*) ;;
    *)
      echo "smoke_test.sh: unexpected 'gamepilot --version' output: $GP_VER" >&2
      exit 1
      ;;
  esac
  if [ -n "$EXPECTED_VERSION" ]; then
    case "$GP_VER" in
      "gamepilot $EXPECTED_VERSION ("*")") ;;
      *)
        echo "smoke_test.sh: expected gamepilot version '$EXPECTED_VERSION', got: $GP_VER" >&2
        exit 1
        ;;
    esac
  fi

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

  echo "[smoke] gamepilot doctor (out of tree, empty temp config)"
  "$GP" doctor --config "$TMPDIR_TEST/consoles.json" | grep -q "\[PASS\] bundled data" || {
    echo "smoke_test.sh: expected [PASS] bundled data from gamepilot doctor" >&2
    exit 1
  }

  DAEMON=""
  if [ -x "$STAGED/bin/gamepilot_daemon" ]; then
    DAEMON="$STAGED/bin/gamepilot_daemon"
  elif [ -f "$STAGED/bin/gamepilot_daemon.exe" ]; then
    DAEMON="$STAGED/bin/gamepilot_daemon.exe"
  fi

  if [ -n "$DAEMON" ]; then
    echo "[smoke] $(basename "$DAEMON") --help"
    "$DAEMON" --help 2>&1 | grep -q "usage:" || {
      echo "smoke_test.sh: expected usage output from $(basename "$DAEMON")" >&2
      exit 1
    }

    echo "[smoke] $(basename "$DAEMON") --version"
    DM_VER=$("$DAEMON" --version)
    case "$DM_VER" in
      "gamepilot_daemon "*) ;;
      *)
        echo "smoke_test.sh: unexpected 'gamepilot_daemon --version' output: $DM_VER" >&2
        exit 1
        ;;
    esac
    if [ -n "$EXPECTED_VERSION" ]; then
      if [ "$DM_VER" != "gamepilot_daemon $EXPECTED_VERSION" ]; then
        echo "smoke_test.sh: expected daemon version '$EXPECTED_VERSION', got: $DM_VER" >&2
        exit 1
      fi
    fi
  fi
)

echo "smoke_test.sh: ok ($STAGED)"
