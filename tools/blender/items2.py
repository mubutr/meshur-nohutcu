"""v3 ürünleri: tencere, tepsiler, soslar, tahta katmanları, bitmiş dürümler, bahşiş kavanozu.

Kamera/çözünürlükler items.py ile aynıdır (tahta katmanları BOARD_CAM, istasyonlar _prop_scene)."""
import math
import random

import bpy
from mathutils import Vector

import bl_lib as L
from items import BOARD_CAM, BOARD_RES, NOHUT_COL, _bowl, _bread, _catcher, _lights, _prop_scene, board_scene

STEEL = dict(color=(0.78, 0.8, 0.82), rough=0.25, metal=1.0)

MEAT = (0.42, 0.20, 0.09)
KAVURMA = (0.27, 0.11, 0.05)
COGKOFTE = (0.66, 0.30, 0.12)


def steel(name="Celik"):
    return L.make_mat(name, STEEL["color"], rough=STEEL["rough"], metal=STEEL["metal"])


def _curve(name, pts, mat, bevel=0.03):
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


# ------------------------------------------------------------------ yiyecek parçaları
def _slices(name, n, rx, ry, z, hmax, mat, rnd, radius=0.13, flat=0.35, seed=1):
    pts = L.scatter_disc(n, rx, ry, rnd, min_dist=0.1, z=z, hmax=hmax)
    return L.blob_cloud(name, pts, mat, radius=radius, jitter=0.35, seed=seed, subdiv=1, flat=flat)


def _fries(n, rx, ry, z, hmax, rnd, min_dist=0.2):
    """Patates çubukları + patlıcan dilimleri + yeşil biber (kızartma karışımı)."""
    potato = L.make_mat("Patates", (0.95, 0.74, 0.28), rough=0.6, bump=("fine", 40, 0.12))
    eggplant = L.make_mat("Patlican", (0.22, 0.08, 0.20), rough=0.35)
    pepper = L.make_mat("Biber", (0.25, 0.55, 0.15), rough=0.4)
    pts = L.scatter_disc(n, rx, ry, rnd, min_dist=min_dist, z=z, hmax=hmax)
    for i, p in enumerate(pts):
        k = i % 5
        if k <= 2:
            L.cube(p, (0.5, 0.1, 0.1), potato, rot=(rnd.uniform(-15, 15), rnd.uniform(-15, 15), rnd.uniform(0, 180)), bevel=0.01, name="Patates")
        elif k == 3:
            L.cylinder(p, 0.15, 0.05, eggplant, rot=(rnd.uniform(-20, 20), rnd.uniform(-20, 20), 0), verts=16, name="Patlican")
        else:
            L.sphere(p, 0.07, (2.4, 0.8, 0.8), pepper, rot=(0, 0, rnd.uniform(0, 180)), seg=12, rings=6, name="Biber")


def _lettuce(n, rx, ry, z, rnd):
    leaf = L.make_mat("Marul", (0.30, 0.62, 0.16), rough=0.45)
    for _ in range(n):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        L.sphere((r * math.cos(a) * rx, r * math.sin(a) * ry, z + rnd.uniform(0, 0.03)), 0.12, (1.8, 1, 0.18), leaf,
                 rot=(rnd.uniform(-15, 15), rnd.uniform(-15, 15), rnd.uniform(0, 360)), seg=12, rings=6, name="Marul")


