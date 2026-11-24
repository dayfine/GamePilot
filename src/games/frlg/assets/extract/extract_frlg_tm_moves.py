#!/usr/bin/env python3
"""Writes the moves FRLG's TMs and HMs teach, for the FRLG text reader.

The TM case shows each TM's move name, so a TM case row's candidates are these
58 moves rather than every move. The data comes from a pret/pokefirered
checkout, as src/games/frlg/assets/extract/extract_frlg_item_names.py's does: src/data/items.json gives
each TM or HM item its moveId (e.g. FocusPunch), and
src/data/text/move_names.h the name the game shows for MOVE_FOCUS_PUNCH. One
line per item: <item> <move name>, in item order.

    python3 src/games/frlg/assets/extract/extract_frlg_tm_moves.py ~/Projects/pokefirered \\
        > src/games/frlg/assets/tm_hm_moves_eng.txt
"""

import json
import re
import sys

MOVE_NAME = re.compile(r'\[(MOVE_\w+)\]\s*=\s*_\("([^"]*)"\)')


def move_constant(move_id):
    """FocusPunch -> MOVE_FOCUS_PUNCH."""
    return "MOVE_" + re.sub(r"(?<!^)(?=[A-Z])", "_", move_id).upper()


def main(decomp):
    items = json.load(open(decomp + "/src/data/items.json", encoding="utf-8"))["items"]
    text = open(decomp + "/src/data/text/move_names.h", encoding="utf-8").read()
    names = dict(MOVE_NAME.findall(text))
    print("# FRLG TM and HM moves, made by src/games/frlg/assets/extract/extract_frlg_tm_moves.py from")
    print("# pret/pokefirered src/data/items.json and src/data/text/move_names.h:")
    print("# <item> <move name>")
    for item in items:
        if item["pocket"] != "POCKET_TM_CASE":
            continue
        constant = move_constant(item["moveId"])
        if constant not in names:
            sys.exit("no name for %s (%s)" % (constant, item["english"]))
        print("%s %s" % (item["english"], names[constant]))


if __name__ == "__main__":
    main(sys.argv[1])
