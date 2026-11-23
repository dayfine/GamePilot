#!/usr/bin/env python3
"""Writes the English FRLG item names by bag pocket, for the FRLG text reader.

Packages has no FRLG item dictionary (only moves, BattleMovesOCR.json), so the
names come from a pret/pokefirered checkout's src/data/items.json. One line per
item: <pocket> <name>, where <pocket> is items, key_items, poke_balls, tm_case
or berry_pouch and <name> is the rest of the line as the bag shows it.

    python3 tools/extract_frlg_item_names.py ~/Projects/pokefirered \
        > src/games/frlg/assets/item_names_eng.txt
"""

import json
import sys

POCKETS = {
    "POCKET_ITEMS": "items",
    "POCKET_KEY_ITEMS": "key_items",
    "POCKET_POKE_BALLS": "poke_balls",
    "POCKET_TM_CASE": "tm_case",
    "POCKET_BERRY_POUCH": "berry_pouch",
}
UNUSED_NAME = "????????"  # ITEM_NONE and the unused slots
PLACEHOLDER = "{"  # names the game fills in at run time (Emerald's POKéBLOCK CASE)


def main(decomp):
    items = json.load(open(decomp + "/src/data/items.json", encoding="utf-8"))["items"]
    print("# FRLG English item names, made by tools/extract_frlg_item_names.py")
    print("# from pret/pokefirered src/data/items.json: <pocket> <name>")
    seen = set()
    for item in items:
        name = item["english"]
        if name == UNUSED_NAME or PLACEHOLDER in name or name in seen:
            continue
        seen.add(name)
        print("%s %s" % (POCKETS[item["pocket"]], name))


if __name__ == "__main__":
    main(sys.argv[1])
