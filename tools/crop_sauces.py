"""Sos şişesi sprite'larını yalnız şişeye kırpar ve dört şişeyi aynı tuvalde, tabanı hizalı bırakır.

Blender çıktısında şişe 512x512 karenin küçük bir bölümüydü (boşluk + sola düşen gölge); etiketten kopuk görünüyordu.
Çalıştırma:  python -I tools/crop_sauces.py   (kaynaklar tools/icon_src yerine assets/sprites içindedir; ilk çalıştırmada
yedek tools/data_backup/sise_orijinal/ altına alınır)
"""
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"
BACKUP = ROOT / "tools" / "data_backup" / "sise_orijinal"
NAMES = ["sos_sise", "ketcap_sise", "mayonez_sise", "nar_sise"]
PAD = 4


def bottle_box(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= 200 else 0)
    return a.getbbox()


def main():
    BACKUP.mkdir(parents=True, exist_ok=True)
    crops = []
    for n in NAMES:
        src = SPR / f"{n}.png"
        bak = BACKUP / f"{n}.png"
        if not bak.exists():
            shutil.copy(src, bak)
        im = Image.open(bak).convert("RGBA")
        box = bottle_box(im)
        crops.append(im.crop((box[0] - PAD, box[1] - PAD, box[2] + PAD, box[3] + PAD)))
    w = max(c.width for c in crops)
    h = max(c.height for c in crops)
    for n, c in zip(NAMES, crops):
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        canvas.alpha_composite(c, ((w - c.width) // 2, h - c.height))  # tabanlar hizalı
        canvas.save(SPR / f"{n}.png", optimize=True)
    print("tuval", w, h)


main()
