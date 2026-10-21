"""Dükkân süsleri: bg_restoran / tezgah_on ile AYNI kamera ve ışık. Her süs ayrı, tam kare, şeffaf PNG (decor_<id>.png)."""
import math
import random

import bpy
from mathutils import Vector

import bl_lib as L
from bg import CAM, H, W, _apply, _base, emissive

BACK = ("kilim", "fener", "fistik", "foto", "saat", "bakir2", "isik", "kilim2", "neon", "akvaryum", "avize", "altinsaat", "sutun")   # müşterilerin ARKASINDA
FRONT = ("saksi",)                                                       # tezgâhın ÜSTÜNDE (müşteri önünde)


def _catch_wall():
    p = L.plane((0, 3.0, 5.5), (24, 12), None, rot=(90, 0, 0))
    _apply(p)
    p.is_shadow_catcher = True


def _catch_box(loc, size):
    c = L.cube(loc, size)
    c.is_shadow_catcher = True


def _start(back=True):
    _base()
    if back:
        _catch_wall()


def d_kilim():
    _start()
    mat = bpy.data.materials.new("Kilim")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Y"
    wave.inputs["Scale"].default_value = 3.4
    wave.inputs["Distortion"].default_value = 0.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    cols = [(0.62, 0.10, 0.08, 1), (0.93, 0.85, 0.65, 1), (0.10, 0.20, 0.40, 1), (0.88, 0.62, 0.14, 1)]
    e = ramp.color_ramp.elements
    e[0].position = 0.0
    e[0].color = cols[0]
    e[1].position = 0.5
    e[1].color = cols[1]
    for pos, c in ((0.25, cols[2]), (0.75, cols[3])):
        el = e.new(pos)
        el.color = c
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 120
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    rug = L.plane((5.2, 2.86, 3.75), (3.2, 1.5), mat, rot=(90, 0, 0), name="Kilim")
    _apply(rug)
    fr = L.make_mat("KilimKenar", (0.25, 0.12, 0.06), rough=0.7)
    L.cube((5.2, 2.85, 4.52), (3.3, 0.05, 0.07), fr, name="KilimUst")
    cream = L.make_mat("Puskul", (0.93, 0.88, 0.75), rough=0.9)
    for i in range(24):
        L.cylinder((3.7 + i * 0.131, 2.85, 2.93), 0.016, 0.22, cream, verts=8, name="Puskul")
    L.render(f"{OUT}/decor_kilim.png", W, H, samples=40)


def d_fener():
    _start()
    metal = L.make_mat("FenerMetal", (0.55, 0.35, 0.15), rough=0.3, metal=1.0)
    glass = emissive("FenerCam", (1.0, 0.55, 0.15), 3.0)
    dark = L.make_mat("Ip", (0.02, 0.02, 0.02), rough=1.0)
    for x, z in ((-6.3, 7.4), (6.7, 8.0), (-4.5, 8.2)):
        L.cylinder((x, 1.9, z + 0.9), 0.012, 1.2, dark, name="FenerIp")
        L.cylinder((x, 1.9, z), 0.26, 0.5, glass, verts=12, name="FenerCam")
        for k in range(6):
            a = k * math.tau / 6
            L.cylinder((x + 0.27 * math.cos(a), 1.9 + 0.27 * math.sin(a), z), 0.014, 0.52, metal, verts=6, name="FenerTel")
        L.cylinder((x, 1.9, z + 0.28), 0.3, 0.06, metal, verts=12, name="FenerKapak")
        L.sphere((x, 1.9, z + 0.4), 0.08, (1, 1, 1), metal, name="FenerTepe")
        L.cylinder((x, 1.9, z - 0.28), 0.22, 0.05, metal, verts=12, name="FenerTaban")
        L.add_point((x, 1.2, z), energy=90, color=(1, 0.6, 0.25), radius=0.15)
    L.render(f"{OUT}/decor_fener.png", W, H, samples=40)


