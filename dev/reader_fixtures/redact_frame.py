"""Redacts a console capture to what the readers probe, so a reader test's
frame keeps no personal content (avatars, names, boxes, game libraries).

  python3 redact_frame.py SPEC KEEP [--pattern-busy REGEX] [--fill-mean]
      [--pattern X,Y,W,H]... [--line-test REGEX] [--grey X,Y,W,H]... IN OUT

SPEC is a probe spec as the tests' write_probe_spec.exe prints it ({"probes":
[{"id", "box": {x, y, w, h}}]}, boxes as fractions of the frame, the native
viewport). KEEP is a regular expression: the probes whose id it matches (from
the start) keep their box's pixels, 2 px more each side for the daemon's
rounding; everything else becomes flat mid-grey (128, 128, 128). With
--pattern-busy, the kept boxes whose id matches REGEX and whose pixels are not
flat (their channels' standard deviations summing to more than 25) become a
checkerboard as --pattern makes: a box slot holding a Pokémon, which a reader
only needs to tell from an empty one; the other kept boxes are pasted again
over them. With
--fill-mean, the fill is the frame's own mean colour instead of mid-grey, so a
whole-picture probe's brightness stays near the capture's (a dimmed screen
stays dark). Each --pattern region (frame pixels) is first replaced by a
checkerboard of 8 px squares, its own mean colour 48 lighter and darker: for a
personal picture inside a probed box (a profile's icon and name), keeping the
box's colour and detail without the picture. With --line-test, the kept
[core.line_shares@1] boxes whose id matches REGEX keep only the pixels that
pass the probe's test, pasted last over whatever lies under them, so the probe
reads the same and only what it counts stays (a cursor's arrow, not the Pokémon
behind it). Each --grey region
(frame pixels) is filled last: text inside a kept box that its probe does not
count (a total on a button whose colour is read). OUT is written as PNG, the frame's size unchanged.

Needs Pillow (uv run --with pillow python3 redact_frame.py ...).
"""

import json
import re
import sys

from PIL import Image, ImageStat

GREY = (128, 128, 128)
MARGIN = 2
FLAT_MAX_STDDEV_SUM = 25
SQUARE = 8
CONTRAST = 48


def pixel_box(box, size, margin):
    w, h = size
    left = max(0, int(box["x"] * w) - margin)
    top = max(0, int(box["y"] * h) - margin)
    right = min(w, int(round((box["x"] + box["w"]) * w)) + margin)
    bottom = min(h, int(round((box["y"] + box["h"]) * h)) + margin)
    return (left, top, right, bottom)


def busy(image, rect):
    return sum(ImageStat.Stat(image.crop(rect)).stddev) > FLAT_MAX_STDDEV_SUM


def clamp(v):
    return max(0, min(255, round(v)))


def checker(image, rect):
    left, top, right, bottom = rect
    mean = ImageStat.Stat(image.crop(rect)).mean
    light = tuple(clamp(c + CONTRAST) for c in mean)
    dark = tuple(clamp(c - CONTRAST) for c in mean)
    for y in range(top, bottom, SQUARE):
        for x in range(left, right, SQUARE):
            odd = ((x - left) // SQUARE + (y - top) // SQUARE) % 2
            box = (x, y, min(x + SQUARE, right), min(y + SQUARE, bottom))
            image.paste(light if odd else dark, box)


def passes(pixel, test):
    for t in test:
        v = sum(w * c for w, c in zip(t["weights"], pixel))
        if not (v > t["value"] if t["op"] == ">" else v < t["value"]):
            return False
    return True


def paste_passing(image, redacted, probe):
    rect = pixel_box(probe["box"], image.size, MARGIN)
    for y in range(rect[1], rect[3]):
        for x in range(rect[0], rect[2]):
            if passes(image.getpixel((x, y)), probe["test"]):
                redacted.putpixel((x, y), image.getpixel((x, y)))


def regions(argv, flag):
    found = []
    while flag in argv:
        i = argv.index(flag)
        x, y, w, h = (int(v) for v in argv[i + 1].split(","))
        found.append((x, y, x + w, y + h))
        argv = argv[:i] + argv[i + 2 :]
    return found, argv


def option(argv, flag):
    if flag not in argv:
        return None, argv
    i = argv.index(flag)
    return re.compile(argv[i + 1]), argv[:i] + argv[i + 2 :]


def main(argv):
    patterns, argv = regions(argv, "--pattern")
    greys, argv = regions(argv, "--grey")
    busy_re, argv = option(argv, "--pattern-busy")
    line_test, argv = option(argv, "--line-test")
    fill_mean = "--fill-mean" in argv
    argv = [a for a in argv if a != "--fill-mean"]
    spec_path, keep, src, out = argv
    keep = re.compile(keep)
    probes = json.load(open(spec_path))["probes"]
    image = Image.open(src).convert("RGB")
    for rect in patterns:
        checker(image, rect)
    fill = GREY
    if fill_mean:
        fill = tuple(round(c) for c in ImageStat.Stat(image).mean)
    redacted = Image.new("RGB", image.size, fill)
    kept = [p for p in probes if keep.match(p["id"])]

    def tested(p):
        return bool(line_test and line_test.match(p["id"]) and "test" in p)

    whole = [p for p in kept if not tested(p)]
    for p in whole:
        rect = pixel_box(p["box"], image.size, MARGIN)
        redacted.paste(image.crop(rect), rect)
    if busy_re:
        for p in whole:
            if busy_re.match(p["id"]) and busy(
                image, pixel_box(p["box"], image.size, 0)
            ):
                rect = pixel_box(p["box"], image.size, MARGIN)
                redacted.paste(image.crop(rect), rect)
                checker(redacted, rect)
        # The other kept boxes again, over any patterned box they overlap.
        for p in whole:
            if not busy_re.match(p["id"]):
                rect = pixel_box(p["box"], image.size, MARGIN)
                redacted.paste(image.crop(rect), rect)
    for p in kept:
        if tested(p):
            paste_passing(image, redacted, p)
    for rect in greys:
        redacted.paste(fill, rect)
    redacted.save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1:])
