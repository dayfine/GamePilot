#!/bin/sh
# Remakes the golden vectors in ../fixtures from the fork's C++ (the oracle, D6):
# builds generate_golden.cpp with plain clang++ against the C++ sources it ports
# and runs it. link_stubs.cpp stands in for the app-wide error and cancellation
# code those sources name but the generator never reaches.
#
# BlinkExtraction's header includes the eye detector's, which names OpenCV
# types; the fork's vendored OpenCV headers satisfy it and nothing links them.
#
# BlinkRecovery.cpp also holds the video and controller loops, whose symbols
# nothing here defines; -dead_strip (Apple's linker) drops those functions, as
# the generator calls only the pure ones (update_provisional,
# build_blink_streams, reanchor_absolute).
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

clang++ -std=c++23 -O2 -ffp-contract=off -I"$FORK" -I"$SOURCE" -I"$FORK/3rdParty/opencv-4.12.0" -Wl,-dead_strip -o "$WORK/generate_golden" \
  "$HERE/generate_golden.cpp" \
  "$HERE/generate_golden_recovery.cpp" \
  "$SOURCE/Pokemon/Pokemon_Xorshift128.cpp" \
  "$SOURCE/Pokemon/Pokemon_Gf2Matrix.cpp" \
  "$SOURCE/Pokemon/Pokemon_Xoroshiro128Plus.cpp" \
  "$SOURCE/Pokemon/Pokemon_BdspRng.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateReidentifier.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_AdvanceClock.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_RngCalibration.cpp" \
  "$SOURCE/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.cpp" \
  "$SOURCE/Pokemon/Pokemon_StatsCalculation.cpp" \
  "$SOURCE/PokemonBDSP/Inference/Rng/PokemonBDSP_BlinkExtraction.cpp" \
  "$FORK/Common/Cpp/PrettyPrint.cpp" \
  "$HERE/link_stubs.cpp"
"$WORK/generate_golden" "$HERE/../fixtures"
