#!/usr/bin/env python3
"""Writes the English FRLG move names, for the FRLG text reader.

Reads src/data/text/move_names.h from a pret/pokefirered checkout (a sparse
checkout works through `git show`, see below) and prints one line per move:
<slug> <name>, where <slug> is the MOVE_ constant in lowercase with dashes
(MOVE_KARATE_CHOP: karate-chop, the plans' slugs) and <name> the rest of the
line as the game shows it (KARATE CHOP). Four constants keep Gen 3 spellings
the slugs elsewhere (Packages, PokemonSimulation's battle_data_export.py) do
not; they get those slugs. MOVE_NONE's placeholder is left out.

    python3 src/games/frlg/assets/extract/extract_frlg_move_names.py ~/Projects/pokefirered \
        > src/games/frlg/assets/move_names_eng.txt
"""

import re
import subprocess
import sys

ENTRY = re.compile(r'\[MOVE_(\w+)\]\s*= _\("([^"]*)"\)')
SOURCE = "src/data/text/move_names.h"
SLUGS = {
    "FAINT_ATTACK": "feint-attack",
    "HI_JUMP_KICK": "high-jump-kick",
    "SMELLING_SALT": "smelling-salts",
    "VICE_GRIP": "vise-grip",
}


def main(decomp):
    text = subprocess.run(
        ["git", "-C", decomp, "show", "HEAD:" + SOURCE], capture_output=True, check=True, text=True
    ).stdout
    print("# FRLG English move names, made by src/games/frlg/assets/extract/extract_frlg_move_names.py")
    print("# from pret/pokefirered %s: <slug> <name>" % SOURCE)
    for constant, name in ENTRY.findall(text):
        if constant == "NONE":
            continue
        slug = SLUGS.get(constant, constant.lower().replace("_", "-"))
        print("%s %s" % (slug, name))


if __name__ == "__main__":
    main(sys.argv[1])
