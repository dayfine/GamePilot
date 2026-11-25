"""Draws the fork's synthetic test frames (1920 x 1080 PNGs) into OUT/synthetic/,
for regen_fixture.sh, as PokemonLZA_DialogDetectors_Tests.cpp builds them.

  python3 draw_synthetic_frames.py OUT

Needs Pillow (uv run --with pillow python3 draw_synthetic_frames.py OUT).
"""

import os
import sys

from PIL import Image

WIDTH, HEIGHT = 1920, 1080


def solid(argb):
    return Image.new("RGB", (WIDTH, HEIGHT), rgb(argb))


def rgb(argb):
    return ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF)


FRAMES = {
    # DIALOG_CASES' "a black frame".
    "black": lambda: solid(0xFF000000),
}


def main():
    out = os.path.join(sys.argv[1], "synthetic")
    os.makedirs(out, exist_ok=True)
    for name, draw in FRAMES.items():
        draw().save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main()