def d_fistik():
    _start()
    _catch_box((0.4, 2.6, 4.3), (4.6, 0.7, 0.14))
    bowl_m = L.make_mat("FistikKase", (0.85, 0.55, 0.25), rough=0.35, metal=0.6)
    nuts = L.make_mat("Fistik", (0.58, 0.72, 0.28), rough=0.5, bump=("fine", 50, 0.2))
    rnd = random.Random(12)
    for cx in (1.85, 2.6):
        b = L.sphere((cx, 2.55, 4.55), 0.3, (1, 1, 0.55), bowl_m, seg=32, rings=16, name="FistikKase")
        pts = [Vector((cx + rnd.uniform(-0.2, 0.2), 2.55 + rnd.uniform(-0.2, 0.2), 4.62 + rnd.uniform(0, 0.1))) for _ in range(40)]
        L.blob_cloud("Fistik", pts, nuts, radius=0.05, jitter=0.2, seed=int(cx * 10), subdiv=1)
    L.render(f"{OUT}/decor_fistik.png", W, H, samples=40)


def d_foto():
    _start()
    wood = L.make_mat("FotoCerceve", (0.30, 0.16, 0.07), rough=0.5)
    paper = L.make_mat("FotoKagit", (0.75, 0.62, 0.45), rough=0.8)
    sepia = L.make_mat("FotoSiluet", (0.32, 0.22, 0.14), rough=0.9)
    L.cube((-7.35, 2.86, 5.3), (1.3, 0.09, 1.7), wood, name="FotoCerceve", bevel=0.03)
    L.cube((-7.35, 2.8, 5.3), (1.05, 0.03, 1.45), paper, name="FotoKagit")
    L.sphere((-7.35, 2.76, 5.5), 0.2, (1, 0.4, 1.1), sepia, name="FotoBas")
    L.sphere((-7.35, 2.76, 5.0), 0.34, (1, 0.4, 1.0), sepia, name="FotoGovde")
    L.cube((-7.35, 2.75, 5.68), (0.48, 0.05, 0.1), sepia, name="FotoKasket")
    L.render(f"{OUT}/decor_foto.png", W, H, samples=40)


def d_saat():
    _start()
    brass = L.make_mat("SaatPirinc", (0.85, 0.65, 0.25), rough=0.25, metal=1.0)
    face = L.make_mat("SaatYuz", (0.96, 0.94, 0.88), rough=0.5)
    dark = L.make_mat("SaatKol", (0.04, 0.04, 0.04), rough=0.5)
    L.cylinder((-7.35, 2.86, 7.2), 0.5, 0.08, face, rot=(90, 0, 0), name="SaatYuz")
    L.torus((-7.35, 2.82, 7.2), major=0.5, minor=0.045, mat=brass, rot=(90, 0, 0), name="SaatCerceve")
    for k in range(12):
        a = k * math.tau / 12
        L.cube((-7.35 + 0.4 * math.sin(a), 2.8, 7.2 + 0.4 * math.cos(a)), (0.03, 0.02, 0.07), dark, rot=(0, -math.degrees(a), 0), name="Rakam")
    L.cube((-7.35 + 0.0, 2.78, 7.2 + 0.12), (0.035, 0.02, 0.28), dark, name="Akrep")
    L.cube((-7.35 + 0.14, 2.78, 7.2 - 0.0), (0.3, 0.02, 0.03), dark, name="Yelkovan")
    L.render(f"{OUT}/decor_saat.png", W, H, samples=40)


def d_bakir2():
    _start()
    copper = L.make_mat("Bakir", (0.85, 0.42, 0.22), rough=0.28, metal=1.0)
    inner = L.make_mat("BakirIc", (0.9, 0.55, 0.3), rough=0.3, metal=1.0)
    for z, r in ((6.9, 0.42), (5.95, 0.5), (4.95, 0.4)):
        L.cylinder((7.4, 2.88, z), r, 0.06, copper, rot=(90, 0, 0), name="Bakir2")
        L.cylinder((7.4, 2.84, z), r * 0.62, 0.05, inner, rot=(90, 0, 0), name="Bakir2Ic")
    L.render(f"{OUT}/decor_bakir2.png", W, H, samples=40)


