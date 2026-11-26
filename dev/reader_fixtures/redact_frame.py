"""Redacts a console capture to what the readers probe, so a reader test's
frame keeps no personal content (avatars, names, boxes, game libraries).

  python3 redact_frame.py SPEC KEEP [--grey-busy REGEX] IN OUT

SPEC is a probe spec as the tests' write_probe_spec.exe prints it ({"probes":
[{"id", "box": {x, y, w, h}}]}, boxes as fractions of the frame, the native
viewport). KEEP is a regular expression: the probes whose id it matches (from
the start) keep their box's pixels, 2 px more each side for the daemon's
rounding; everything else becomes flat mid-grey (128, 128, 128). With
--grey-busy, the kept boxes whose id matches REGEX and whose pixels are not
flat (their channels' standard deviations summing to more than 25) become
mid-grey too: a box slot holding a Pokémon, which a reader only needs to tell
from an empty one; the other kept boxes are pasted again over them. OUT is written as PNG, the frame's size unchanged.

Needs Pillow (uv run --with pillow python3 redact_frame.py ...).
"""

import json
import re
import sys

from PIL import Image, ImageStat

GREY = (128, 128, 128)
MARGIN = 2
FLAT_MAX_STDDEV_SUM = 25


def pixel_box(box, size, margin):
    w, h = size
    left = max(0, int(box["x"] * w) - margin)
    top = max(0, int(box["y"] * h) - margin)
    right = min(w, int(round((box["x"] + box["w"]) * w)) + margin)
    bottom = min(h, int(round((box["y"] + box["h"]) * h)) + margin)
    return (left, top, right, bottom)


def busy(image, rect):
    return sum(ImageStat.Stat(image.crop(rect)).stddev) > FLAT_MAX_STDDEV_SUM


def main(argv):
    grey_busy = None
    if "--grey-busy" in argv:
        i = argv.index("--grey-busy")
        grey_busy = re.compile(argv[i + 1])
        argv = argv[:i] + argv[i + 2 :]
    spec_path, keep, src, out = argv
    keep = re.compile(keep)
    probes = json.load(open(spec_path))["probes"]
    image = Image.open(src).convert("RGB")
    redacted = Image.new("RGB", image.size, GREY)
    kept = [p for p in probes if keep.match(p["id"])]
    for p in kept:
        rect = pixel_box(p["box"], image.size, MARGIN)
        redacted.paste(image.crop(rect), rect)
    if grey_busy:
        for p in kept:
            if grey_busy.match(p["id"]):
                rect = pixel_box(p["box"], image.size, MARGIN)
                if busy(image, pixel_box(p["box"], image.size, 0)):
                    redacted.paste(GREY, rect)
        # The other kept boxes again, over any greyed box they overlap (the
        # cursor's arrow over the slot above it).
        for p in kept:
            if not grey_busy.match(p["id"]):
                rect = pixel_box(p["box"], image.size, MARGIN)
                redacted.paste(image.crop(rect), rect)
    redacted.save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1:])
