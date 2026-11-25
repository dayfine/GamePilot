#!/usr/bin/env python3
"""Writes the FRLG wild encounter slots per game, for the wild RNG target search.

Reads Packages' Resources/PokemonFRLG/EncounterSlotsFR.json and
EncounterSlotsLG.json ({type: {location: [{species, minLevel, maxLevel}]}}) and
writes them in the same shape, one location per line, to
src/games/frlg/assets/encounter_slots_<game>.json (firered, leafgreen). The
slots are the same in every language. Run it from the repo root after the
Packages submodule moves:

    python3 src/games/frlg/assets/extract/extract_frlg_encounter_slots.py third_party/Packages
"""

import json
import sys

SOURCES = {
    "firered": "Resources/PokemonFRLG/EncounterSlotsFR.json",
    "leafgreen": "Resources/PokemonFRLG/EncounterSlotsLG.json",
}
OUTPUT = "src/games/frlg/assets/encounter_slots_%s.json"


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(", ", ": "))


def write(kinds, out):
    out.write("{\n")
    for i, (kind, locations) in enumerate(kinds.items()):
        out.write("  %s: {\n" % compact(kind))
        rows = ["    %s: %s" % (compact(name), compact(slots)) for name, slots in locations.items()]
        out.write(",\n".join(rows))
        out.write("\n  }%s\n" % ("," if i + 1 < len(kinds) else ""))
    out.write("}\n")


def main(packages):
    for game, source in SOURCES.items():
        with open(packages + "/" + source, encoding="utf-8") as f:
            kinds = json.load(f)
        with open(OUTPUT % game, "w", encoding="utf-8", newline="\n") as out:
            write(kinds, out)


if __name__ == "__main__":
    main(sys.argv[1])