def d_isik():
    _start()
    neon = emissive("Neon", (1.0, 0.72, 0.25), 6.0)
    for (x, z, sx, sz) in ((0.3, 8.33, 5.9, 0.05), (0.3, 7.07, 5.9, 0.05), (-2.62, 7.7, 0.05, 1.3), (3.22, 7.7, 0.05, 1.3)):
        L.cube((x, 2.74, z), (sx, 0.04, sz), neon, name="Neon")
    L.add_point((0.3, 2.0, 7.7), energy=120, color=(1, 0.7, 0.3), radius=0.4)
    L.render(f"{OUT}/decor_isik.png", W, H, samples=40)


def d_saksi():
    _base()
    # tezgâh üstü gölge yakalayıcı
    cat = L.cube((0, -1.75, 2.6), (24, 1.5, 0.22))
    cat.is_shadow_catcher = True
    terra = L.make_mat("Saksi", (0.72, 0.36, 0.2), rough=0.6, bump=("noise", 30, 0.2))
    leaf = L.make_mat("Yaprak", (0.18, 0.5, 0.16), rough=0.5)
    flower = L.make_mat("Cicek", (0.85, 0.15, 0.2), rough=0.4)
    rnd = random.Random(22)
    for x in (-7.2, 7.2):
        L.cylinder((x, -1.7, 2.95), 0.34, 0.5, terra, verts=24, name="Saksi")
        L.torus((x, -1.7, 3.2), major=0.36, minor=0.05, mat=terra, name="SaksiKenar")
        for k in range(9):
            a = k * math.tau / 9 + rnd.uniform(-0.2, 0.2)
            L.sphere((x + 0.2 * math.cos(a), -1.7 + 0.2 * math.sin(a), 3.55 + rnd.uniform(0, 0.3)), 0.2,
                     (0.5, 0.12, 1.4), leaf, rot=(rnd.uniform(-30, 30), rnd.uniform(-30, 30), math.degrees(a)), name="Yaprak")
        for k in range(4):
            L.sphere((x + rnd.uniform(-0.25, 0.25), -1.7 + rnd.uniform(-0.2, 0.2), 3.9 + rnd.uniform(0, 0.25)), 0.11,
                     (1, 1, 0.8), flower, name="Cicek")
    L.render(f"{OUT}/decor_saksi.png", W, H, samples=40)


def d_kilim2():
    """İkinci kilim: sol duvarda, fırın ile fotoğraf arasında asılı yolluk."""
    _start()
    mat = bpy.data.materials.new("Kilim2")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    tc = nt.nodes.new("ShaderNodeTexCoord")
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 9.0
    chk.inputs["Color1"].default_value = (0.10, 0.22, 0.38, 1)
    chk.inputs["Color2"].default_value = (0.86, 0.70, 0.30, 1)
    nt.links.new(tc.outputs["Object"], chk.inputs["Vector"])
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    rug = L.plane((-7.4, 2.86, 3.4), (1.25, 1.7), mat, rot=(90, 0, 0), name="Kilim2")
    _apply(rug)
    fr = L.make_mat("Kilim2Kenar", (0.25, 0.12, 0.06), rough=0.7)
    L.cube((-7.4, 2.85, 4.28), (1.35, 0.05, 0.07), fr, name="Kilim2Ust")
    cream = L.make_mat("Puskul2", (0.93, 0.88, 0.75), rough=0.9)
    for i in range(10):
        L.cylinder((-7.9 + i * 0.1, 2.85, 2.46), 0.016, 0.22, cream, verts=8, name="Puskul2")
    L.render(f"{OUT}/decor_kilim2.png", W, H, samples=40)


