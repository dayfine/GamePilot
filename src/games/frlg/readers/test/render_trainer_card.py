"""Renders the FireRed Trainer Card's front from pret pokefirered's graphics.

The card as src/trainer_card.c draws it for a male player's own card: BG2 the
screen behind the card (bg.bin), BG0 the card (front.bin, tiles.png, the
card's palette for its star count), BG3 the stars (tile 143, star.pal) and the
earned badges (badges.png, from tile 192) by DrawStarsAndBadgesOnCard. Text
(BG1) and the trainer's picture are not drawn: the card readers' boxes avoid
them. Colors are 5-bit GBA colors widened as mGBA shows them (c << 3 | c >> 2).
A fade multiplies every color, as the palette fade in from black does.

These renders stand in for mGBA frames until real ones are captured
(trainer_card_front.mli). Needs Pillow and a pokefirered clone (a sparse one
works: files are read with git show):

  python3 render_trainer_card.py POKEFIRERED OUT.png BADGES STARS [FADE]

BADGES is eight 0/1 digits, slot 1 (Boulder) first; STARS 0 to 4; FADE 0 to 1
(default 1, the card shown).
"""

import io
import struct
import subprocess
import sys

from PIL import Image

CARD_PALETTES = ["blue", "green", "bronze", "silver", "gold"]
WIDTH, HEIGHT = 30, 20
STAR_TILE, STAR_PALETTE, STAR_X, STAR_Y = 143, 4, 15, 7
BADGE_TILE, BADGE_PALETTE, BADGE_X, BADGE_Y, BADGE_PITCH = 192, 3, 4, 16, 3


def git_file(repo, path):
    return subprocess.run(
        ["git", "-C", repo, "show", "HEAD:" + path], check=True, capture_output=True
    ).stdout


def jasc(text):
    lines = text.decode().splitlines()[3:]
    return [tuple(int(v) for v in line.split()) for line in lines if line.strip()]


def as_shown(color, fade):
    return tuple(int((((v >> 3) << 3) | (v >> 5)) * fade) for v in color)


def tilemap(data):
    entries = struct.unpack("<600H", data)
    return [list(entries[WIDTH * r : WIDTH * (r + 1)]) for r in range(HEIGHT)]


class Card:
    def __init__(self, repo, stars):
        def gfx(name):
            return git_file(repo, "graphics/trainer_card/" + name)

        self.palettes = [[(255, 0, 255)] * 16 for _ in range(16)]
        card = jasc(gfx(CARD_PALETTES[stars] + ".pal"))
        for i in range(3):
            self.palettes[i] = card[16 * i : 16 * i + 16]
        self.tiles = Image.open(io.BytesIO(gfx("tiles.png")))
        self.badges = Image.open(io.BytesIO(gfx("badges.png")))
        flat = self.badges.getpalette()[:48]
        self.palettes[BADGE_PALETTE] = [tuple(flat[3 * i : 3 * i + 3]) for i in range(16)]
        self.palettes[STAR_PALETTE] = jasc(gfx("star.pal"))
        self.screen = tilemap(gfx("bg.bin"))
        self.front = tilemap(gfx("front.bin"))

    def tile(self, n):
        image, n = (self.tiles, n) if n < BADGE_TILE else (self.badges, n - BADGE_TILE)
        per_row = image.size[0] // 8
        x, y = (n % per_row) * 8, (n // per_row) * 8
        return [[image.getpixel((x + i, y + j)) & 15 for i in range(8)] for j in range(8)]

    def draw(self, image, entries, fade, opaque_only):
        for ty, row in enumerate(entries):
            for tx, entry in enumerate(row):
                if entry is None:
                    continue
                pixels = self.tile(entry & 0x3FF)
                hflip, vflip, palette = entry >> 10 & 1, entry >> 11 & 1, entry >> 12
                for j in range(8):
                    for i in range(8):
                        c = pixels[7 - j if vflip else j][7 - i if hflip else i]
                        if c == 0 and opaque_only:
                            continue
                        color = as_shown(self.palettes[palette][c], fade)
                        image.putpixel((tx * 8 + i, ty * 8 + j), color)


def overlay(badges, stars):
    entries = [[None] * WIDTH for _ in range(HEIGHT)]
    for k in range(stars):
        entries[STAR_Y][STAR_X + k] = STAR_TILE | STAR_PALETTE << 12
    for i, earned in enumerate(badges):
        if earned != "1":
            continue
        x, tile = BADGE_X + BADGE_PITCH * i, BADGE_TILE + 2 * i
        for dx, dy, dt in [(0, 0, 0), (1, 0, 1), (0, 1, 16), (1, 1, 17)]:
            entries[BADGE_Y + dy][x + dx] = (tile + dt) | BADGE_PALETTE << 12
    return entries


def main(repo, out, badges, stars, fade="1"):
    stars, fade = int(stars), float(fade)
    card = Card(repo, stars)
    image = Image.new("RGB", (WIDTH * 8, HEIGHT * 8))
    card.draw(image, card.screen, fade, opaque_only=False)
    card.draw(image, card.front, fade, opaque_only=True)
    card.draw(image, overlay(badges, stars), fade, opaque_only=True)
    image.save(out)


if __name__ == "__main__":
    main(*sys.argv[1:])
