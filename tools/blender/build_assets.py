"""Komut satırı girişi.

  blender -b -P tools/blender/build_assets.py -- <çıktı_klasörü> [items|chars|bg|all] [alt_küme]

Örnek:
  blender -b -P tools/blender/build_assets.py -- assets/sprites items
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import importlib

import bl_lib  # noqa: F401


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[0] if argv else "assets/sprites")
    what = argv[1] if len(argv) > 1 else "all"
    sub = argv[2] if len(argv) > 2 else None
    os.makedirs(out, exist_ok=True)

    if what in ("items", "all"):
        items = importlib.import_module("items")
        if sub:
            getattr(items, f"build_{sub}")(out)
        else:
            items.build_all(out)
    if what in ("items2", "all"):
        items2 = importlib.import_module("items2")
        if sub:
            getattr(items2, f"build_{sub}")(out)
        else:
            items2.build_all(out)
    if what in ("chars", "all"):
        chars = importlib.import_module("chars")
        chars.build_all(out) if not sub else chars.build_one(out, sub)
    if what in ("bg", "all"):
        bg = importlib.import_module("bg")
        bg.build_theme(out, sub) if sub else bg.build_all(out)
    if what == "icon":
        importlib.import_module("icon").build_icon(out)
    if what in ("decor", "all"):
        decor = importlib.import_module("decor")
        decor.build_all(out) if not sub else decor.build_one(out, sub)


main()
