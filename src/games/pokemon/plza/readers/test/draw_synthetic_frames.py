"""Draws the fork's synthetic test frames (1920 x 1080 PNGs) into OUT/synthetic/,
for regen_fixture.sh, as PokemonLZA_DialogDetectors_Tests.cpp and
PokemonLZA_Detectors_Tests.cpp build them. Also our own frames of the move
effectiveness symbols under ZL, which no console capture in CommandLineTests
shows: the four symbols' Packages images (4K-sized), halved and laid over a
dark button in the four moves' boxes (PokemonLZA_MoveEffectivenessSymbol.cpp).
The map pin and caught mark frames are PokemonLZA_Detectors_Tests.cpp's.

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


# The map pin reader's frames: squares on the zone's green, at map points
# (the frame over 2.4).
ZONE_GREEN = 0xFF98EFAD
ARROW_BLUE = 0xFF00A0FF
CONE_BLUE = 0xFF5EC9EA


def map_with(squares):
    image = solid(ZONE_GREEN)
    for x, y, side, argb in squares:
        cx, cy = int(x * 2.4), int(y * 2.4)
        fill(image, cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2, argb)
    return image


# The caught mark reader's frames: a lock-on name plate's green bar, the
# player's HP bar, the gender mark and the caught mark's Poke Ball.
PLATE_GREEN = 0xFF2DC673
GENDER_ORANGE = 0xFFFF7644
# Ours: the female mark is a pinkish red disc (about 249, 105, 114 on console
# B's run frames) round a white sign; the fork's frames have only the orange.
FEMALE_RED = 0xFFF96972
BALL_RED = 0xFFFF6B6E
BRIGHT_GRASS = 0xFF44A050
DARK_GROUND = 0xFF303030


def female_mark(image):
    fill(image, 1020, 430, 1044, 454, FEMALE_RED)
    # The sign: a ring over a cross, about 70 white pixels (the console's
    # female marks counted 23 to 82 white at 1080p).
    fill(image, 1028, 433, 1036, 441, WHITE)
    fill(image, 1030, 435, 1034, 439, FEMALE_RED)
    fill(image, 1031, 441, 1033, 449, WHITE)
    fill(image, 1029, 445, 1035, 447, WHITE)


def plate(ground, plate_bar=False, player_bar=False, gender=False, ball=False,
          female=False):
    image = solid(ground)
    if plate_bar:
        fill(image, 950, 515, 1058, 533, PLATE_GREEN)
    if player_bar:
        fill(image, 990, 560, 1053, 572, PLATE_GREEN)
    if gender:
        fill(image, 1020, 430, 1044, 454, GENDER_ORANGE)
        fill(image, 1028, 438, 1036, 446, WHITE)
    if female:
        female_mark(image)
    if ball:
        fill(image, 1056, 430, 1080, 442, BALL_RED)
        fill(image, 1056, 442, 1080, 454, WHITE)
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
    # The map pin cases.
    "map-arrow-and-cone": lambda: map_with(
        [(350, 215, 40, CONE_BLUE), (370, 230, 24, ARROW_BLUE)]),
    "map-cone-only": lambda: map_with([(350, 215, 40, CONE_BLUE)]),
    "map-arrow-outside-window": lambda: map_with([(100, 100, 24, ARROW_BLUE)]),
    "map-arrow-speck": lambda: map_with([(400, 230, 6, ARROW_BLUE)]),
    # The caught mark cases.
    "plate-and-player-bar-on-grass": lambda: plate(
        BRIGHT_GRASS, plate_bar=True, player_bar=True),
    "plate-gender-mark-only": lambda: plate(DARK_GROUND, plate_bar=True, gender=True),
    "plate-gender-and-ball-marks": lambda: plate(
        DARK_GROUND, plate_bar=True, gender=True, ball=True),
    # Ours: the female mark, alone and beside the Poke Ball.
    "plate-female-mark-only": lambda: plate(DARK_GROUND, plate_bar=True, female=True),
    "plate-female-and-ball-marks": lambda: plate(
        DARK_GROUND, plate_bar=True, female=True, ball=True),
    "player-bar-alone": lambda: plate(DARK_GROUND, player_bar=True),
    "bright-grass-alone": lambda: plate(BRIGHT_GRASS),
}


def main():
    out = os.path.join(sys.argv[1], "synthetic")
    os.makedirs(out, exist_ok=True)
    for name, draw in FRAMES.items():
        draw().save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main()
