"""Draws the fork's synthetic test frames (1920 x 1080 PNGs) into OUT/synthetic/,
for regen_fixture.sh, as PokemonLZA_DialogDetectors_Tests.cpp and
PokemonLZA_Detectors_Tests.cpp build them. Also our own frames of the move
effectiveness symbols under ZL, which no console capture in CommandLineTests
shows: the four symbols' Packages images (4K-sized), halved and laid over a
dark button in the four moves' boxes (PokemonLZA_MoveEffectivenessSymbol.cpp).

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


WHITE = 0xFFFFFFFF


def fill(image, min_x, min_y, max_x, max_y, argb):
    image.paste(rgb(argb), (min_x, min_y, max_x, max_y))


def autosave_badge(background, glow, mint_bands=False):
    image = solid(background)
    fill(image, 1655, 73, 1667, 104, glow)
    fill(image, 1659, 73, 1663, 104, WHITE)
    if mint_bands:
        fill(image, 1600, 60, 1720, 64, 0xFF60CB93)
        fill(image, 1600, 112, 1720, 116, 0xFF60CB93)
    return image


PAVEMENT = 0xFFC8C3BE
BLUE_WALL = 0xFF18375C
PANEL = 0xFF243C6C
DARK_TEXT = 0xFF1E1E28
NARROW = (1408, 1540)  # the panel's left, the text's end
WIDE_SHORT_ROWS = (1343, 1400)


def choice_menu(background, rows, highlighted, width=NARROW):
    panel_left, text_end = width
    image = solid(background)
    fill(image, panel_left, 808 - 80 * rows - 4, 1728, 808, PANEL)
    for row in range(rows):
        top = 732 - 80 * (rows - 1 - row)
        lit = row in highlighted
        if lit:
            fill(image, panel_left + 10, top, 1715, top + 68, WHITE)
        for x in range(panel_left + 35, text_end, 3):
            fill(image, x, top + 16, x + 1, top + 52, DARK_TEXT if lit else WHITE)
    return image


HERE = os.path.dirname(os.path.abspath(__file__))
SYMBOLS = os.path.join(
    HERE, "..", "..", "..", "..", "..", "..",
    "third_party", "Packages", "Resources", "PokemonLZA", "MoveEffectiveness")
# The moves' boxes: top, left, right, bottom (fractions of the frame).
MOVE_BOXES = [(0.780, 0.750), (0.750, 0.800), (0.806, 0.800), (0.780, 0.850)]
MOVE_BOX = (0.025, 0.041)
BUTTON = 0xFF2A2E3A


def move_symbols(symbols):
    image = solid(PAVEMENT)
    for (left, top), symbol in zip(MOVE_BOXES, symbols):
        x, y = int(left * WIDTH), int(top * HEIGHT)
        w, h = int(MOVE_BOX[0] * WIDTH), int(MOVE_BOX[1] * HEIGHT)
        fill(image, x - 6, y - 6, x + w + 6, y + h + 6, BUTTON)
        if symbol is None:
            continue
        icon = Image.open(os.path.join(SYMBOLS, "MoveEffectiveness-%s.png" % symbol))
        icon = icon.convert("RGBA").resize((icon.width // 2, icon.height // 2), Image.LANCZOS)
        image.paste(icon, (x + (w - icon.width) // 2, y + (h - icon.height) // 2), icon)
    return image


FRAMES = {
    # DIALOG_CASES' "a black frame".
    "black": lambda: solid(0xFF000000),
    # The autosave badge cases.
    "autosave-dim-glow-dark-wall": lambda: autosave_badge(0xFF252722, 0xFF1C4655),
    "autosave-stroke-no-glow": lambda: autosave_badge(0xFF252722, 0xFF252722),
    "autosave-mint-banner-bands": lambda: autosave_badge(0xFF101418, 0xFF28C8E6, True),
    "autosave-stroke-green-sign-glow": lambda: autosave_badge(0xFF252722, 0xFF3CF06E),
    # The choice rows cases.
    "choice-3-rows-middle": lambda: choice_menu(BLUE_WALL, 3, {1}),
    "choice-3-short-rows-wide-bottom": lambda: choice_menu(BLUE_WALL, 3, {2}, WIDE_SHORT_ROWS),
    "choice-1-row": lambda: choice_menu(PAVEMENT, 1, {0}),
    "choice-3-rows-none": lambda: choice_menu(PAVEMENT, 3, set()),
    "choice-3-rows-two": lambda: choice_menu(PAVEMENT, 3, {0, 2}),
    # Ours: the move symbols under ZL.
    "moves-normal-super-notvery-none": lambda: move_symbols(
        ["Normal", "SuperEffective", "NotVeryEffective", "NoEffect"]),
    "moves-super-none-normal-notvery": lambda: move_symbols(
        ["SuperEffective", "NoEffect", "Normal", "NotVeryEffective"]),
    "moves-two-blank": lambda: move_symbols(["Normal", None, None, "Normal"]),
    "moves-no-symbols": lambda: move_symbols([None, None, None, None]),
}


def main():
    out = os.path.join(sys.argv[1], "synthetic")
    os.makedirs(out, exist_ok=True)
    for name, draw in FRAMES.items():
        draw().save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main()
