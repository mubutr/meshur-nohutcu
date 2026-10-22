"""Uygulama simgesini sprite'lardan üretir ve tüm platform boyutlarına dağıtır.

Çalıştırma:  python -I tools/make_icons.py
Çıktı: iOS AppIcon seti (alfa kanalsız), Android mipmap'leri, web simgeleri, Play Store 512 (store/play_icon_512.png).
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"


def background(size):
    """Sıcak ışıklı zemin: üst ortada altın, kenarlara doğru koyu kızıl; hafif güneş ışınları."""
    import math

    cx, cy = size * 0.5, size * 0.42
    inner, outer = (255, 206, 96), (178, 62, 34)
    img = Image.new("RGB", (size, size))
    px = img.load()
    rmax = math.hypot(size * 0.62, size * 0.7)
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / rmax)
            t = t * t * (3 - 2 * t)
            px[x, y] = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    rays = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(rays)
    n = 14
    for k in range(n):
        a0 = math.tau * k / n
        a1 = a0 + math.tau / n * 0.5
        d.polygon([(cx, cy), (cx + math.cos(a0) * size * 1.2, cy + math.sin(a0) * size * 1.2), (cx + math.cos(a1) * size * 1.2, cy + math.sin(a1) * size * 1.2)], fill=34)
    rays = rays.filter(ImageFilter.GaussianBlur(size * 0.006))
    img.paste(Image.new("RGB", (size, size), (255, 236, 170)), (0, 0), rays)
    return img


def steam(canvas, x0, y0, size):
    """Açık uçtan yükselen yumuşak buhar: büyüyüp sönen beyaz lekeler."""
    import math

    mask = Image.new("L", canvas.size, 0)
    d = ImageDraw.Draw(mask)
    for k, (dx, h, amp, phase) in enumerate(((-0.055, 0.30, 0.03, 0.0), (0.015, 0.40, 0.035, 1.4), (0.085, 0.28, 0.028, 2.6))):
        n = 34
        for i in range(n):
            t = i / (n - 1)
            x = x0 + size * (dx + amp * math.sin(t * math.pi * 2.0 + phase))
            y = y0 - size * h * t
            r = size * (0.011 + 0.014 * t)
            a = round(255 * math.sin(min(1.0, t * 1.1) * math.pi) ** 0.6)
            d.ellipse((x - r, y - r, x + r, y + r), fill=max(0, a))
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.006))
    layer = Image.new("RGBA", canvas.size, (255, 250, 238, 0))
    layer.putalpha(mask)
    canvas.alpha_composite(layer)


def master(size=1024, transparent=False):
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0)) if transparent else background(size).convert("RGBA")
    src = Image.open(ROOT / "tools" / "icon_src" / "icon_durum_temiz.png").convert("RGBA")
    src = src.crop(src.getchannel("A").getbbox())
    k = size * 0.78 / src.width
    dur = src.resize((round(src.width * k), round(src.height * k)), Image.LANCZOS)
    ox = round((size - dur.width) / 2 - size * 0.01)
    oy = round(size * 0.585 - dur.height / 2)
    # kendi yumuşak gölgemiz (sağ alta düşer)
    sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    sa = dur.getchannel("A").point(lambda v: 150 if v > 128 else 0)
    shadow = Image.new("RGBA", dur.size, (70, 22, 8, 0))
    shadow.putalpha(sa)
    sh.alpha_composite(shadow, (ox + round(size * 0.035), oy + round(size * 0.05)))
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.022)))
    bg.alpha_composite(dur, (ox, oy))
    # buhar: dolgunun olduğu sağ üst uçtan
    steam(bg, ox + dur.width * 0.80, oy + dur.height * 0.42, size)
    return bg if transparent else bg.convert("RGB")


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
    # Android uyarlanabilir simge (8.0+): zemin + güvenli bölgeye sığan ön plan (432 px = 108 dp x4)
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    save(background(432), res / "mipmap-xxxhdpi" / "ic_launcher_background.png", 432)
    fg = master(1024, transparent=True)
    fg = fg.crop(fg.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox())
    k = 292 / max(fg.size)
    fg = fg.resize((round(fg.width * k), round(fg.height * k)), Image.LANCZOS)
    canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    canvas.alpha_composite(fg, ((432 - fg.width) // 2, (432 - fg.height) // 2))
    (res / "mipmap-xxxhdpi").mkdir(parents=True, exist_ok=True)
    canvas.save(res / "mipmap-xxxhdpi" / "ic_launcher_foreground.png", optimize=True)
    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""",
        encoding="utf-8",
    )
    # Android (eski cihazlar için düz simge)
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
