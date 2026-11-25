#!/usr/bin/env python3
"""Writes the PLZA readers' core.find@1 templates and the advance chevron's shape.

Templates: the fork makes each template from a Packages image
(CommonTools/ImageMatch/WaterfillTemplateMatcher.cpp): the pixels within a
colour range (alpha included), cut into 4-connected blobs of a least area, and
the largest blob's bounding box cropped from the image, every channel kept.
The daemon scores a blob against the PNG it is given, so it gets that crop;
the crop's fill (its blob's pixels over its box's) goes to templates.json
beside the crops for the readers.

Shape: the chevron's V (PokemonLZA_StoryDialogDetector.cpp), drawn at
2560 x 1520 as daemon/tests/blob_find_test.cpp draws it, opaque where
abs(abs(u - 0.5) - (0.40 * (1 - v) + 0.03)) <= 0.11 at the pixel's centre.

    uv run --with pillow python3 src/games/pokemon/plza/assets/extract/write_find_templates.py \
        third_party/Packages/Resources src/games/pokemon/plza/assets/templates
"""

import json
import os
import sys

from PIL import Image

# name: (Packages image, low colour, high colour, least area), as the fork
# makes each template (0xAARRGGBB; an opaque colour has alpha ff).
MATCHERS = {
    "dialog_white_arrow": (
        "PokemonLZA/DialogBox/DialogBoxWhiteArrow-Template.png",
        0xFFC0C0C0, 0xFFFFFFFF, 50),
    "dialog_black_arrow": (
        "PokemonLZA/DialogBox/DialogBoxBlackArrow-Template.png",
        0xFF000000, 0xFF5A5A5A, 50),
    "dialog_teal_arrow": (
        "PokemonLZA/DialogBox/DialogBoxTealArrow-Template.png",
        0xFF00C080, 0xFF3FFFFF, 50),
    "choice_arrow": (
        "PokemonLZA/SelectionArrowRight.png",
        0xFF80C000, 0xFFFFFF7F, 100),
    # PokemonLZA_ButtonDetector.cpp's ButtonMatcher::A.
    "button_a": (
        "PokemonLZA/Buttons/ButtonA.png",
        0xFF808008, 0xFFFFFFFF, 100),
    # ButtonMatcher::DpadUp and DpadDown, and their black interiors (the
    # Interior matchers: the dark range, least area 50), for
    # PokemonLZA_OverworldPartySelectionDetector.cpp's party bar marker.
    "button_dpad_up": (
        "PokemonLZA/Buttons/ButtonDpadUp.png",
        0xFF808008, 0xFFFFFFFF, 100),
    "button_dpad_down": (
        "PokemonLZA/Buttons/ButtonDpadDown.png",
        0xFF808008, 0xFFFFFFFF, 100),
    "button_dpad_up_interior": (
        "PokemonLZA/Buttons/ButtonDpadUp.png",
        0xFF000000, 0xFF404040, 50),
    "button_dpad_down_interior": (
        "PokemonLZA/Buttons/ButtonDpadDown.png",
        0xFF000000, 0xFF404040, 50),
    # PokemonLZA_MoveEffectivenessSymbol.cpp's MoveEffectivenessSymbolMatcher.
    "move_no_effect": (
        "PokemonLZA/MoveEffectiveness/MoveEffectiveness-NoEffect.png",
        0xFFE0E0E0, 0xFFFFFFFF, 100),
    "move_not_very_effective": (
        "PokemonLZA/MoveEffectiveness/MoveEffectiveness-NotVeryEffective.png",
        0xFFE0E0E0, 0xFFFFFFFF, 100),
    "move_effective": (
        "PokemonLZA/MoveEffectiveness/MoveEffectiveness-Normal.png",
        0xFFE0E0E0, 0xFFFFFFFF, 100),
    "move_super_effective": (
        "PokemonLZA/MoveEffectiveness/MoveEffectiveness-SuperEffective.png",
        0xFFE0E0E0, 0xFFFFFFFF, 100),
}

SHAPE_WIDTH = 2560
SHAPE_HEIGHT = 1520


def argb(value):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, (value >> 24) & 0xFF)


def mask_of(image, low, high):
    pixels = image.load()
    width, height = image.size
    lo, hi = argb(low), argb(high)
    return [
        [all(lo[c] <= pixels[x, y][c] <= hi[c] for c in range(4)) for x in range(width)]
        for y in range(height)
    ]


def blobs(mask):
    """4-connected blobs: (area, min_x, min_y, max_x, max_y), max exclusive."""
    height, width = len(mask), len(mask[0])
    seen = [[False] * width for _ in range(height)]
    found = []
    for y0 in range(height):
        for x0 in range(width):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            seen[y0][x0] = True
            stack, area = [(x0, y0)], 0
            min_x, min_y, max_x, max_y = x0, y0, x0, y0
            while stack:
                x, y = stack.pop()
                area += 1
                min_x, min_y = min(min_x, x), min(min_y, y)
                max_x, max_y = max(max_x, x), max(max_y, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            found.append((area, min_x, min_y, max_x + 1, max_y + 1))
    return found


def crop(resources, out, name, spec):
    path, low, high, min_area = spec
    image = Image.open(os.path.join(resources, path)).convert("RGBA")
    candidates = [b for b in blobs(mask_of(image, low, high)) if b[0] >= min_area]
    # The first largest, as the fork keeps the first of equal areas.
    area, min_x, min_y, max_x, max_y = max(candidates, key=lambda b: b[0])
    image.crop((min_x, min_y, max_x, max_y)).save(os.path.join(out, name + ".png"))
    width, height = max_x - min_x, max_y - min_y
    return {"width": width, "height": height, "fill": round(area / (width * height), 6)}


def chevron_shape(out):
    shape = Image.new("LA", (SHAPE_WIDTH, SHAPE_HEIGHT), (0, 0))
    pixels = shape.load()
    for y in range(SHAPE_HEIGHT):
        v = (y + 0.5) / SHAPE_HEIGHT
        for x in range(SHAPE_WIDTH):
            u = (x + 0.5) / SHAPE_WIDTH
            if abs(abs(u - 0.5) - (0.40 * (1 - v) + 0.03)) <= 0.11:
                pixels[x, y] = (255, 255)
    shape.save(os.path.join(out, "advance_chevron_shape.png"), optimize=True)


def main():
    resources, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    measured = {name: crop(resources, out, name, spec) for name, spec in MATCHERS.items()}
    with open(os.path.join(out, "templates.json"), "w") as f:
        json.dump(measured, f, indent=2, sort_keys=True)
        f.write("\n")
    chevron_shape(out)


if __name__ == "__main__":
    main()
