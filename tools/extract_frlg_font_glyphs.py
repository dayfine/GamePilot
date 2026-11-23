#!/usr/bin/env python3
"""Writes the FRLG Latin glyph table GamePilot draws text templates from.

Reads a pret/pokefirered checkout (graphics/fonts/latin_normal.png, the glyph
width table in src/text.c and charmap.txt) and prints one line per glyph:

    <code> <width> <codepoint> <row>/<row>/...

<code> is the game's character code (hex), <codepoint> the character's Unicode
code point (hex), and each row has <width> pixels: '.' background,
'#' text, 's' shadow. Latin glyphs advance by their width; the game adds no
letter spacing (RenderText in src/text.c).

    python3 tools/extract_frlg_font_glyphs.py ~/Projects/pokefirered \
        > src/games/frlg/assets/font_latin_normal.glyphs

Stdlib only: the font PNG is a 2-bit paletted image with no interlace.
"""

import re
import struct
import sys
import zlib

GLYPH_CELL = 16  # each glyph is a 16x16 cell, 16 cells per row in the PNG
GLYPH_HEIGHT = 14  # gGlyphInfo.height for FONT_NORMAL Latin glyphs
LAST_CODE = 0xFE  # 0xFF ends a string
JAPANESE_SECTION = "@ Hiragana"
PIXEL_CHARS = {0: ".", 1: "#", 2: "s", 3: "."}  # palette index -> pixel


def png_indices(path):
    """Palette indices of a non-interlaced paletted PNG, as rows of ints."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind, body = data[pos + 4 : pos + 8], data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert color == 3 and interlace == 0, "expected a paletted PNG"
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    stride = (width * depth + 7) // 8
    rows, prev = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1 : start + 1 + stride])
        assert kind in (0, 2), "filter %d not needed by the font PNGs" % kind
        if kind == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        prev = line
        per_byte = 8 // depth
        mask = (1 << depth) - 1
        rows.append(
            [(line[x // per_byte] >> (8 - depth * (x % per_byte + 1))) & mask for x in range(width)]
        )
    return rows


def glyph_widths(text_c):
    """sFontNormalLatinGlyphWidths from src/text.c."""
    source = open(text_c, encoding="utf-8").read()
    match = re.search(r"sFontNormalLatinGlyphWidths\[\]\s*=\s*\{([^}]*)\}", source)
    return [int(v) for v in re.findall(r"\d+", match.group(1))]


def charmap_chars(charmap):
    """(character, game code) for the single-character entries of the Western
    section, which ends where the Japanese one starts. A code may have two
    characters (' and its typographic form share one glyph)."""
    chars = []
    for line in open(charmap, encoding="utf-8"):
        if line.startswith(JAPANESE_SECTION):
            break
        match = re.match(r"^'\\?(.)'\s*=\s*([0-9A-F]{2})\s*$", line)
        if match:
            chars.append((match.group(1), int(match.group(2), 16)))
    return chars


def main(decomp):
    pixels = png_indices(decomp + "/graphics/fonts/latin_normal.png")
    widths = glyph_widths(decomp + "/src/text.c")
    chars = charmap_chars(decomp + "/charmap.txt")
    cells_per_row = len(pixels[0]) // GLYPH_CELL
    print("# FRLG FONT_NORMAL Latin glyphs, made by tools/extract_frlg_font_glyphs.py")
    print("# from pret/pokefirered: <code> <width> <codepoint> <rows> (see the script)")
    for char, code in sorted(chars, key=lambda entry: entry[1]):
        if code > LAST_CODE:
            continue
        top = (code // cells_per_row) * GLYPH_CELL
        left = (code % cells_per_row) * GLYPH_CELL
        width = widths[code]
        rows = [
            "".join(PIXEL_CHARS[pixels[top + y][left + x]] for x in range(width))
            for y in range(GLYPH_HEIGHT)
        ]
        print("%02X %d %04X %s" % (code, width, ord(char), "/".join(rows)))


if __name__ == "__main__":
    main(sys.argv[1])