def _fill(kind, rx, ry, z, hmax, n, rnd, seed=1):
    """Ana malzeme: kind = doner | kavurma | cigkofte | kizartma"""
    if kind == "doner":
        mat = L.make_mat("Doner", MEAT, rough=0.55, bump=("fine", 60, 0.2))
        _slices("DonerDilim", n, rx, ry, z, hmax, mat, rnd, radius=0.14, flat=0.32, seed=seed)
        light = L.make_mat("DonerAcik", (0.62, 0.36, 0.18), rough=0.5)
        _slices("DonerAcik", n // 3, rx, ry, z + 0.03, hmax, light, rnd, radius=0.1, flat=0.3, seed=seed + 3)
    elif kind == "kavurma":
        mat = L.make_mat("Kavurma", KAVURMA, rough=0.32, bump=("fine", 50, 0.2))
        _slices("KavurmaParca", n, rx, ry, z, hmax, mat, rnd, radius=0.11, flat=0.7, seed=seed)
    elif kind == "cigkofte":
        mat = L.make_mat("CigKofte", COGKOFTE, rough=0.75, bump=("fine", 90, 0.3))
        _slices("Kofte", n, rx, ry, z, hmax, mat, rnd, radius=0.1, flat=0.8, seed=seed)
        _lettuce(max(3, n // 5), rx, ry, z + 0.02, rnd)
    elif kind == "kizartma":
        _fries(max(8, n // 2), rx, ry, z, hmax, rnd)


# ------------------------------------------------------------------ tahta katmanları (üstten)
def build_board_layers(out):
    for kind, counts in (("doner", (16, 30)), ("kavurma", (18, 34)), ("cigkofte", (18, 34)), ("kizartma", (18, 34))):
        for lvl, n in enumerate(counts, start=1):
            board_scene(bread=False)
            rnd = random.Random(40 + lvl)
            _fill(kind, 0.95 + 0.12 * lvl, 0.38 + 0.07 * lvl, 0.12, 0.05 + 0.04 * lvl, n, rnd, seed=lvl)
            L.render(f"{out}/top_{kind}_{lvl}.png", BOARD_RES, BOARD_RES)

    # kızartma eki (az miktar, bir kenara dizili)
    board_scene(bread=False)
    rnd = random.Random(90)
    _fries(9, 0.55, 0.26, 0.2, 0.05, rnd)
    L.render(f"{out}/top_fried.png", BOARD_RES, BOARD_RES)

    # soslar: ekmek üstünde zikzak şeritler
    sauces = {
        "sos": ((0.55, 0.10, 0.04), 0.35, 7.0, 0.0),
        "ketcap": ((0.80, 0.05, 0.03), 0.30, 6.0, 0.9),
        "mayonez": ((0.97, 0.94, 0.78), 0.26, 8.0, 1.8),
        "nar": ((0.28, 0.03, 0.06), 0.22, 5.0, 2.6),
    }
    for sid, (col, amp, freq, ph) in sauces.items():
        board_scene(bread=False)
        mat = L.make_mat("Sos_" + sid, col, rough=0.18, sss=0.1)
        pts = [(x, amp * math.sin(freq * x * 0.5 + ph) * (0.9 if sid != "mayonez" else 0.7), 0.27 + 0.02 * math.sin(3 * x)) for x in [(-1.15 + i * 0.05) for i in range(47)]]
        _curve("Sos", pts, mat, bevel=0.035)
        L.render(f"{out}/top_{sid}.png", BOARD_RES, BOARD_RES)


# ------------------------------------------------------------------ beyran
def _hollow_bowl(mat, r=1.0, h=0.55, loc=(0, 0), thickness=0.07):
    """Gerçek (içi boş) kâse: yarım küre, üstü açık, kalınlık verilmiş."""
    import bmesh
    o = L.sphere((loc[0], loc[1], h), r, (1, 1, 0.62), mat, seg=64, rings=32, name="Kase")
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.001], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    sol = o.modifiers.new("Sol", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = -1
    return o


def _soup_bowl(rnd, r=0.95, h=0.5):
    cer = L.make_mat("BeyranKase", (0.93, 0.90, 0.80), rough=0.28)
    trim = L.make_mat("BeyranKenar", (0.12, 0.30, 0.42), rough=0.3)
    _hollow_bowl(cer, r=r, h=h)
    L.torus((0, 0, h), major=r * 0.995, minor=0.035, mat=trim, name="KaseKenar")
    broth = L.make_mat("Corba", (0.62, 0.34, 0.12), rough=0.15)
    L.cylinder((0, 0, h - 0.1), r * 0.9, 0.05, broth, verts=48, name="Corba")
    oil = L.make_mat("AciYag", (0.8, 0.10, 0.03), rough=0.12)
    L.torus((0, 0, h - 0.07), major=r * 0.5, minor=0.05, mat=oil, scale=(1, 1, 0.35), name="AciYag")
    L.torus((0, 0, h - 0.07), major=r * 0.26, minor=0.035, mat=oil, scale=(1, 1, 0.35), name="AciYag2")
    meat = L.make_mat("BeyranEt", (0.50, 0.27, 0.12), rough=0.45)
    pts = L.scatter_disc(8, r * 0.62, r * 0.62, rnd, min_dist=0.24, z=h - 0.05, hmax=0.06)
    L.blob_cloud("BeyranEt", pts, meat, radius=0.15, jitter=0.25, seed=4, subdiv=1, flat=0.65)
    rice = L.make_mat("Pirinc", (0.97, 0.94, 0.84), rough=0.5)
    pts = L.scatter_disc(60, r * 0.75, r * 0.75, rnd, min_dist=0.0, z=h - 0.06, hmax=0.05, tries=1)
    L.blob_cloud("Pirinc", pts, rice, radius=0.035, jitter=0.3, seed=2, subdiv=1, flat=0.5)
    green = L.make_mat("Maydanoz", (0.18, 0.5, 0.14), rough=0.55)
    for _ in range(12):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.1, 0.75) * r
        L.sphere((rr * math.cos(a), rr * math.sin(a), h - 0.045), 0.045, (1.6, 1, 0.4), green, seg=8, rings=4, rot=(0, 0, rnd.uniform(0, 360)))


def build_beyran(out):
    _prop_scene()
    _soup_bowl(random.Random(5))
    L.render(f"{out}/beyran_kase.png", 512, 512)
    # tahtada: ekmek yok, kâse büyük görünür
    L.reset_scene()
    L.setup_camera(**BOARD_CAM)
    _lights()
    _catcher()
    _soup_bowl(random.Random(5), r=1.25, h=0.62)
    L.render(f"{out}/beyran_tabla.png", BOARD_RES, BOARD_RES)


# ------------------------------------------------------------------ istasyon sprite'ları (512)
def _tray(w, d, rnd_seed=1):
    s = steel()
    base = L.cube((0, 0, 0.1), (w, d, 0.2), s, bevel=0.04, name="Tepsi")
    # içi hafif koyu çukur
    L.cube((0, 0, 0.21), (w - 0.18, d - 0.18, 0.04), L.make_mat("TepsiIc", (0.55, 0.57, 0.6), rough=0.4, metal=1.0), bevel=0.02, name="TepsiIc")
    return base


def build_trays(out):
    for kind, w, d in (("doner", 2.1, 1.5), ("kavurma", 2.1, 1.5), ("cigkofte", 2.1, 1.5), ("kizartma", 2.1, 1.5)):
        _prop_scene()
        _tray(w, d)
        rnd = random.Random(60)
        _fill(kind, w * 0.42, d * 0.4, 0.26, 0.3, 42, rnd, seed=7)
        L.render(f"{out}/{kind}_tepsi.png", 512, 512)

    # kızartma eki kâsesi (küçük çelik kâse)
    _prop_scene()
    s = steel()
    _bowl(s, s, r=0.85, h=0.5)
    _fries(70, 0.66, 0.66, 0.58, 0.34, random.Random(11), min_dist=0.1)
    L.render(f"{out}/kizartma_kase.png", 512, 512)


def build_tencere(out):
    """Nohut tenceresi: paslanmaz tencere, kenarında tutamaklar, içinde nohut ve kepçe."""
    L.reset_scene()
    L.setup_camera(elev_deg=36, dist=12, ortho_scale=3.4, target=(0, 0, 0.62))
    _lights(3.0)
    _catcher()
    s = steel("Tencere")
    L.cylinder((0, 0, 0.52), 0.95, 1.04, s, verts=64, name="Govde")
    L.torus((0, 0, 1.04), major=0.95, minor=0.055, mat=s, name="Kenar")
    L.cylinder((0, 0, 0.04), 1.0, 0.08, s, verts=64, name="Taban")
    for sgn in (-1, 1):
        L.torus((0.98 * sgn, 0, 0.86), major=0.14, minor=0.04, mat=s, rot=(0, 90, 0), name="Tutamak")
    # içi: nohut tepesi
    rnd = random.Random(14)
    nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.5, sss=0.25, bump=("fine", 38, 0.15))
    L.cylinder((0, 0, 0.97), 0.88, 0.06, L.make_mat("Su", (0.7, 0.55, 0.3), rough=0.2), verts=48, name="Su")
    pts = L.scatter_disc(150, 0.84, 0.84, rnd, min_dist=0.13, z=1.0, hmax=0.12)
    L.blob_cloud("Nohut", pts, nohut, radius=0.075, jitter=0.12, seed=6)
    # kepçe
    L.cylinder((0.62, -0.2, 1.52), 0.025, 1.3, s, rot=(38, 0, 32), verts=12, name="KepceSap")
    L.sphere((0.3, -0.5, 1.02), 0.2, (1, 1, 0.5), s, name="KepceKase")
    L.render(f"{out}/nohut_tencere.png", 512, 512)


def _bottle(out, name, body, cap, label, glass=False, squeeze=False):
    L.reset_scene()
    L.setup_camera(elev_deg=20, dist=12, ortho_scale=3.4, target=(0, 0, 0.95))
    _lights(3.0)
    _catcher()
    if glass:
        bm = L.make_mat("Cam", body, rough=0.08)
        b = bm.node_tree.nodes["Principled BSDF"]
        if "Transmission Weight" in b.inputs:
            b.inputs["Transmission Weight"].default_value = 0.85
            b.inputs["IOR"].default_value = 1.45
    else:
        bm = L.make_mat("Sise", body, rough=0.35)
    capm = L.make_mat("Kapak", cap, rough=0.35)
    lab = L.make_mat("Etiket", label, rough=0.7)
    L.cylinder((0, 0, 0.62), 0.42, 1.24, bm, verts=48, name="Govde")
    L.sphere((0, 0, 1.24), 0.42, (1, 1, 0.5), bm, name="Omuz")
    L.cylinder((0, 0, 1.52), 0.15 if not squeeze else 0.19, 0.42, bm, verts=32, name="Boyun")
    L.cylinder((0, 0, 1.78), 0.2 if not squeeze else 0.22, 0.2, capm, verts=32, name="Kapak")
    if squeeze:
        L.cylinder((0, 0, 1.92), 0.08, 0.14, capm, verts=16, name="Uc")
    L.cylinder((0, 0, 0.62), 0.425, 0.62, lab, verts=48, name="Etiket")
    L.sphere((0, -0.4, 0.62), 0.14, (1, 0.25, 1), L.make_mat("Logo", (0.97, 0.9, 0.7), rough=0.6), name="Logo")
    L.render(f"{out}/{name}.png", 512, 512)


def build_bottles(out):
    _bottle(out, "sos_sise", (0.55, 0.12, 0.05), (0.96, 0.96, 0.94), (0.8, 0.45, 0.12), squeeze=True)
    _bottle(out, "ketcap_sise", (0.82, 0.06, 0.04), (0.82, 0.06, 0.04), (0.97, 0.92, 0.8), squeeze=True)
    _bottle(out, "mayonez_sise", (0.97, 0.94, 0.80), (0.95, 0.75, 0.1), (0.2, 0.45, 0.7), squeeze=True)
    _bottle(out, "nar_sise", (0.30, 0.03, 0.07), (0.9, 0.7, 0.2), (0.93, 0.85, 0.65), glass=True)


# ------------------------------------------------------------------ bitmiş dürümler
YAW = math.radians(-40)  # dürümün açık ucu kameraya doğru döner: dolgu görünsün
AX = (math.cos(YAW), math.sin(YAW))        # dürüm ekseni (yatay)
UX = (-math.sin(YAW), math.cos(YAW))       # açık uca dik yatay yön


def _end_pt(axial, across, up):
    """Açık uç merkezinden (1.0 ekseni) dışarı: axial boyunca, across yatay, up dikey."""
    ex, ey = AX[0] * (1.0 + axial) + UX[0] * across, AX[1] * (1.0 + axial) + UX[1] * across
    return Vector((ex, ey, 0.42 + up))


def _durum(out, name, fill):
    L.reset_scene()
    L.setup_camera(elev_deg=40, dist=14, ortho_scale=3.8, target=(0.1, -0.1, 0.35))
    _lights(3.2)
    _catcher()
    bread = L.bread_material()
    paper = L.make_mat("Kagit", (0.95, 0.93, 0.88), rough=0.9, bump=("fine", 14, 0.25))
    deg = math.degrees(YAW)
    L.cylinder((0, 0, 0.42), 0.40, 2.0, bread, rot=(0, 90, deg), name="Durum")
    L.cylinder((-0.46 * AX[0], -0.46 * AX[1], 0.42), 0.43, 1.05, paper, rot=(0, 90, deg), name="Kagit")
    fill(random.Random(2))
    L.render(f"{out}/{name}.png", 640, 480)


def _spill(mat, rnd, n=20, radius=0.1, flat=1.0, spread=0.3):
    pts = []
    for _ in range(n):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * spread
        pts.append(_end_pt(rnd.uniform(0.0, 0.28), r * math.cos(a), r * math.sin(a)))
    L.blob_cloud("Dolgu", pts, mat, radius=radius, jitter=0.25, seed=9, subdiv=1, flat=flat)


def _garnish(rnd):
    green = L.make_mat("Maydanoz", (0.18, 0.5, 0.14), rough=0.55)
    onion = L.make_mat("Sogan", (0.93, 0.72, 0.80), rough=0.35, sss=0.4)
    for _ in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.1, 0.34)
        L.sphere(_end_pt(rnd.uniform(0.05, 0.3), r * math.cos(a), r * math.sin(a)), 0.05, (1, 1.6, 0.4), green, seg=8, rings=6)
    for _ in range(5):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.1, 0.3)
        L.torus(_end_pt(rnd.uniform(0.05, 0.25), r * math.cos(a), r * math.sin(a)), major=0.09, minor=0.014, mat=onion, rot=(rnd.uniform(0, 90), rnd.uniform(0, 90), 0))


def build_wraps(out):
    # malzemeler sahne sıfırlandıktan SONRA (fill içinde) üretilir
    def doner(r):
        _spill(L.make_mat("Doner", MEAT, rough=0.55), r, 22, 0.11, 0.45)
        _spill(L.make_mat("DonerAcik", (0.66, 0.40, 0.2), rough=0.5), r, 8, 0.08, 0.4)
        _garnish(r)

    def kavurma(r):
        _spill(L.make_mat("Kavurma", KAVURMA, rough=0.3), r, 18, 0.12, 0.85)
        _garnish(r)

    def kofte(r):
        _spill(L.make_mat("CigKofte", COGKOFTE, rough=0.75), r, 20, 0.11, 0.9)
        leaf = L.make_mat("Marul", (0.30, 0.62, 0.16), rough=0.45)
        for _ in range(6):
            a = r.uniform(0, math.tau)
            rr = r.uniform(0.15, 0.36)
            L.sphere(_end_pt(r.uniform(0.0, 0.2), rr * math.cos(a), rr * math.sin(a)), 0.13, (0.4, 1.4, 1.0), leaf, seg=10, rings=6)

    def fries(r):
        potato = L.make_mat("Patates", (0.95, 0.74, 0.28), rough=0.6)
        egg = L.make_mat("Patlican", (0.22, 0.08, 0.20), rough=0.35)
        pep = L.make_mat("Biber", (0.25, 0.55, 0.15), rough=0.4)
        for i in range(14):
            a = r.uniform(0, math.tau)
            rr = math.sqrt(r.random()) * 0.28
            p = _end_pt(r.uniform(0.0, 0.3), rr * math.cos(a), rr * math.sin(a))
            if i % 5 == 4:
                L.cylinder(p, 0.12, 0.05, egg, rot=(r.uniform(0, 60), 90, math.degrees(YAW)), verts=14, name="Patlican")
            elif i % 5 == 3:
                L.sphere(p, 0.08, (2.4, 0.8, 0.8), pep, rot=(0, 0, r.uniform(0, 180)), seg=10, rings=6, name="Biber")
            else:
                L.cube(p, (0.42, 0.08, 0.08), potato, rot=(r.uniform(-20, 20), r.uniform(-30, 30), r.uniform(0, 120)), bevel=0.01, name="Patates")
        _garnish(r)

    _durum(out, "durum_doner", doner)
    _durum(out, "durum_kavurma", kavurma)
    _durum(out, "durum_cigkofte", kofte)
    _durum(out, "durum_kizartma", fries)

    def plain(r):  # nohut dürümü: sıcak nohut + piyaz
        nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.5, sss=0.25)
        _spill(nohut, r, 22, 0.075, 1.0)
        _garnish(r)

    _durum(out, "durum", plain)


