#!/bin/sh
# Remakes the golden vectors in ../fixtures from the fork's C++ (the oracle, D6):
# builds generate_golden.cpp with plain clang++ against the C++ sources it ports
# and runs it. link_stubs.cpp stands in for the app-wide error code and resource
# path those sources name.
#
#   sh src/games/frlg/rng/test/golden/regen_golden.sh
#
# FORK is an Arduino-Source checkout (default: the third_party/Arduino-Source
# submodule; the fixtures in this folder came from its commit b9b477bab).
# RESOURCES is a PokemonAutomation Packages Resources folder (default: the
# third_party/Packages submodule, commit c4603991d). The seed list is cut to
# its first 300 rows (python3) before the C++ reads it, so the fixture stays
# small. Commit the regenerated fixtures with the commits used.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../../../.." && pwd)
FORK=${FORK:-$ROOT/third_party/Arduino-Source}
RESOURCES=${RESOURCES:-$ROOT/third_party/Packages/Resources}
SOURCE=$FORK/SerialPrograms/Source
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/res/PokemonFRLG/RngSeeds"
cp "$RESOURCES/PokemonFRLG/EncounterSlotsFR.json" "$WORK/res/PokemonFRLG/"
python3 - "$RESOURCES/PokemonFRLG/RngSeeds/FR_Eng.json" "$WORK/res/PokemonFRLG/RngSeeds/FR_Eng.json" <<'PY'
import json, sys
table = json.load(open(sys.argv[1]))
json.dump({name: column[:300] for name, column in table.items()}, open(sys.argv[2], "w"), indent=1)
PY

clang++ -std=c++23 -O2 -I"$FORK" -I"$SOURCE" -I"$SOURCE/VideoGames" -o "$WORK/generate_golden" \
  "$HERE/generate_golden.cpp" \
  "$SOURCE/Pokemon/Pokemon_AdvRng.cpp" \
  "$SOURCE/Pokemon/Pokemon_StatsCalculation.cpp" \
  "$SOURCE/VideoGames/PokemonFRLG/Programs/RngManipulation/PokemonFRLG_EncountersDatabase.cpp" \
  "$SOURCE/VideoGames/PokemonFRLG/Programs/RngManipulation/PokemonFRLG_SeedsDatabase.cpp" \
  "$FORK/Common/Cpp/Json/JsonValue.cpp" \
  "$FORK/Common/Cpp/Json/JsonArray.cpp" \
  "$FORK/Common/Cpp/Json/JsonObject.cpp" \
  "$FORK/Common/Cpp/Json/JsonTools.cpp" \
  "$HERE/link_stubs.cpp"
"$WORK/generate_golden" "$HERE/../fixtures" "$WORK/res"
