#!/usr/bin/env python3
"""tools/fonts/build_fonts.py — JIOH-63: builds the three bitmap faces.

Every face comes from the one hand-drawn glyph set in resources/fonts/glyphs_5x9.txt, so the
game has one letterform at three sizes and nothing else:

  jioh_body_6px     document text, proportional, 1x (caps 7px, 10px line)
  jioh_display_10px headings, signage, the wall planner: the body glyphs at 2x
  jioh_terminal_8px the CRT: strict monospace, 6x10 cell

Writes PNG atlases (white ink, alpha 0 or 255 only) and BMFont text metrics
into resources/fonts/. Run from the project root:

  python3 tools/fonts/build_fonts.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "resources/fonts/glyphs_5x9.txt"
OUT = ROOT / "resources/fonts"
ROWS = 9
BASE = 7


def read_glyphs():
    glyphs, cur, rows = {}, None, []
    for line in SRC.read_text().splitlines():
        if line.startswith("//") or not line.strip():
            continue
        if line.startswith("= "):
            parts = line[2:].split(" ")
            name = parts[0]
            ch = " " if name == "space" else name
            width = int(parts[1]) if len(parts) > 1 else None
            cur = (ch, width)
            rows = []
            glyphs[ch] = (width, rows)
            continue
        rows.append(line.strip())
    for ch, (_, rows) in glyphs.items():
        assert len(rows) == ROWS and all(len(r) == 5 for r in rows), f"glyph {ch!r} malformed"
    return glyphs


def build(name, glyphs, scale, mono_cell=None):
    cells = []
    for ch, (fixed, rows) in glyphs.items():
        cols = [c for c in range(5) if any(r[c] == "#" for r in rows)]
        if mono_cell:
            left, width = 0, 5
            advance = mono_cell
        elif cols:
            left, width = cols[0], cols[-1] - cols[0] + 1
            advance = width + 1
        else:
            left, width = 0, 0
            advance = fixed or 3
        if fixed is not None and not mono_cell:
            advance = fixed
        cells.append((ch, rows, left, width, advance))
    pad = 1
    atlas_w = 256 if scale == 1 else 512
    x = y = pad
    placed = []
    h = ROWS * scale
    for ch, rows, left, width, advance in cells:
        w = width * scale
        if x + w + pad > atlas_w:
            x, y = pad, y + h + pad
        placed.append((ch, rows, left, width, advance, x, y))
        x += w + pad
    atlas_h = 1
    while atlas_h < y + h + pad:
        atlas_h *= 2
    img = Image.new("RGBA", (atlas_w, atlas_h), (255, 255, 255, 0))
    px = img.load()
    lines = []
    for ch, rows, left, width, advance, gx, gy in placed:
        for r in range(ROWS):
            for c in range(width):
                if rows[r][left + c] == "#":
                    for sy in range(scale):
                        for sx in range(scale):
                            px[gx + c * scale + sx, gy + r * scale + sy] = (255, 255, 255, 255)
        xoff = left * scale if mono_cell else 0
        lines.append(
            f"char id={ord(ch)} x={gx} y={gy} width={width * scale} height={h if width else 0} "
            f"xoffset={xoff} yoffset=0 xadvance={advance * scale} page=0 chnl=15")
    img.save(OUT / f"{name}.png")
    line_h = (ROWS + 1) * scale
    head = [
        f'info face="{name}" size={line_h} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line_h} base={BASE * scale} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        f'page id=0 file="{name}.png"',
        f"chars count={len(lines)}",
    ]
    (OUT / f"{name}.fnt").write_text("\n".join(head + lines) + "\n")
    print(f"{name}: {len(lines)} glyphs, {atlas_w}x{atlas_h}, line {line_h}px")


if __name__ == "__main__":
    g = read_glyphs()
    OUT.mkdir(parents=True, exist_ok=True)
    build("jioh_body_6px", g, 1)
    build("jioh_display_10px", g, 2)
    build("jioh_terminal_8px", g, 1, mono_cell=6)
