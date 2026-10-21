"""Sprite klasörünü tek bir kontrol resmine dizer (açık/koyu zemin üstünde). Kullanım: contact_sheet.py DIR OUT [HÜCRE]"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

d, out = Path(sys.argv[1]), sys.argv[2]
cell = int(sys.argv[3]) if len(sys.argv) > 3 else 320
files = sorted(p for p in d.glob("*.png") if not p.name.startswith("_"))
cols = 4
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (96, 140, 120))
dr = ImageDraw.Draw(sheet)
for i, p in enumerate(files):
    im = Image.open(p).convert("RGBA")
    im.thumbnail((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * (cell + 18)
    sheet.paste(im, (x + (cell - im.width) // 2, y + 16), im)
    dr.text((x + 4, y + 2), p.name, fill=(255, 255, 255))
sheet.save(out)
print(len(files), "dosya ->", out)