def d_neon():
    """Neon tabela: pencerenin üstünde pembe-mavi çerçeve (yazı yok, ışık parıltısı Flutter'da)."""
    _start()
    pink = emissive("NeonPembe", (1.0, 0.2, 0.5), 2.2)
    blue = emissive("NeonMavi", (0.15, 0.5, 1.0), 2.0)
    for x, z, sx, sz, m in ((5.2, 8.1, 3.0, 0.05, pink), (5.2, 8.7, 3.0, 0.05, blue), (3.7, 8.4, 0.05, 0.65, pink), (6.7, 8.4, 0.05, 0.65, blue)):
        L.cube((x, 2.74, z), (sx, 0.04, sz), m, name="Neon")
    L.cylinder((5.2, 2.74, 8.4), 0.13, 0.04, pink, rot=(90, 0, 0), name="NeonDaire")
    L.add_point((5.2, 2.0, 8.4), energy=140, color=(1, 0.45, 0.8), radius=0.4)
    L.render(f"{OUT}/decor_neon.png", W, H, samples=40)


def d_akvaryum():
    """Akvaryum: sağ duvarda raf üstünde cam tank, balıklar ve taşlar."""
    _start()
    wood = L.make_mat("AkvRaf", (0.30, 0.16, 0.07), rough=0.5)
    L.cube((7.25, 2.7, 3.0), (1.5, 0.6, 0.12), wood, name="AkvRaf", bevel=0.02)
    _catch_box((7.25, 2.7, 3.0), (1.5, 0.6, 0.12))
    glass = L.make_mat("AkvCam", (0.8, 0.95, 1.0), rough=0.03)
    b = glass.node_tree.nodes["Principled BSDF"]
    if "Transmission Weight" in b.inputs:
        b.inputs["Transmission Weight"].default_value = 0.9
        b.inputs["IOR"].default_value = 1.33
    water = L.make_mat("AkvSu", (0.35, 0.75, 0.9), rough=0.05)
    L.cube((7.25, 2.68, 3.62), (1.34, 0.5, 1.0), glass, name="AkvCam", bevel=0.02)
    L.cube((7.25, 2.68, 3.55), (1.28, 0.44, 0.85), water, name="AkvSu")
    sand = L.make_mat("AkvKum", (0.9, 0.82, 0.6), rough=0.9)
    L.cube((7.25, 2.68, 3.16), (1.28, 0.44, 0.1), sand, name="AkvKum")
    rnd = random.Random(8)
    for x, z, col in ((7.0, 3.6, (1.0, 0.45, 0.1)), (7.45, 3.8, (0.95, 0.85, 0.2)), (7.2, 3.35, (0.9, 0.2, 0.2))):
        fish = L.make_mat("Balik", col, rough=0.35)
        L.sphere((x, 2.6, z), 0.1, (1.5, 0.5, 0.9), fish, name="Balik")
        L.sphere((x + 0.14 * (1 if x < 7.25 else -1) * -1, 2.6, z), 0.05, (0.4, 0.3, 1), fish, name="BalikKuyruk")
    weed = L.make_mat("Yosun", (0.15, 0.55, 0.2), rough=0.5)
    for dx in (-0.45, -0.3, 0.4, 0.5):
        L.sphere((7.25 + dx, 2.62, 3.42), 0.06, (0.5, 0.3, 4.0), weed, name="Yosun")
    L.render(f"{OUT}/decor_akvaryum.png", W, H, samples=40)


def d_avize():
    """Kristal avize: tavandan sarkan altın halka ve parlayan kristal damlalar."""
    _start()
    gold = L.make_mat("AvizeAltin", (0.9, 0.68, 0.2), rough=0.2, metal=1.0)
    crystal = emissive("Kristal", (1.0, 0.92, 0.7), 4.0)
    L.cylinder((0.3, 1.5, 9.0), 0.02, 1.6, gold, name="AvizeZincir", verts=8)
    for r, z, n in ((0.95, 7.7, 10), (0.6, 7.95, 7)):
        L.torus((0.3, 1.5, z), major=r, minor=0.04, mat=gold, name="AvizeHalka")
        for k in range(n):
            a = k * math.tau / n
            x, y = 0.3 + r * math.cos(a), 1.5 + r * math.sin(a)
            L.cylinder((x, y, z + 0.12), 0.02, 0.2, gold, name="AvizeKol", verts=8)
            L.sphere((x, y, z + 0.28), 0.07, (1, 1, 1.4), crystal, seg=12, rings=8, name="AvizeAlev")
            L.cylinder((x, y, z - 0.18), 0.012, 0.3, gold, name="AvizeDamla", verts=6)
            L.sphere((x, y, z - 0.38), 0.045, (1, 1, 1.6), crystal, seg=10, rings=6, name="AvizeKristal")
    L.sphere((0.3, 1.5, 7.35), 0.14, (1, 1, 1.3), crystal, name="AvizeUc")
    L.add_point((0.3, 0.6, 7.7), energy=320, color=(1, 0.88, 0.6), radius=0.5)
    L.render(f"{OUT}/decor_avize.png", W, H, samples=40)


