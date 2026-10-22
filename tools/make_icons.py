"""Uygulama simgesini sprite'lardan üretir ve tüm platform boyutlarına dağıtır.

Çalıştırma:  python -I tools/make_icons.py
Çıktı: iOS AppIcon seti (alfa kanalsız), Android mipmap'leri, web simgeleri, Play Store 512 (store/play_icon_512.png).
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"


def gradient(size):
    """Sıcak turuncudan koyu kızıla dikey geçiş + hafif ışık lekesi."""
    top, bot = (246, 178, 64), (184, 74, 38)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c
    glow = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse((size * 0.15, size * 0.02, size * 0.85, size * 0.72), fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    img.paste(Image.new("RGB", (size, size), (255, 226, 150)), (0, 0), glow)
    return img


def master(size=1024):
    bg = gradient(size).convert("RGBA")
    usta = Image.open(SPR / "usta_normal.png").convert("RGBA")
    head = usta.crop((134, 66, 506, 560))  # baş ve gövde üstü
    k = size * 0.74 / head.height
    head = head.resize((round(head.width * k), round(head.height * k)), Image.LANCZOS)
    bg.alpha_composite(head, ((size - head.width) // 2, round(size * 0.02)))
    durum = Image.open(SPR / "durum.png").convert("RGBA")
    box = durum.getbbox()
    durum = durum.crop(box)
    k = size * 0.74 / durum.width
    durum = durum.resize((round(durum.width * k), round(durum.height * k)), Image.LANCZOS)
    # dürümün altına yumuşak gölge
    sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((size * 0.14, size * 0.80, size * 0.86, size * 0.93), fill=(60, 20, 8, 120))
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.02)))
    bg.alpha_composite(durum, ((size - durum.width) // 2, round(size * 0.97 - durum.height)))
    return bg.convert("RGB")


def save(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)


def main():
    m = master()
    # iOS: Contents.json'daki her girdinin boyutu = size × scale
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if ios.exists():
        meta = json.loads((ios / "Contents.json").read_text(encoding="utf-8"))
        for e in meta["images"]:
            px = round(float(e["size"].split("x")[0]) * int(e["scale"].rstrip("x")))
            save(m, ios / e["filename"], px)
    # Android
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(m, ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{folder}" / "ic_launcher.png", px)
    # Web
    for name, px in {"Icon-192.png": 192, "Icon-512.png": 512, "Icon-maskable-192.png": 192, "Icon-maskable-512.png": 512}.items():
        save(m, ROOT / "web" / "icons" / name, px)
    save(m, ROOT / "web" / "favicon.png", 32)
    # Play Store
    save(m, ROOT / "store" / "play_icon_512.png", 512)
    m.save(ROOT / "store" / "icon_1024.png", optimize=True)
    print("tamam")


if __name__ == "__main__":
    main()
