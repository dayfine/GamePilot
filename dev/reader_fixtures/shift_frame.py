"""Writes each frame again with its colors shifted, as another capture card
or emulator might show it, for the readers' tolerance tests.

  python3 shift_frame.py [--one] OUT IMAGE...

Each IMAGE (a path relative to the current directory) is written to
OUT/<shift>/IMAGE for every shift below, channel values clamped to 0..255.
With --one, each IMAGE gets one shift only, picked from its path's MD5 so it
stays the same as other frames come and go (the fixture stays small and every
shift still runs on some frames):

  bright90, bright110   every channel times 0.9, 1.1
  rplus12, rminus12     red plus or minus 12 (gplus12 ... bminus12 likewise)
  grey10                every channel pulled 10% toward mid-grey (128)

Needs Pillow (uv run --with pillow python3 shift_frame.py ...).
"""

import hashlib
import os
import sys

from PIL import Image


def clamp(v):
    return max(0, min(255, round(v)))


def table(f):
    return [clamp(f(v)) for v in range(256)]


SAME = list(range(256))


def everywhere(f):
    t = table(f)
    return (t, t, t)


def one_channel(index, offset):
    t = table(lambda v: v + offset)
    return tuple(t if i == index else SAME for i in range(3))


SHIFTS = {
    "bright90": everywhere(lambda v: v * 0.9),
    "bright110": everywhere(lambda v: v * 1.1),
    "grey10": everywhere(lambda v: v + 0.1 * (128 - v)),
}
for index, channel in enumerate("rgb"):
    SHIFTS[channel + "plus12"] = one_channel(index, 12)
    SHIFTS[channel + "minus12"] = one_channel(index, -12)


def picked(image, one):
    if not one:
        return list(SHIFTS.items())
    names = list(SHIFTS)
    index = int(hashlib.md5(image.encode()).hexdigest(), 16) % len(names)
    return [(names[index], SHIFTS[names[index]])]


def main():
    args = sys.argv[1:]
    one = args[:1] == ["--one"]
    if one:
        args = args[1:]
    out, images = args[0], args[1:]
    for image in images:
        frame = Image.open(image).convert("RGB")
        for name, (r, g, b) in picked(image, one):
            path = os.path.join(out, name, image)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            frame.point(r + g + b).save(path)


if __name__ == "__main__":
    main()