def d_altinsaat():
    """Altın saat: sağ üst köşede büyük, süslü altın duvar saati."""
    _start()
    gold = L.make_mat("AltinSaat", (0.92, 0.70, 0.22), rough=0.2, metal=1.0)
    face = L.make_mat("AltinYuz", (0.98, 0.95, 0.86), rough=0.5)
    dark = L.make_mat("SaatKol", (0.04, 0.04, 0.04), rough=0.5)
    cx, cz = 7.35, 8.0
    L.cylinder((cx, 2.86, cz), 0.62, 0.08, face, rot=(90, 0, 0), name="Yuz")
    L.torus((cx, 2.82, cz), major=0.62, minor=0.06, mat=gold, rot=(90, 0, 0), name="Cerceve")
    for k in range(12):
        a = k * math.tau / 12
        L.sphere((cx + 0.5 * math.sin(a), 2.78, cz + 0.5 * math.cos(a)), 0.035, (1, 0.6, 1), dark, name="Rakam")
        L.sphere((cx + 0.75 * math.sin(a), 2.82, cz + 0.75 * math.cos(a)), 0.05, (1, 0.6, 1), gold, name="Sus")
    L.cube((cx, 2.76, cz + 0.14), (0.04, 0.02, 0.3), dark, name="Akrep")
    L.cube((cx + 0.17, 2.76, cz), (0.36, 0.02, 0.035), dark, name="Yelkovan")
    L.render(f"{OUT}/decor_altinsaat.png", W, H, samples=40)


def d_sutun():
    """Mermer sütunlar: iki yan kenarda yerden tavana."""
    _start()
    marble = L.make_mat("Mermer", (0.94, 0.93, 0.9), rough=0.12, bump=("noise", 6, 0.04))
    gold = L.make_mat("SutunAltin", (0.88, 0.66, 0.2), rough=0.22, metal=1.0)
    for x in (-8.0, 8.0):
        L.cylinder((x, 2.3, 4.5), 0.28, 9.0, marble, verts=40, name="Sutun")
        L.cube((x, 2.3, 0.18), (0.8, 0.8, 0.36), marble, bevel=0.03, name="SutunTaban")
        L.cube((x, 2.3, 8.82), (0.8, 0.8, 0.36), marble, bevel=0.03, name="SutunBas")
        L.torus((x, 2.3, 0.45), major=0.3, minor=0.04, mat=gold, name="SutunHalka")
        L.torus((x, 2.3, 8.55), major=0.3, minor=0.04, mat=gold, name="SutunHalka2")
    L.render(f"{OUT}/decor_sutun.png", W, H, samples=40)


OUT = "."
FUNCS = {"kilim": d_kilim, "fener": d_fener, "fistik": d_fistik, "foto": d_foto, "saat": d_saat, "bakir2": d_bakir2,
         "isik": d_isik, "saksi": d_saksi, "kilim2": d_kilim2, "neon": d_neon, "akvaryum": d_akvaryum, "avize": d_avize,
         "altinsaat": d_altinsaat, "sutun": d_sutun}


def build_one(out, which):
    global OUT
    OUT = out
    FUNCS[which]()


def build_all(out):
    global OUT
    OUT = out
    for f in FUNCS.values():
        f()
