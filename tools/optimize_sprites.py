"""assets/sprites içindeki PNG'leri 256 renge indirir (alfa korunur, Floyd-Steinberg); boyut ~10× küçülür.

Blender çıktıları üretildikten SONRA çalıştırılır:  python -I tools/optimize_sprites.py [klasör]
"""
import io
import sys
from pathlib import Path

from PIL import Image

d = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/sprites")
before = after = 0
for p in sorted(d.glob("*.png")):
    raw = p.read_bytes()
    before += len(raw)
    if p.name.startswith("bg_"):  # büyük renk geçişli arka planlar bantlanmasın: kayıpsız kalır
        after += len(raw)
        continue
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    q = im.quantize(colors=256, method=Image.FASTOCTREE, dither=Image.FLOYDSTEINBERG)
    buf = io.BytesIO()
    q.save(buf, "PNG", optimize=True)
    data = buf.getvalue()
    if len(data) < len(raw):
        p.write_bytes(data)
        after += len(data)
    else:
        after += len(raw)
print(f"{before / 1e6:.1f} MB -> {after / 1e6:.1f} MB")
