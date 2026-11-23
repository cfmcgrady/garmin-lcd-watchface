#!/usr/bin/env python3
"""Build compact, monochrome BMFont resources at the watch's native resolution."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "resources/fonts"
FONT_DIR.mkdir(parents=True, exist_ok=True)
TIME_HEIGHT = 66
TIME_CELL = 44
TIME_INK_WIDTH = 38
COLON_ADVANCE = 16


def lcd_glyph(char):
    if char == ":":
        mask = Image.new("L", (COLON_ADVANCE, TIME_HEIGHT))
        draw = ImageDraw.Draw(mask)
        draw.rectangle((4, 19, 11, 26), fill=255)
        draw.rectangle((4, 41, 11, 48), fill=255)
        return mask, COLON_ADVANCE

    alpha = Image.new("L", (70, TIME_HEIGHT))
    font = ImageFont.truetype(str(ROOT / "resources/font-source/DSEG7Classic-Bold.ttf"), 65)
    ImageDraw.Draw(alpha).text((0, 1), char, font=font, fill=255)
    bounds = alpha.getbbox()
    width = TIME_INK_WIDTH
    if char == "1":
        zero_bounds = font.getmask("0").getbbox()
        width = round(TIME_INK_WIDTH * (bounds[2] - bounds[0]) / (zero_bounds[2] - zero_bounds[0]))
    alpha = alpha.crop((bounds[0], 0, bounds[2], TIME_HEIGHT))
    alpha = alpha.resize((width, TIME_HEIGHT), Image.Resampling.LANCZOS)
    alpha = alpha.point(lambda p: 255 if p >= 100 else 0)
    # Keep the narrow strokes of 1, but give every digit the same advance.
    cell = Image.new("L", (TIME_CELL, TIME_HEIGHT))
    cell.paste(alpha, ((TIME_CELL - width) // 2, 0))
    return cell, TIME_CELL


def font_glyphs(path, size, chars, xscale=1.0, weight=None):
    font = ImageFont.truetype(str(path), size)
    if weight is not None:
        font.set_variation_by_axes([weight])
    ascent, descent = font.getmetrics()
    height = ascent + descent
    result = {}
    for char in chars:
        advance = max(2, round(font.getlength(char)))
        mask = Image.new("L", (advance + 2, height))
        ImageDraw.Draw(mask).text((0, ascent), char, font=font, fill=255, anchor="ls")
        if xscale != 1:
            advance = max(2, round(advance * xscale))
            mask = mask.resize((advance + 2, height), Image.Resampling.LANCZOS)
        mask = mask.point(lambda p: 255 if p >= 100 else 0)
        result[char] = (mask, advance)
    return result, height, ascent


def write_font(name, glyphs, line_height, base):
    atlas = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    x, y, row_height = 1, 1, 0
    records = []
    for char, (mask, advance) in glyphs.items():
        w, h = mask.size
        if x + w + 1 > atlas.width:
            x, y, row_height = 1, y + row_height + 1, 0
        if y + h >= atlas.height:
            raise RuntimeError("Font atlas overflow")
        white = Image.new("RGBA", mask.size, (255, 255, 255, 0))
        white.putalpha(mask)
        atlas.paste(white, (x, y))
        records.append(f'char id={ord(char)} x={x} y={y} width={w} height={h} xoffset=0 yoffset=0 xadvance={advance} page=0 chnl=15')
        x += w + 1
        row_height = max(row_height, h)
    atlas = atlas.crop((0, 0, 512, y + row_height + 1))
    atlas.save(FONT_DIR / f"{name}.png")
    contents = [
        f'info face="{name}" size={line_height} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
        f'common lineHeight={line_height} base={base} scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0',
        f'page id=0 file="{name}.png"', f'chars count={len(records)}', *records,
        'kernings count=0',
    ]
    (FONT_DIR / f"{name}.fnt").write_text("\n".join(contents) + "\n")


def main():
    write_font("lcd", {c: lcd_glyph(c) for c in "0123456789:"}, TIME_HEIGHT, TIME_HEIGHT)
    noto = Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")
    dejavu = Path("/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf")
    chars = "0123456789月日周一二三四五六 "
    glyphs, height, base = font_glyphs(noto, 17, chars)
    # Use one common crop for digits and CJK to preserve their shared baseline.
    # Derive it from the full date alphabet, avoiding truncated week/day strokes.
    bounds = [m.getbbox() for m, _ in glyphs.values() if m.getbbox()]
    top = min(b[1] for b in bounds)
    bottom = max(b[3] for b in bounds)
    date_height = bottom - top + 2
    glyphs = {c: (m.crop((0, top, m.width, bottom + 2)), a) for c, (m, a) in glyphs.items()}
    write_font("date", glyphs, date_height, base - top)
    latin = ROOT / "resources/font-source/RobotoCondensed.ttf"
    for name, size, chars in [
        ("hr", 26, "0123456789-"),
        ("small", 11, "HR ·1BPM-"),
        ("battery", 18, "0123456789%"),
    ]:
        # Use a real condensed family, preserving its designed stroke widths.
        glyphs, height, base = font_glyphs(latin, size, dict.fromkeys(chars), weight=700)
        boxes = [m.getbbox() for m, _ in glyphs.values() if m.getbbox()]
        top = min(b[1] for b in boxes)
        bottom = max(b[3] for b in boxes)
        glyphs = {c: (m.crop((0, top, m.width, bottom + 2)), a) for c, (m, a) in glyphs.items()}
        write_font(name, glyphs, bottom - top + 2, base - top)
    icon = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw.ellipse((0, 0, 39, 39), fill="#000000", outline="#AAFF00", width=2)
    draw.text((20, 8), "LCD", font=ImageFont.truetype(str(dejavu), 11), anchor="mt", fill="white")
    draw.line([(9, 28), (15, 24), (19, 29), (25, 23), (31, 26)], fill="#AAFF00", width=2)
    icon.save(ROOT / "resources/drawables/launcher.png")
    print("Generated native-resolution LCD digits and four small subset fonts.")


if __name__ == "__main__":
    main()
