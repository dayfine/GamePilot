#!/usr/bin/env python3
"""Writes an FRLG Latin glyph table GamePilot draws text templates from.

Reads a pret/pokefirered checkout (graphics/fonts/latin_<font>.png, the font's
glyph width table in src/text.c and charmap.txt) and prints one line per glyph:

    <code> <width> <codepoint> <row>/<row>/...

<code> is the game's character code (hex), <codepoint> the character's Unicode
code point (hex), and each row has <width> pixels: '.' background,
'#' text, 's' shadow. Latin glyphs advance by their width; the game adds no
letter spacing (RenderText in src/text.c).

    python3 src/games/frlg/assets/extract/extract_frlg_font_glyphs.py ~/Projects/pokefirered \
        > src/games/frlg/assets/font_latin_normal.glyphs
    python3 src/games/frlg/assets/extract/extract_frlg_font_glyphs.py ~/Projects/pokefirered small \
        > src/games/frlg/assets/font_latin_small.glyphs

The fonts (DecompressGlyph_Normal and DecompressGlyph_Small in src/text.c):
FONT_NORMAL glyphs are 16x16 cells, 16 to a row of the PNG, 14 rows tall;
FONT_SMALL glyphs (the bag's "x 2" counts, the Berry Pouch's "No06") are 8x16
cells, 32 to a row, 13 rows tall.

Stdlib only: the font PNG is a 2-bit paletted image with no interlace.
"""

import re
import struct
import sys
import zlib

# font: (cell width, cell height, glyph height (gGlyphInfo.height), the width
# table's name in src/text.c, the name in the header line)
FONTS = {
    "normal": (16, 16, 14, "sFontNormalLatinGlyphWidths", "FONT_NORMAL"),
    "small": (8, 16, 13, "sFontSmallLatinGlyphWidths", "FONT_SMALL"),
}
LAST_CODE = 0xFE  # 0xFF ends a string
JAPANESE_SECTION = "@ Hiragana"
# Extra symbols (charmap "NAME = F9 xx": glyph 0x100 + xx) given a code point
# here: the Easy Chat editor draws an empty word as seven {UNDERSCORE}s.
EXTRA_SYMBOLS = [(0x09, "_")]
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


def glyph_widths(text_c, table):
    """The font's glyph width table from src/text.c."""
    source = open(text_c, encoding="utf-8").read()
    match = re.search(table + r"\[\]\s*=\s*\{([^}]*)\}", source)
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


def main(decomp, font):
    cell_width, cell_height, glyph_height, table, name = FONTS[font]
    pixels = png_indices(decomp + "/graphics/fonts/latin_%s.png" % font)
    widths = glyph_widths(decomp + "/src/text.c", table)
    chars = charmap_chars(decomp + "/charmap.txt")
    cells_per_row = len(pixels[0]) // cell_width
    print("# FRLG %s Latin glyphs, made by src/games/frlg/assets/extract/extract_frlg_font_glyphs.py" % name)
    print("# from pret/pokefirered: <code> <width> <codepoint> <rows> (see the script)")
    extras = [(char, 0x100 + symbol) for symbol, char in EXTRA_SYMBOLS]
    for char, code in sorted(chars, key=lambda entry: entry[1]) + extras:
        if code > LAST_CODE and code < 0x100:
            continue
        top = (code // cells_per_row) * cell_height
        left = (code % cells_per_row) * cell_width
        width = widths[code]
        rows = [
            "".join(PIXEL_CHARS[pixels[top + y][left + x]] for x in range(width))
            for y in range(glyph_height)
        ]
        print("%02X %d %04X %s" % (code, width, ord(char), "/".join(rows)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "normal")