# ------------------------------------------------------------------ bahşiş kavanozu
def build_jar(out):
    for level, coins in ((0, 6), (1, 26), (2, 56)):
        L.reset_scene()
        L.setup_camera(elev_deg=16, dist=12, ortho_scale=2.6, target=(0, 0, 0.78))
        _lights(3.2)
        _catcher()
        glass = L.make_mat("Cam", (0.85, 0.92, 0.95), rough=0.05)
        b = glass.node_tree.nodes["Principled BSDF"]
        if "Transmission Weight" in b.inputs:
            b.inputs["Transmission Weight"].default_value = 0.92
            b.inputs["IOR"].default_value = 1.45
        gold = L.make_mat("Para", (0.95, 0.72, 0.18), rough=0.25, metal=1.0)
        silver = L.make_mat("Gumus", (0.85, 0.87, 0.9), rough=0.3, metal=1.0)
        rnd = random.Random(33 + level)
        # paralar (kavanozun içinde, yığın)
        for i in range(coins):
            h = 0.06 + 0.035 * i * (1.0 if level == 0 else 0.55)
            x, y = rnd.uniform(-0.28, 0.28), rnd.uniform(-0.22, 0.22)
            L.cylinder((x, y, min(h, 1.1)), 0.13, 0.03, gold if i % 3 else silver, rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), 0), verts=20, name="Para")
        L.cylinder((0, 0, 0.62), 0.5, 1.24, glass, verts=48, name="Kavanoz")
        capm = L.make_mat("KavanozKapak", (0.75, 0.18, 0.12), rough=0.4)
        L.cylinder((0, 0, 1.3), 0.52, 0.14, capm, verts=48, name="KapakUst")
        L.cube((0, 0, 1.36), (0.34, 0.06, 0.04), L.make_mat("Yarik", (0.05, 0.03, 0.03), rough=0.5), name="Yarik")
        L.cylinder((0, 0, 0.58), 0.515, 0.34, L.make_mat("BahsisBant", (0.95, 0.85, 0.55), rough=0.7), verts=48, name="Bant")
        L.render(f"{out}/bahsis_{level}.png", 384, 480)


