"""Karakterler: stilize, düşük-poligon TAM BOY (baştan ayağa) müşteri/usta; 3 ifade (normal, mutlu, kızgın).

Oyunda tezgâh belden aşağısını örter; bacaklar yine de modellenir ki gövde yüzmesin."""
import math

import bpy

import bl_lib as L

RES = (640, 960)
EXPR = ("normal", "mutlu", "kizgin")

# kimlik -> parametreler
CHARS = {
    "usta": dict(skin=(0.80, 0.58, 0.43), shirt=(0.84, 0.83, 0.78), apron=(0.16, 0.30, 0.48), hat=("kasket", (0.86, 0.85, 0.8)),
                 mustache=(0.05, 0.04, 0.03), brow=(0.05, 0.04, 0.03), size=1.0, belly=1.08),
    # ---- müşteri kadrosu: 10 kadın + 10 erkek (ad = sprite öneki)
    # kadınlar (yaşlı)
    "fatma": dict(skin=(0.84, 0.64, 0.50), shirt=(0.55, 0.20, 0.25), scarf=(0.90, 0.85, 0.70), skirt=(0.20, 0.20, 0.30), earrings=True,
                  brow=(0.55, 0.55, 0.55), size=0.93, belly=1.10, lashes=True),
    "hattuc": dict(skin=(0.74, 0.52, 0.40), shirt=(0.25, 0.40, 0.55), scarf=(0.15, 0.15, 0.25), skirt=(0.28, 0.2, 0.15), glasses=True,
                   brow=(0.5, 0.5, 0.5), size=0.92, belly=1.05),
    "zennup": dict(skin=(0.80, 0.60, 0.46), shirt=(0.35, 0.50, 0.25), scarf=(0.85, 0.55, 0.15), skirt=(0.30, 0.25, 0.20),
                   brow=(0.45, 0.4, 0.35), size=0.90, belly=1.18),
    "sehriban": dict(skin=(0.88, 0.70, 0.56), shirt=(0.60, 0.45, 0.20), scarf=(0.50, 0.10, 0.15), skirt=(0.25, 0.25, 0.30), vest=(0.25, 0.25, 0.30),
                     earrings=True, brow=(0.6, 0.6, 0.6), size=0.94, belly=1.0),
    # kadınlar (genç)
    "emine": dict(skin=(0.86, 0.66, 0.52), shirt=(0.90, 0.55, 0.65), scarf=(0.95, 0.95, 0.95), skirt=(0.30, 0.30, 0.45), brow=(0.12, 0.08, 0.05),
                  size=0.92, belly=0.9, lashes=True),
    "hayce": dict(skin=(0.78, 0.56, 0.42), shirt=(0.20, 0.60, 0.60), hair=(0.10, 0.06, 0.04), hairband=(0.8, 0.12, 0.12), skirt=(0.15, 0.2, 0.30),
                  brow=(0.08, 0.05, 0.03), size=0.93, belly=0.92, lashes=True),
    "ayyus": dict(skin=(0.90, 0.72, 0.58), shirt=(0.95, 0.80, 0.30), hair=(0.45, 0.25, 0.10), earrings=True, skirt=(0.50, 0.20, 0.20),
                  brow=(0.3, 0.18, 0.08), size=0.94, belly=0.88, lashes=True),
    "yumma": dict(skin=(0.72, 0.50, 0.38), shirt=(0.55, 0.30, 0.70), scarf=(0.90, 0.40, 0.60), skirt=(0.25, 0.15, 0.30), brow=(0.1, 0.06, 0.04),
                  size=0.90, belly=0.95, lashes=True),
    "lutfiye": dict(skin=(0.84, 0.64, 0.50), shirt=(0.85, 0.25, 0.20), hair=(0.20, 0.10, 0.06), hairband=(0.2, 0.4, 0.8), skirt=(0.18, 0.18, 0.22),
                    brow=(0.15, 0.08, 0.05), size=0.95, belly=0.9, lashes=True),
    "sakire": dict(skin=(0.80, 0.60, 0.47), shirt=(0.15, 0.35, 0.20), scarf=(0.95, 0.85, 0.40), skirt=(0.35, 0.25, 0.15), glasses=True,
                   brow=(0.1, 0.07, 0.05), size=0.93, belly=0.98, lashes=True),
    # erkekler (yaşlı: ammi)
    "maamed": dict(skin=(0.76, 0.54, 0.40), shirt=(0.78, 0.74, 0.62), vest=(0.30, 0.25, 0.20), hat=("takke", (0.95, 0.94, 0.9)), pants=(0.25, 0.25, 0.28),
                   mustache=(0.62, 0.62, 0.60), brow=(0.7, 0.7, 0.68), size=0.97, belly=1.15),
    "huseyin": dict(skin=(0.70, 0.50, 0.38), shirt=(0.25, 0.35, 0.50), vest=(0.15, 0.15, 0.18), hat=("kasket", (0.30, 0.30, 0.32)), glasses=True,
                    pants=(0.18, 0.18, 0.22), mustache=(0.30, 0.30, 0.30), brow=(0.4, 0.4, 0.4), size=1.0, belly=1.20),
    "okkes": dict(skin=(0.82, 0.62, 0.48), shirt=(0.50, 0.55, 0.40), hat=("kasket", (0.55, 0.40, 0.25)), beard_long=(0.82, 0.82, 0.80), pants=(0.30, 0.26, 0.2),
                  brow=(0.75, 0.75, 0.75), size=0.95, belly=1.10),
    "cimaali": dict(skin=(0.66, 0.46, 0.34), shirt=(0.60, 0.25, 0.20), vest=(0.20, 0.20, 0.25), hat=("takke", (0.85, 0.80, 0.70)), pants=(0.22, 0.2, 0.18),
                    mustache=(0.10, 0.08, 0.06), brow=(0.1, 0.08, 0.06), size=1.0, belly=1.25),
    # erkekler (genç: Rafık)
    "mustafa": dict(skin=(0.84, 0.64, 0.50), shirt=(0.15, 0.15, 0.20), hair=(0.05, 0.04, 0.04), beard=True, chain=True, pants=(0.12, 0.12, 0.16),
                    brow=(0.05, 0.04, 0.04), size=1.0, belly=0.92),
    "ahmet": dict(skin=(0.78, 0.58, 0.44), shirt=(0.20, 0.50, 0.70), hair=(0.30, 0.18, 0.10), mustache=(0.20, 0.12, 0.08), pants=(0.15, 0.2, 0.3),
                  brow=(0.2, 0.12, 0.07), size=1.0, belly=0.95),
    "ali": dict(skin=(0.86, 0.68, 0.54), shirt=(0.85, 0.85, 0.85), vest=(0.30, 0.10, 0.15), hair=(0.10, 0.08, 0.06), glasses=True, pants=(0.12, 0.12, 0.18),
                brow=(0.08, 0.06, 0.05), size=1.0, belly=0.90),
    "mehmetali": dict(skin=(0.72, 0.52, 0.40), shirt=(0.90, 0.60, 0.15), hat=("bere", (0.15, 0.40, 0.20)), hair=(0.05, 0.04, 0.04), pants=(0.2, 0.2, 0.24),
                      brow=(0.05, 0.04, 0.04), size=1.0, belly=0.95),
    "hogges": dict(skin=(0.82, 0.62, 0.48), shirt=(0.35, 0.35, 0.40), hair=(0.25, 0.15, 0.10), beard=True, pants=(0.18, 0.15, 0.12),
                   brow=(0.2, 0.12, 0.08), size=1.05, belly=1.0),
    "memik": dict(skin=(0.88, 0.70, 0.56), shirt=(0.30, 0.60, 0.35), hair=(0.55, 0.35, 0.15), pants=(0.25, 0.22, 0.2), earrings=True,
                  brow=(0.4, 0.25, 0.1), size=0.96, belly=0.85),
    # ---- hikâye/özel karakterler
    "dayi": dict(skin=(0.70, 0.50, 0.37), shirt=(0.36, 0.30, 0.24), patches=True, hat=("kasket", (0.28, 0.25, 0.22)),
                 beard_long=(0.86, 0.86, 0.84), brow=(0.8, 0.8, 0.78), size=0.95, belly=1.05),
    "nine": dict(skin=(0.80, 0.60, 0.48), shirt=(0.30, 0.20, 0.38), scarf=(0.55, 0.30, 0.58), glasses=True, brow=(0.75, 0.75, 0.75),
                 size=0.88, belly=1.0),
    "maskeli": dict(skin=(0.78, 0.58, 0.44), shirt=(0.13, 0.13, 0.16), hair=(0.03, 0.03, 0.04), mask=(0.05, 0.05, 0.06),
                    brow=(0.03, 0.03, 0.03), size=1.0, belly=0.95),
    "itfaiyeci": dict(skin=(0.82, 0.60, 0.45), shirt=(0.70, 0.10, 0.08), helmet=(0.95, 0.78, 0.12), mustache=(0.22, 0.12, 0.06),
                      brow=(0.2, 0.1, 0.05), size=1.05, belly=1.1),
    "rakip": dict(skin=(0.84, 0.64, 0.5), shirt=(0.10, 0.45, 0.35), hair=(0.05, 0.04, 0.04), chain=True, brow=(0.05, 0.04, 0.04),
                  size=1.0, belly=0.9),
    "yatirimci": dict(skin=(0.70, 0.50, 0.37), shirt=(0.10, 0.12, 0.22), suit=True, beard_long=(0.88, 0.88, 0.86),
                      hat=("kasket", (0.1, 0.1, 0.12)), brow=(0.8, 0.8, 0.78), size=1.0, belly=1.1),
    "cirak": dict(skin=(0.84, 0.64, 0.5), shirt=(0.85, 0.80, 0.70), apron=(0.55, 0.30, 0.12), hair=(0.08, 0.06, 0.05),
                  brow=(0.08, 0.06, 0.05), size=0.9, belly=0.9),
    "antikaci": dict(skin=(0.80, 0.60, 0.46), shirt=(0.45, 0.28, 0.14), vest=(0.25, 0.12, 0.30), glasses=True, chain=True,
                     hat=("kasket", (0.38, 0.14, 0.40)), mustache=(0.35, 0.28, 0.22), brow=(0.3, 0.24, 0.2), size=1.0, belly=1.05),
    # ---- v3: bonus müşteri ve kurye
    "gezgin": dict(skin=(0.88, 0.70, 0.56), shirt=(0.22, 0.42, 0.30), vest=(0.62, 0.44, 0.2), glasses=True, camera=True, backpack=True,
                   hat=("gezgin", (0.78, 0.66, 0.40)), brow=(0.25, 0.18, 0.1), size=1.0, belly=1.0, pants=(0.55, 0.45, 0.28)),
    "kurye": dict(skin=(0.82, 0.62, 0.47), shirt=(0.10, 0.10, 0.13), stripe=True, helmet=(0.12, 0.42, 0.85), mustache=(0.15, 0.1, 0.06),
                  brow=(0.1, 0.07, 0.05), size=1.0, belly=0.95, bag=True, pants=(0.12, 0.12, 0.16)),
}

