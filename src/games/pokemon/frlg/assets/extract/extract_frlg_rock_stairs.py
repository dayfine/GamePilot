#!/usr/bin/env python3
"""Writes the FRLG rock stairs, for the walker's step times.

A step north off a rock stair (MB_ROCK_STAIRS) or south onto one is slow: the
game walks or runs it with its slow movement (PlayerIsMovingOnRockStairs in
src/field_player_avatar.c). Reads every map's layout (data/maps/*/map.json,
data/layouts/layouts.json) and its tilesets' metatile behaviours from a
pret/pokefirered checkout through `git show` (a sparse checkout works) and
prints one line per map with rock stairs: <map> <x>,<y> ...

    python3 src/games/pokemon/frlg/assets/extract/extract_frlg_rock_stairs.py ~/Projects/pokefirered \
        > src/games/pokemon/frlg/assets/rock_stairs.txt
"""

import json
import re
import struct
import subprocess
import sys

MB_ROCK_STAIRS = 0x2A
METATILE_BEHAVIOR_MASK = 0x1FF
METATILE_ID_MASK = 0x3FF
NUM_METATILES_IN_PRIMARY = 640


def show(decomp, path):
    return subprocess.run(
        ["git", "-C", decomp, "show", "HEAD:" + path], capture_output=True, check=True
    ).stdout


def files(decomp, prefix):
    out = subprocess.run(
        ["git", "-C", decomp, "ls-tree", "-r", "--name-only", "HEAD", prefix],
        capture_output=True, check=True, text=True,
    ).stdout
    return out.split()


def tileset_attributes(decomp):
    """Each tileset's metatile attribute file, by its gTileset_ name."""
    metatiles = show(decomp, "src/data/tilesets/metatiles.h").decode()
    headers = show(decomp, "src/data/tilesets/headers.h").decode()
    paths = dict(re.findall(r'gMetatileAttributes_(\w+)\[\] = INCBIN_U32\("([^"]+)"\)', metatiles))
    found = {}
    for name, body in re.findall(r"const struct Tileset (gTileset_\w+) =\s*\{(.*?)\};", headers, re.S):
        attributes = re.search(r"\.metatileAttributes = gMetatileAttributes_(\w+)", body)
        if attributes and attributes.group(1) in paths:
            found[name] = paths[attributes.group(1)]
    return found


def stairs_of_layout(decomp, layout, attribute_paths, cache):
    def behaviours(tileset):
        if tileset not in attribute_paths:
            return ()
        if tileset not in cache:
            data = show(decomp, attribute_paths[tileset])
            cache[tileset] = struct.unpack("<%dI" % (len(data) // 4), data)
        return cache[tileset]

    primary = behaviours(layout["primary_tileset"])
    secondary = behaviours(layout["secondary_tileset"])

    def behaviour(metatile):
        table, i = (primary, metatile) if metatile < NUM_METATILES_IN_PRIMARY else (
            secondary, metatile - NUM_METATILES_IN_PRIMARY)
        return table[i] & METATILE_BEHAVIOR_MASK if i < len(table) else 0

    data = show(decomp, layout["blockdata_filepath"])
    blocks = struct.unpack("<%dH" % (len(data) // 2), data)
    width = layout["width"]
    return [
        (i % width, i // width)
        for i, block in enumerate(blocks)
        if behaviour(block & METATILE_ID_MASK) == MB_ROCK_STAIRS
    ]


def main(decomp):
    layouts = {
        l["id"]: l
        for l in json.loads(show(decomp, "data/layouts/layouts.json"))["layouts"]
        if "blockdata_filepath" in l
    }
    attribute_paths = tileset_attributes(decomp)
    cache = {}
    print("# FRLG rock stairs, made by src/games/pokemon/frlg/assets/extract/extract_frlg_rock_stairs.py from pret/pokefirered")
    print("# (MB_ROCK_STAIRS metatiles of each map's layout): <map> <x>,<y> ...")
    for path in sorted(p for p in files(decomp, "data/maps") if p.endswith("/map.json")):
        header = json.loads(show(decomp, path))
        layout = layouts.get(header.get("layout"))
        if layout is None:
            continue
        stairs = stairs_of_layout(decomp, layout, attribute_paths, cache)
        if stairs:
            print(header["name"] + " " + " ".join("%d,%d" % tile for tile in stairs))


if __name__ == "__main__":
    main(sys.argv[1])