def build_all(out):
    build_tencere(out)
    build_trays(out)
    build_bottles(out)
    build_board_layers(out)
    build_beyran(out)
    build_wraps(out)
    build_jar(out)


def build_bowlstack(out):
    """Beyran için kâse yığını (ekmek yığınının karşılığı): tepsi üstünde 2 yığın içi boş kâse."""
    L.reset_scene()
    L.setup_camera(elev_deg=50, dist=14, ortho_scale=4.4, target=(0, 0, 0.3))
    _lights(3.0)
    _catcher()
    cer = L.make_mat("BeyranKase", (0.93, 0.90, 0.80), rough=0.28)
    trim = L.make_mat("BeyranKenar", (0.12, 0.30, 0.42), rough=0.3)
    s = steel()
    L.cube((0, 0, 0.04), (3.7, 2.5, 0.08), s, bevel=0.03, name="Tepsi")
    for dx in (-0.85, 0.85):
        for k in range(3):
            z = 0.55 + 0.2 * k
            _hollow_bowl(cer, r=0.8, h=z, loc=(dx, 0.0), thickness=0.06)
            L.torus((dx, 0.0, z), major=0.795, minor=0.03, mat=trim, name="KaseKenar")
    L.render(f"{out}/kase_yigin.png", 640, 512)
