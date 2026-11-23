#!/usr/bin/env python3
"""Check the shipped BMFont at the watch face's actual time position."""
import re
import shlex
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "resources/fonts/lcd.fnt"
DIGITS = "0123456789:"


@dataclass
class Glyph:
    mask: Image.Image
    left: int
    top: int
    advance: int


def read_glyphs():
    lines = FONT.read_text(encoding="utf-8").splitlines()
    page = next(line for line in lines if line.startswith("page "))
    page_name = dict(token.split("=", 1) for token in shlex.split(page)[1:])["file"]
    with Image.open(FONT.with_name(page_name)) as atlas:
        alpha = atlas.convert("RGBA").getchannel("A")
    glyphs = {}
    for line in lines:
        if not line.startswith("char "):
            continue
        fields = dict(token.split("=") for token in line.split()[1:])
        record = {key: int(value) for key, value in fields.items()}
        char = chr(record["id"])
        x, y = record["x"], record["y"]
        mask = alpha.crop((x, y, x + record["width"], y + record["height"]))
        glyph = Glyph(mask, record["xoffset"], record["yoffset"], record["xadvance"])
        if char in DIGITS:
            expected_width = 16 if char == ":" else 44
            if glyph.advance != expected_width or mask.height != 66 or not mask.getbbox():
                raise ValueError(f"{char!r} must have visible ink in its {expected_width}×66 cell")
            glyphs[char] = glyph
    if set(glyphs) != set(DIGITS) or "kernings count=0" not in lines:
        raise ValueError("Expected all ten digits and a colon with fixed, unkerned advances")
    return glyphs


def main():
    source = (ROOT / "source/LcdFaceView.mc").read_text(encoding="utf-8")
    position = re.search(
        r"drawText\(\s*(\d+)\s*,\s*(\d+)\s*,\s*_timeFont\s*,\s*timeText\(\)\s*,"
        r"\s*Graphics\.TEXT_JUSTIFY_CENTER\s*\)", source
    )
    if not position:
        raise ValueError("Could not locate the centered time drawing call")
    center, top = map(int, position.groups())
    glyphs = read_glyphs()
    allowed = Image.frombytes("L", (240, 240), bytes(
        255 if 65 <= y < 145 and (x - 119.5) ** 2 + (y - 119.5) ** 2 <= 120 ** 2 else 0
        for y in range(240) for x in range(240)
    ))
    min_gap = min_ones = 240
    for minute in range(24 * 60):
        time = f"{minute // 60:02d}:{minute % 60:02d}"
        width = sum(glyphs[char].advance for char in time)
        if width != 192:
            raise ValueError(f"{time} advances by {width} pixels")
        pen = center - width // 2
        frame = Image.new("L", allowed.size)
        previous_right = None
        previous_char = None
        for char in time:
            glyph = glyphs[char]
            x, y = pen + glyph.left, top + glyph.top
            left, upper, right, bottom = glyph.mask.getbbox()
            if x + left < 0 or y + upper < 0 or x + right > 240 or y + bottom > 240:
                raise ValueError(f"{time} extends off the display")
            if previous_right is not None:
                gap = x + left - previous_right
                if gap < 0:
                    raise ValueError(f"{time} contains overlapping glyphs")
                if char != ":" and previous_char != ":":
                    min_gap = min(min_gap, gap)
                    if gap < 6:
                        raise ValueError(f"{time} has only {gap} clear pixels between digits")
                if char == previous_char == "1":
                    min_ones = min(min_ones, gap)
                    if gap < 30:
                        raise ValueError(f"{time} has only {gap} clear pixels between its ones")
            frame.paste(glyph.mask, (x, y))
            pen += glyph.advance
            previous_right = x + right
            previous_char = char
        if ImageChops.subtract(frame, allowed).getbbox():
            raise ValueError(f"{time} has lit pixels outside the circular time area")
    print(f"1,440 times checked; width 192 px; minimum digit gap {min_gap} px; "
          f"minimum 11 gap {min_ones} px.")


if __name__ == "__main__":
    main()