# pantolon (varsayılan) ve etek: gövdenin altı
PANTS = {"usta": (0.20, 0.22, 0.30), "dayi": (0.30, 0.26, 0.2),
         "maskeli": (0.10, 0.10, 0.12), "itfaiyeci": (0.12, 0.14, 0.30), "rakip": (0.10, 0.12, 0.16), "yatirimci": (0.10, 0.12, 0.22),
         "cirak": (0.25, 0.22, 0.20), "antikaci": (0.22, 0.14, 0.10)}
SKIRT = {"nine": (0.30, 0.20, 0.38)}


def _mats(p):
    skin = L.make_mat("Ten", p["skin"], rough=0.55, sss=0.35)
    cloth = L.make_mat("Giysi", p["shirt"], rough=0.85, bump=("fine", 90, 0.12))
    return skin, cloth


def _curve(name, pts, mat, bevel=0.02):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = bevel
    cu.bevel_resolution = 4
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, (x, y, z) in enumerate(pts):
        sp.points[i].co = (x, y, z, 1)
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def build_char(cid, expr):
    p = CHARS[cid]
    L.reset_scene()
    L.set_world((0.7, 0.72, 0.78), 0.5)
    L.setup_camera(elev_deg=8, dist=14, ortho_scale=4.0, target=(0, 0, 0.85))
    L.add_sun(rot_deg=(55, 0, -25), strength=2.4, color=(1, 0.94, 0.85))
    L.add_area((-3, -5, 4), size=5, energy=110, color=(1, 0.96, 0.92), look_at=(0, 0, 1.6))
    L.add_area((4, -3, 2), size=4, energy=50, color=(0.85, 0.92, 1), look_at=(0, 0, 1.4))
    sc = p["size"]
    skin, cloth = _mats(p)
    black = L.make_mat("Siyah", (0.02, 0.02, 0.02), rough=0.4)
    white = L.make_mat("Beyaz", (0.97, 0.97, 0.97), rough=0.3)

    # gövde (bel üstü) + omuzlar
    L.sphere((0, 0, 1.0), 0.62, (0.95 * p["belly"], 0.55 * p["belly"], 1.18), cloth, name="Govde")
    L.sphere((-0.52 * sc, 0, 1.55), 0.2, (1, 1, 1), cloth, name="OmuzL")
    L.sphere((0.52 * sc, 0, 1.55), 0.2, (1, 1, 1), cloth, name="OmuzR")
    # ----- alt gövde: kalça, bacaklar, ayakkabı (ya da etek)
    pants_col = p.get("pants", PANTS.get(cid, (0.2, 0.2, 0.25)))
    pants = L.make_mat("Pantolon", pants_col, rough=0.85, bump=("fine", 90, 0.12))
    shoes = L.make_mat("Ayakkabi", (0.07, 0.05, 0.04), rough=0.45)
    skirt_col = p.get("skirt") or SKIRT.get(cid)
    if skirt_col:
        sk = L.make_mat("Etek", skirt_col, rough=0.85, bump=("fine", 80, 0.14))
        L.sphere((0, 0, -0.1), 0.78, (0.95 * p["belly"], 0.62, 1.55), sk, name="Etek")
        for sgn in (-1, 1):
            L.sphere((0.2 * sgn, -0.12, -1.0), 0.17, (1, 1.7, 0.6), shoes, name="Ayakkabi")
    else:
        L.sphere((0, 0, 0.32), 0.55, (0.95 * p["belly"], 0.58, 0.8), pants, name="Kalca")
        L.cube((0, -0.01, 0.62), (1.05 * p["belly"], 0.7, 0.07), L.make_mat("Kemer", (0.06, 0.04, 0.03), rough=0.5), bevel=0.02, name="Kemer")
        for sgn in (-1, 1):
            L.cylinder((0.27 * sgn, 0, -0.35), 0.19, 1.25, pants, name="Bacak", verts=32)
            L.sphere((0.27 * sgn, -0.13, -0.98), 0.2, (1, 1.7, 0.62), shoes, name="Ayakkabi")

    # kollar
    for sgn in (-1, 1):
        L.cylinder((0.62 * sgn * sc, -0.05, 1.18), 0.15, 0.7, cloth, rot=(0, 0, 0), name="Kol", scale=(1, 1, 1))
        L.sphere((0.62 * sgn * sc, -0.12, 0.8), 0.14, (1, 1, 1), skin, name="El")
    if "apron" in p:
        ap = L.make_mat("Onluk", p["apron"], rough=0.85, bump=("fine", 60, 0.1))
        L.cube((0, -0.5, 0.95), (0.95, 0.06, 1.15), ap, bevel=0.05, name="Onluk")
        L.cube((0, -0.42, -0.1), (0.9, 0.06, 0.95), ap, bevel=0.05, name="OnlukAlt")
        L.sphere((0, -0.45, 1.55), 0.1, (2.4, 0.4, 0.4), ap, name="OnlukIp")
    if "vest" in p:
        vm = L.make_mat("Yelek", p["vest"], rough=0.9, bump=("fine", 70, 0.15))
        L.sphere((0, -0.06, 1.0), 0.64, (0.98 * p["belly"], 0.58 * p["belly"], 1.12), vm, name="Yelek")
        # yelek önü açık: gömlek şeridi
        L.cube((0, -0.52, 1.1), (0.16, 0.05, 0.9), cloth, name="Gomlek")

    # boyun + kafa
    L.cylinder((0, 0, 1.62), 0.17, 0.22, skin, name="Boyun")
    hz = 2.05
    L.sphere((0, 0, hz), 0.46, (1.0 * (1 + 0.04 * p["belly"]), 0.94, 1.04), skin, seg=48, rings=24, name="Kafa")
    for sgn in (-1, 1):
        L.sphere((0.45 * sgn, 0.02, hz - 0.02), 0.1, (0.55, 0.4, 1), skin, name="Kulak")
    L.sphere((0, -0.45, hz - 0.06), 0.085, (1, 1.1, 1), skin, name="Burun")

    # gözler
    for sgn in (-1, 1):
        ex = 0.17 * sgn
        L.sphere((ex, -0.40, hz + 0.05), 0.088, (1, 0.55, 1.15), white, seg=24, rings=12, name="Goz")
        L.sphere((ex + 0.01 * sgn * -1, -0.455, hz + 0.045), 0.046, (1, 0.5, 1), black, seg=16, rings=8, name="Gozbebegi")

    # kaş + ağız ifadeye göre
    brow = L.make_mat("Kas", p["brow"], rough=0.8)
    if expr == "mutlu":
        by, bt, mouth, cheek = 0.0, 0.0, [(-0.17, 0), (-0.1, -0.06), (0, -0.09), (0.1, -0.06), (0.17, 0)], True
        for sgn in (-1, 1):
            L.cube((0.17 * sgn, -0.4, hz + 0.2), (0.14, 0.03, 0.026), brow, rot=(0, 8 * sgn, 0), name="Kas")
    elif expr == "kizgin":
        mouth, cheek = [(-0.14, -0.1), (-0.07, -0.05), (0, -0.04), (0.07, -0.05), (0.14, -0.1)], False
        for sgn in (-1, 1):
            L.cube((0.16 * sgn, -0.4, hz + 0.19), (0.17, 0.035, 0.034), brow, rot=(0, -26 * sgn, 0), name="Kas")
    else:
        mouth, cheek = [(-0.13, -0.07), (-0.06, -0.075), (0, -0.075), (0.06, -0.075), (0.13, -0.07)], False
        for sgn in (-1, 1):
            L.cube((0.17 * sgn, -0.4, hz + 0.2), (0.15, 0.03, 0.028), brow, name="Kas")
    mm = L.make_mat("Agiz", (0.35, 0.08, 0.07), rough=0.5)
    # ağız yüzeye otursun: kafa küresinin önünde (y ≈ -0.43)
    _curve("Agiz", [(x, -0.425 + 0.0 * x, hz - 0.18 + z) for x, z in mouth], mm, bevel=0.016 if expr != "kizgin" else 0.02)
    if cheek:
        pink = L.make_mat("Yanak", (0.95, 0.5, 0.45), rough=0.6)
        for sgn in (-1, 1):
            L.sphere((0.27 * sgn, -0.37, hz - 0.1), 0.07, (1, 0.3, 0.7), pink, name="Yanak")

    # bıyık / sakal
    if "mustache" in p:
        mus = L.make_mat("Biyik", p["mustache"], rough=0.9, bump=("fine", 120, 0.3))
        for sgn in (-1, 1):
            L.sphere((0.1 * sgn, -0.435, hz - 0.14), 0.09, (1.5, 0.7, 0.65), mus, rot=(0, 18 * sgn, 0), name="Biyik")
    if p.get("beard"):
        sk = L.make_mat("Sakal", (0.1, 0.08, 0.07), rough=0.95, bump=("fine", 150, 0.3))
        L.sphere((0, -0.36, hz - 0.3), 0.3, (1.0, 0.55, 0.55), sk, name="Sakal")
    if p.get("lashes"):
        for sgn in (-1, 1):
            L.cube((0.17 * sgn, -0.44, hz + 0.12), (0.12, 0.02, 0.02), black, rot=(0, 10 * sgn, 0), name="Kirpik")

    # özel donanım
    if p.get("beard_long"):
        bm = L.make_mat("SakalUzun", p["beard_long"], rough=0.95, bump=("fine", 150, 0.3))
        L.sphere((0, -0.33, hz - 0.36), 0.34, (1.0, 0.6, 1.15), bm, name="SakalUzun")
    if p.get("glasses"):
        gm = L.make_mat("Gozluk", (0.08, 0.08, 0.08), rough=0.3, metal=0.6)
        for sgn in (-1, 1):
            L.torus((0.17 * sgn, -0.47, hz + 0.05), major=0.105, minor=0.012, mat=gm, rot=(90, 0, 0), name="Gozluk")
        L.cube((0, -0.47, hz + 0.06), (0.1, 0.015, 0.015), gm, name="GozlukKopru")
    if p.get("mask"):
        mk = L.make_mat("Maske", p["mask"], rough=0.9)
        L.sphere((0, -0.29, hz - 0.17), 0.33, (1.08, 0.78, 0.62), mk, name="Maske")
    if p.get("helmet"):
        hm2 = L.make_mat("Kask", p["helmet"], rough=0.35)
        L.sphere((0, 0.0, hz + 0.22), 0.53, (1.05, 1.0, 0.72), hm2, seg=40, rings=20, name="KaskUst")
        L.cylinder((0, -0.02, hz + 0.1), 0.56, 0.1, hm2, name="KaskBant")
        L.cube((0, -0.5, hz + 0.1), (0.7, 0.3, 0.03), hm2, rot=(8, 0, 0), name="KaskSiper", bevel=0.012)
        L.cube((0, -0.52, hz + 0.34), (0.2, 0.03, 0.14), L.make_mat("Rozet", (0.8, 0.1, 0.08), rough=0.4), name="Rozet")
    if p.get("chain"):
        gold = L.make_mat("Altin", (0.9, 0.7, 0.2), rough=0.25, metal=1.0)
        L.torus((0, -0.38, 1.5), major=0.28, minor=0.02, mat=gold, rot=(75, 0, 0), name="Zincir")
        L.sphere((0, -0.6, 1.28), 0.05, (1, 1, 1), gold, name="Kolye")
    if p.get("suit"):
        jm = L.make_mat("Ceket", p["shirt"], rough=0.8, bump=("fine", 120, 0.1))
        L.sphere((0, -0.06, 1.0), 0.64, (0.98 * p["belly"], 0.58 * p["belly"], 1.12), jm, name="Ceket")
        L.cube((0, -0.52, 1.25), (0.2, 0.04, 0.8), L.make_mat("Gomlek", (0.92, 0.92, 0.9), rough=0.7), name="GomlekSeridi")
        L.cube((0, -0.54, 1.2), (0.07, 0.03, 0.6), L.make_mat("Kravat", (0.75, 0.1, 0.12), rough=0.5), name="Kravat")
    if p.get("stripe"):
        refl = L.make_mat("Yansitici", (0.85, 0.9, 0.35), rough=0.3, metal=0.2, emission=(0.8, 0.9, 0.3), em_strength=0.6)
        L.cube((0, -0.5, 1.0), (1.0, 0.03, 0.09), refl, name="Serit1")
        L.cube((0, -0.5, 0.75), (1.0, 0.03, 0.09), refl, name="Serit2")
        for sgn in (-1, 1):
            L.cube((0.62 * sgn, -0.13, 1.18), (0.2, 0.2, 0.09), refl, name="KolSerit")
    if p.get("bag"):
        bagm = L.make_mat("Canta", (0.92, 0.42, 0.12), rough=0.6, bump=("fine", 80, 0.1))
        L.cube((-0.88, -0.28, 0.62), (0.7, 0.55, 0.62), bagm, bevel=0.05, name="SicakCanta")
        L.cube((-0.88, -0.28, 0.98), (0.72, 0.57, 0.06), L.make_mat("CantaKapak", (0.2, 0.2, 0.22), rough=0.5), bevel=0.02, name="CantaKapak")
    if p.get("camera"):
        cm = L.make_mat("Kamera", (0.07, 0.07, 0.08), rough=0.4, metal=0.4)
        L.cube((0.0, -0.6, 1.12), (0.4, 0.18, 0.26), cm, bevel=0.03, name="Kamera")
        L.cylinder((0.0, -0.74, 1.12), 0.09, 0.1, L.make_mat("Lens", (0.1, 0.12, 0.2), rough=0.1, metal=0.8), rot=(90, 0, 0), name="Lens")
        L.torus((0, -0.1, 1.55), major=0.62, minor=0.03, mat=cm, rot=(70, 0, 0), name="KameraKayis")
    if p.get("backpack"):
        bp = L.make_mat("Sirt", (0.55, 0.26, 0.12), rough=0.8, bump=("fine", 80, 0.15))
        for sgn in (-1, 1):
            L.cube((0.4 * sgn, -0.28, 1.4), (0.1, 0.06, 0.95), bp, rot=(0, 0, 4 * sgn), name="SirtKayis")
    if p.get("patches"):
        for i, (x, z, c) in enumerate(((-0.25, 1.1, (0.55, 0.2, 0.2)), (0.3, 0.8, (0.2, 0.35, 0.5)), (0.1, 1.35, (0.45, 0.4, 0.15)))):
            L.cube((x, -0.52, z), (0.22, 0.03, 0.2), L.make_mat(f"Yama{i}", c, rough=0.9), rot=(0, 0, 10 * (i - 1)), name="Yama")

    # şapka / saç / eşarp
    if "hat" in p and p["hat"][0] == "gezgin":
        hm = L.make_mat("GezginSapka", p["hat"][1], rough=0.9, bump=("fine", 90, 0.12))
        L.cylinder((0, -0.02, hz + 0.22), 0.74, 0.05, hm, name="SapkaKenar", scale=(1, 0.96, 1))
        L.sphere((0, 0.0, hz + 0.34), 0.45, (1.0, 0.96, 0.62), hm, seg=40, rings=20, name="SapkaUst")
        L.cylinder((0, -0.02, hz + 0.26), 0.47, 0.1, L.make_mat("SapkaBant", (0.32, 0.14, 0.1), rough=0.8), name="SapkaBant")
    elif "hat" in p and p["hat"][0] == "takke":
        tm = L.make_mat("Takke", p["hat"][1], rough=0.9, bump=("fine", 160, 0.25))
        L.sphere((0, 0.0, hz + 0.3), 0.44, (1.0, 0.97, 0.5), tm, seg=40, rings=20, name="Takke")
        L.cylinder((0, -0.02, hz + 0.22), 0.44, 0.07, tm, name="TakkeBant", scale=(1, 0.97, 1))
    elif "hat" in p and p["hat"][0] == "bere":
        bm2 = L.make_mat("Bere", p["hat"][1], rough=0.95, bump=("fine", 200, 0.2))
        L.sphere((0.1, 0.0, hz + 0.3), 0.55, (1.1, 1.0, 0.42), bm2, rot=(0, -10, 0), seg=40, rings=20, name="Bere")
        L.sphere((0.1, 0.0, hz + 0.5), 0.07, (1, 1, 1), bm2, name="BereTopu")
    elif "hat" in p:
        kind, col = p["hat"]
        hm = L.make_mat("Sapka", col, rough=0.85, bump=("fine", 90, 0.1))
        L.sphere((0, 0.0, hz + 0.28), 0.5, (1.0, 0.98, 0.5), hm, seg=40, rings=20, name="KasketUst")
        L.cylinder((0, -0.02, hz + 0.2), 0.48, 0.12, hm, name="KasketBant", scale=(1, 0.97, 1))
        L.cube((0, -0.5, hz + 0.3), (0.62, 0.3, 0.03), hm, rot=(10, 0, 0), name="KasketSiper", bevel=0.012)
    if "hair" in p:
        hm = L.make_mat("Sac", p["hair"], rough=0.9, bump=("fine", 140, 0.25))
        L.sphere((0, 0.04, hz + 0.1), 0.5, (1.0, 0.95, 0.9), hm, seg=40, rings=20, name="Sac")
        # alın bölgesini aç: yüz öne çıksın (yüz küresi tekrar önde)
        L.sphere((0, -0.06, hz - 0.03), 0.455, (1.0, 0.92, 1.0), skin, seg=40, rings=20, name="Alin")
    if p.get("hairband"):
        hb = L.make_mat("SacBandi", p["hairband"], rough=0.6)
        L.torus((0, 0.0, hz + 0.16), major=0.47, minor=0.035, mat=hb, scale=(1.0, 0.97, 1.0), name="SacBandi")
    if p.get("earrings"):
        gold2 = L.make_mat("Kupe", (0.92, 0.72, 0.22), rough=0.25, metal=1.0)
        for sgn in (-1, 1):
            L.sphere((0.47 * sgn, -0.02, hz - 0.14), 0.05, (1, 1, 1.4), gold2, seg=12, rings=8, name="Kupe")
    if "scarf" in p:
        sm = L.make_mat("Esarp", p["scarf"], rough=0.85, bump=("fine", 110, 0.2))
        L.sphere((0, 0.17, hz + 0.03), 0.53, (1.04, 0.92, 1.08), sm, seg=40, rings=20, name="Esarp")
        L.torus((0, -0.27, hz - 0.01), major=0.36, minor=0.065, mat=sm, rot=(90, 0, 0), name="EsarpKenar",
                scale=(1.0, 1.0, 1.12))
        L.sphere((0, 0.0, hz - 0.4), 0.3, (1.3, 0.85, 0.5), sm, name="EsarpBoyun")

    L.render(f"{OUT}/{cid}_{expr}.png", RES[0], RES[1], samples=40)


OUT = "."


def build_one(out, which):
    global OUT
    OUT = out
    cid, _, expr = which.partition(":")
    for e in ([expr] if expr else EXPR):
        build_char(cid, e)


def build_all(out):
    global OUT
    OUT = out
    for cid in CHARS:
        for e in EXPR:
            build_char(cid, e)
