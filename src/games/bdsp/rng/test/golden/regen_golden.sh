#!/bin/sh
# Remakes the golden vectors in ../fixtures from the fork's C++ (the oracle, D6):
# builds generate_golden.cpp with plain clang++ against the C++ sources it ports
# and runs it. link_stubs.cpp stands in for the app-wide error and cancellation
# code those sources name but the generator never reaches.
#
# -ffp-contract=off keeps every float operation rounded as written. Clang on
# arm64 otherwise fuses BlinkModel's "f * min + (1 - f) * max" into an FMA and
# differs from x86 and MSVC builds (and from OCaml) by one ulp.
#
#   sh src/games/bdsp/rng/test/golden/regen_golden.sh
#
# FORK is an Arduino-Source checkout with the BDSP RNG code (default
# ~/Projects/wt/dev-bdsp; the fixtures in this folder came from its commit
# c23af4605). Commit the regenerated fixtures with the fork commit used.
set -eu

FORK=${FORK:-$HOME/Projects/wt/dev-bdsp}
SOURCE=$FORK/SerialPrograms/Source
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

clang++ -std=c++23 -O2 -ffp-contract=off -I"$FORK" -I"$SOURCE" -o "$WORK/generate_golden" \
  "$HERE/generate_golden.cpp" \
  "$SOURCE/Pokemon/Pokemon_Xorshift128.cpp" \
  "$SOURCE/Pokemon/Pokemon_Gf2Matrix.cpp" \
  "$SOURCE/Pokemon/Pokemon_Xoroshiro128Plus.cpp" \
  "$SOURCE/Pokemon/Pokemon_BdspRng.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.cpp" \
  "$FORK/Common/Cpp/PrettyPrint.cpp" \
  "$HERE/link_stubs.cpp"
"$WORK/generate_golden" "$HERE/../fixtures"
