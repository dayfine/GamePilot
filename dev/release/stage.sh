#!/bin/sh
# Stage a self-contained GamePilot release directory.
#
# Usage:
#   sh dev/release/stage.sh <out-dir> [--gamepilot PATH] [--daemon PATH] [--allow-missing-daemon]
set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: sh dev/release/stage.sh <out-dir> [--gamepilot PATH] [--daemon PATH] [--allow-missing-daemon]" >&2
  exit 2
fi

OUT_DIR=$1
shift

GAMEPILOT_BIN="src/_build/default/bin/gamepilot.exe"
DAEMON_BIN="daemon/build/gamepilot_daemon"
ALLOW_MISSING_DAEMON=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --gamepilot)
      GAMEPILOT_BIN=$2
      shift 2
      ;;
    --daemon)
      DAEMON_BIN=$2
      shift 2
      ;;
    --allow-missing-daemon)
      ALLOW_MISSING_DAEMON=1
      shift
      ;;
    *)
      echo "stage.sh: unknown option $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$GAMEPILOT_BIN" ]; then
  echo "stage.sh: gamepilot binary not found at $GAMEPILOT_BIN (run 'cd src && opam exec -- dune build bin/gamepilot.exe')" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/bin" "$OUT_DIR/share/gamepilot"

case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    cp "$GAMEPILOT_BIN" "$OUT_DIR/gamepilot.exe"
    ;;
  *)
    cp "$GAMEPILOT_BIN" "$OUT_DIR/gamepilot"
    chmod +x "$OUT_DIR/gamepilot"
    ;;
esac

if [ -f "$DAEMON_BIN" ]; then
  DAEMON_NAME=$(basename "$DAEMON_BIN")
  cp "$DAEMON_BIN" "$OUT_DIR/bin/$DAEMON_NAME"
  chmod +x "$OUT_DIR/bin/$DAEMON_NAME" 2>/dev/null || true
elif [ "$ALLOW_MISSING_DAEMON" -eq 0 ]; then
  echo "stage.sh: daemon binary not found at $DAEMON_BIN (pass --daemon PATH or --allow-missing-daemon)" >&2
  exit 1
fi

copy_tree() {
  rel=$1
  if [ -e "$rel" ]; then
    dst="$OUT_DIR/share/gamepilot/$(dirname "$rel")"
    mkdir -p "$dst"
    cp -R "$rel" "$dst/"
  fi
}

# Plans
find src/games -path '*/programs/*/plans' -type d | sort | while IFS= read -r dir; do
  copy_tree "$dir"
done

# Runtime game assets, places, fragments (exclude build-time extract scripts)
find src/games \( -name assets -o -name places -o -name fragments \) -type d | sort | while IFS= read -r dir; do
  copy_tree "$dir"
done
find "$OUT_DIR/share/gamepilot" -type d -name extract -exec rm -rf {} + 2>/dev/null || true
find "$OUT_DIR/share/gamepilot" -type f \( -name '*.ml' -o -name '*.mli' -o -name 'dune' \) -delete 2>/dev/null || true

# Runtime maps from PokemonSimulation
if [ -d "third_party/PokemonSimulation/data/games/frlg/maps" ]; then
  copy_tree "third_party/PokemonSimulation/data/games/frlg/maps"
fi

cat > "$OUT_DIR/README.txt" <<'EOF'
GamePilot release bundle
========================

Quick start:
  ./gamepilot --help
  ./gamepilot programs

Bundled files:
  gamepilot             Main CLI executable
  bin/gamepilot_daemon  Capture/controller daemon (CoreLib compiled in)
  share/gamepilot/      Plans, assets, places, and maps

Switch controller firmware:
  If you already use Pokemon Automation / SerialPrograms (PA/CC), your
  controller board works as-is. Otherwise flash a compatible PA/CC firmware
  onto your microcontroller before running Switch programs.
EOF

echo "staged release bundle in $OUT_DIR"
