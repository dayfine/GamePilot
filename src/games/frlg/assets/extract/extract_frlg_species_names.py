#!/usr/bin/env python3
"""Writes the English FRLG species names, for the FRLG text reader.

Reads src/data/text/species_names.h from a pret/pokefirered checkout (a sparse
checkout works through `git show`, see below) and prints one line per species:
<slug> <name>, where <slug> is the SPECIES_ constant in lowercase with dashes
(SPECIES_MR_MIME: mr-mime, the plans' slugs) and <name> the rest of the line as
the game shows it (MR. MIME). The placeholder names (SPECIES_NONE's ??????????,
the old Unown forms' ?) are left out.

    python3 src/games/frlg/assets/extract/extract_frlg_species_names.py ~/Projects/pokefirered \
        > src/games/frlg/assets/species_names_eng.txt
"""

import re
import subprocess
import sys

ENTRY = re.compile(r'\[SPECIES_(\w+)\] = _\("([^"]*)"\)')
SOURCE = "src/data/text/species_names.h"


def main(decomp):
    text = subprocess.run(
        ["git", "-C", decomp, "show", "HEAD:" + SOURCE], capture_output=True, check=True, text=True
    ).stdout
    print("# FRLG English species names, made by src/games/frlg/assets/extract/extract_frlg_species_names.py")
    print("# from pret/pokefirered %s: <slug> <name>" % SOURCE)
    for constant, name in ENTRY.findall(text):
        if set(name) <= {"?"}:
            continue
        print("%s %s" % (constant.lower().replace("_", "-"), name))


if __name__ == "__main__":
    main(sys.argv[1])
