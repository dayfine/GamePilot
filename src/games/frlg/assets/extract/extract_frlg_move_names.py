#!/usr/bin/env python3
"""Writes the FRLG move names per language, for the FRLG text reader.

Reads Packages' Resources/PokemonFRLG/BattleMovesOCR.json
({language: {slug: [names]}}) and writes one file per language it has,
src/games/frlg/assets/move_names_<language>.txt: <slug> <name> per line, the
slug's first name, in the JSON's order. Run it from the repo root after the
Packages submodule moves:

    python3 src/games/frlg/assets/extract/extract_frlg_move_names.py third_party/Packages
"""

import json
import sys

SOURCE = "Resources/PokemonFRLG/BattleMovesOCR.json"
OUTPUT = "src/games/frlg/assets/move_names_%s.txt"


def main(packages):
    with open(packages + "/" + SOURCE, encoding="utf-8") as f:
        languages = json.load(f)
    for language, moves in languages.items():
        with open(OUTPUT % language, "w", encoding="utf-8", newline="\n") as out:
            out.write("# FRLG move names (%s), made by src/games/frlg/assets/extract/extract_frlg_move_names.py\n" % language)
            out.write("# from Packages %s: <slug> <name>\n" % SOURCE)
            for slug, names in moves.items():
                out.write("%s %s\n" % (slug, names[0]))


if __name__ == "__main__":
    main(sys.argv[1])
