"""Yemek varlıkları: tırnaklı ekmek, nohut/piyaz/acı kâseleri, katman (overlay) sprite'ları, dürüm."""
import math
import random

import bpy
from mathutils import Vector

import bl_lib as L

# Tahta üstü çerçevesi: ekmek ve tüm katmanlar AYNI kamera/çözünürlükle render edilir.
BOARD_RES = 768
BOARD_CAM = dict(elev_deg=52, dist=14, ortho_scale=4.6, target=(0, 0, 0.05))

NOHUT_COL = (0.86, 0.60, 0.26)


def _lights(strength=2.1):
    L.add_sun(rot_deg=(48, 0, 28), strength=strength, color=(1, 0.93, 0.82))
    L.add_area((-3, -4, 6), size=5, energy=70, color=(1, 0.95, 0.9), look_at=(0, 0, 0))
    L.add_area((4, 3, 4), size=4, energy=30, color=(0.85, 0.92, 1), look_at=(0, 0, 0))


def _catcher(z=-0.01, size=14):
    p = L.plane((0, 0, z), (size, size))
    p.is_shadow_catcher = True
    return p


def _bread(loc=(0, 0, 0), yaw=0, stretch=1.0, name="Ekmek"):
    """Uzun oval, kenarı kabarık, yüzeyi parmak izli tırnaklı ekmek."""
    mat = L.bread_material()
    o = L.sphere(loc, 1.0, (1.55 * stretch, 0.98, 0.075), mat, seg=96, rings=40, rot=(0, 0, yaw), name=name)
    # Kenar kabarıklığı: üst yüzü hafif çukurlaştır
    me = o.data
    seed = sum(ord(c) for c in name)
    ph = (seed % 7) * 0.9
    for v in me.vertices:
        x, y = v.co.x, v.co.y            # birim küre koordinatları
        r2 = x * x + y * y
        if v.co.z > 0:
            v.co.z *= 0.55 + 0.9 * min(1.0, r2) ** 2.2
        # düzensiz el yapımı kenar + bir ucu hafif dar
        th = math.atan2(y, x)
        wob = 1 + 0.045 * math.sin(3 * th + ph) + 0.03 * math.sin(5 * th + 2 * ph)
        v.co.x = x * wob
        v.co.y = y * wob * (1 - 0.16 * x)
    me.update()
    sub = o.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 2
    return o


def board_scene(bread=True):
    L.reset_scene()
    L.setup_camera(**BOARD_CAM)
    _lights()
    _catcher()
    if bread:
        _bread(yaw=0)


def build_bread(out):
    board_scene(bread=True)
    L.render(f"{out}/ekmek.png", BOARD_RES, BOARD_RES)


def _topping_layer(name, n, rx, ry, rnd, mat, radius, hmax, z=0.075, min_dist=0.11, jitter=0.18):
    pts = L.scatter_disc(n, rx, ry, rnd, min_dist=min_dist, z=z, hmax=hmax)
    return L.blob_cloud(name, pts, mat, radius=radius, jitter=jitter, seed=rnd.randint(0, 9999))


def build_toppings(out):
    """Nohut (3 seviye), piyaz ve acı katmanları — ekmek gizli, yalnız katman + gölge."""
    for lvl, count in ((1, 22), (2, 44), (3, 70)):
        board_scene(bread=False)
        nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.5, sss=0.25, bump=("fine", 38, 0.15))
        rnd = random.Random(10 + lvl)
        # Nohut ekmeğin orta şeridine dizilir
        pts = L.scatter_disc(count, 1.05 + 0.1 * lvl, 0.42 + 0.06 * lvl, rnd, min_dist=0.135,
                             z=0.12, hmax=0.05 + 0.03 * lvl)
        L.blob_cloud("Nohut", pts, nohut, radius=0.075, jitter=0.12, seed=lvl)
        L.render(f"{out}/top_nohut_{lvl}.png", BOARD_RES, BOARD_RES)

    # Piyaz: ince soğan hilalleri + maydanoz + sumak kırmızısı
    board_scene(bread=False)
    rnd = random.Random(77)
    onion = L.make_mat("Sogan", (0.93, 0.72, 0.80), rough=0.35, sss=0.4)
    parsley = L.make_mat("Maydanoz", (0.18, 0.5, 0.14), rough=0.55)
    sumak = L.make_mat("Domates", (0.8, 0.12, 0.06), rough=0.4)
    for i in range(46):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        x, y = r * math.cos(a) * 1.15, r * math.sin(a) * 0.5
        h = 0.2 + 0.05 * (1 - r * r) + rnd.uniform(0, 0.04)
        L.torus((x, y, h), major=0.11, minor=0.012, mat=onion,
                rot=(rnd.uniform(0, 80), rnd.uniform(0, 80), rnd.uniform(0, 360)),
                scale=(1, rnd.uniform(0.6, 1), 1))
    for i in range(55):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        x, y = r * math.cos(a) * 1.2, r * math.sin(a) * 0.55
        L.sphere((x, y, 0.22 + rnd.uniform(0, 0.05)), 0.05, (rnd.uniform(1, 2.2), 1, 0.35), parsley, seg=10,
                 rings=6, rot=(0, 0, rnd.uniform(0, 360)))
    for i in range(14):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        L.sphere((r * math.cos(a) * 1.1, r * math.sin(a) * 0.5, 0.22), 0.045, (1.3, 1, 0.5), sumak, seg=8,
                 rings=6, rot=(0, 0, rnd.uniform(0, 360)))
    L.render(f"{out}/top_piyaz.png", BOARD_RES, BOARD_RES)

    # Acı: pul biber serpintisi
    board_scene(bread=False)
    rnd = random.Random(5)
    flake = L.make_mat("PulBiber", (0.62, 0.06, 0.02), rough=0.55, bump=("noise", 60, 0.3))
    pts = []
    for i in range(240):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        pts.append(Vector((r * math.cos(a) * 1.3, r * math.sin(a) * 0.6, 0.23 + rnd.uniform(0, 0.06))))
    L.blob_cloud("Acı", pts, flake, radius=0.026, jitter=0.4, seed=3, subdiv=1, flat=0.5)
    L.render(f"{out}/top_aci.png", BOARD_RES, BOARD_RES)


# ------------------------------------------------------------- kâse sprite'ları
def _bowl(mat_outer, mat_inner, r=1.0, h=0.55):
    """Yarım küre kâse: dış kabuk + iç yüzey."""
    outer = L.sphere((0, 0, h), r, (1, 1, 0.62), mat_outer, seg=64, rings=32)
    # alt yarıyı koru, üst yarıyı kes (kenara kadar)
    me = outer.data
    for v in me.vertices:
        if v.co.z > 0:
            v.co.z = 0
    me.update()
    outer.location.z = h
    sol = outer.modifiers.new("Sol", "SOLIDIFY")
    sol.thickness = -0.06
    sol.offset = 1
    return outer


def _prop_scene():
    L.reset_scene()
    L.setup_camera(elev_deg=50, dist=12, ortho_scale=3.0, target=(0, 0, 0.35))
    _lights(3.0)
    _catcher(-0.0)


def build_bowls(out):
    def steel_mat():
        return L.make_mat("Celik", (0.78, 0.8, 0.82), rough=0.25, metal=1.0)

    # Nohut kâsesi
    _prop_scene()
    steel = steel_mat()
    _bowl(steel, steel)
    rnd = random.Random(3)
    nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.5, sss=0.25, bump=("fine", 38, 0.15))
    pts = L.scatter_disc(130, 0.82, 0.82, rnd, min_dist=0.13, z=0.36, hmax=0.3)
    L.blob_cloud("Nohut", pts, nohut, radius=0.075, jitter=0.12, seed=5)
    L.render(f"{out}/nohut_kase.png", 512, 512)

    # Piyaz kâsesi
    _prop_scene()
    steel = steel_mat()
    _bowl(steel, steel)
    rnd = random.Random(8)
    onion = L.make_mat("Sogan", (0.93, 0.72, 0.80), rough=0.35, sss=0.4)
    parsley = L.make_mat("Maydanoz", (0.18, 0.5, 0.14), rough=0.55)
    for i in range(70):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * 0.85
        h = 0.38 + 0.18 * (1 - r * r) + rnd.uniform(0, 0.05)
        L.torus((r * math.cos(a), r * math.sin(a), h), major=0.12, minor=0.014, mat=onion,
                rot=(rnd.uniform(0, 80), rnd.uniform(0, 80), rnd.uniform(0, 360)))
    for i in range(80):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * 0.85
        L.sphere((r * math.cos(a), r * math.sin(a), 0.42 + 0.15 * (1 - r * r) + rnd.uniform(0, 0.05)), 0.055,
                 (rnd.uniform(1, 2.2), 1, 0.35), parsley, seg=10, rings=6, rot=(0, 0, rnd.uniform(0, 360)))
    L.render(f"{out}/piyaz_kase.png", 512, 512)

    # Acı (pul biber) kâsesi
    _prop_scene()
    ceramic = L.make_mat("Seramik", (0.92, 0.9, 0.84), rough=0.3)
    _bowl(ceramic, ceramic, r=0.8, h=0.45)
    rnd = random.Random(21)
    flake = L.make_mat("PulBiber", (0.62, 0.06, 0.02), rough=0.55, bump=("noise", 60, 0.3))
    pts = L.scatter_disc(420, 0.65, 0.65, rnd, min_dist=0.0, z=0.3, hmax=0.2, tries=1)
    L.blob_cloud("Acı", pts, flake, radius=0.03, jitter=0.4, seed=4, subdiv=1, flat=0.6)
    L.render(f"{out}/aci_kase.png", 512, 512)


def build_stack(out):
    """Ekmek yığını: tepsi üstünde 3 tırnaklı ekmek."""
    L.reset_scene()
    L.setup_camera(elev_deg=50, dist=14, ortho_scale=4.4, target=(0, 0, 0.2))
    _lights(3.0)
    _catcher()
    steel = L.make_mat("Celik", (0.78, 0.8, 0.82), rough=0.28, metal=1.0)
    L.cube((0, 0, 0.04), (3.7, 2.5, 0.08), steel, bevel=0.03, name="Tepsi")
    for i, (dx, dy, yaw, z) in enumerate(((0, 0, 4, 0.14), (0.05, 0.04, -7, 0.23), (-0.04, -0.02, 11, 0.32))):
        _bread(loc=(dx, dy, z), yaw=yaw, stretch=0.92, name=f"Ekmek{i}")
    L.render(f"{out}/ekmek_yigin.png", 640, 512)


def build_durum(out):
    """Kâğıda sarılı bitmiş dürüm."""
    L.reset_scene()
    L.setup_camera(elev_deg=42, dist=14, ortho_scale=3.6, target=(0, 0, 0.3))
    _lights(3.2)
    _catcher()
    bread = L.bread_material()
    paper = L.make_mat("Kagit", (0.95, 0.93, 0.88), rough=0.9, bump=("fine", 14, 0.25))
    tube = L.cylinder((0, 0, 0.42), 0.40, 2.0, bread, rot=(0, 90, 18), name="Durum")
    tube.scale = (1, 1, 1)
    # Üst ucu hafif yuvarlat
    sleeve = L.cylinder((-0.46, -0.13, 0.42), 0.43, 1.05, paper, rot=(0, 90, 18), name="Kagit")
    # Açık uçta görünen nohut + piyaz
    rnd = random.Random(2)
    nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.5, sss=0.25)
    cx, cy = 0.95, 0.31
    pts = []
    for i in range(14):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * 0.26
        pts.append(Vector((cx + 0.03 + rnd.uniform(0, 0.06), cy + r * math.cos(a) * 0.35, 0.42 + r * math.sin(a))))
    L.blob_cloud("Dolgu", pts, nohut, radius=0.085, jitter=0.1, seed=9)
    green = L.make_mat("Maydanoz", (0.18, 0.5, 0.14), rough=0.55)
    red = L.make_mat("Pul", (0.7, 0.08, 0.03), rough=0.5)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        L.sphere((cx + 0.08, cy + 0.08 * math.cos(a), 0.42 + 0.2 * math.sin(a)), 0.04, (1, 1.6, 0.4), green, seg=8,
                 rings=6)
    for i in range(6):
        a = rnd.uniform(0, math.tau)
        L.sphere((cx + 0.09, cy + 0.07 * math.cos(a), 0.42 + 0.22 * math.sin(a)), 0.03, (1, 1.2, 0.5), red, seg=8,
                 rings=6)
    L.render(f"{out}/durum.png", 640, 480)


def build_sumak(out):
    """Sumak: kâse + ekmek üstü serpinti katmanı (koyu bordo toz)."""
    sumak_col = (0.42, 0.06, 0.10)
    # katman
    board_scene(bread=False)
    rnd = random.Random(31)
    dust = L.make_mat("Sumak", sumak_col, rough=0.9, bump=("noise", 80, 0.25))
    pts = []
    for i in range(520):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        pts.append(Vector((r * math.cos(a) * 1.3, r * math.sin(a) * 0.58, 0.22 + rnd.uniform(0, 0.05))))
    L.blob_cloud("Sumak", pts, dust, radius=0.022, jitter=0.5, seed=8, subdiv=1, flat=0.55)
    L.render(f"{out}/top_sumak.png", BOARD_RES, BOARD_RES)
    # kâse
    _prop_scene()
    ceramic = L.make_mat("Seramik2", (0.30, 0.45, 0.62), rough=0.3)
    _bowl(ceramic, ceramic, r=0.8, h=0.45)
    rnd = random.Random(33)
    dust = L.make_mat("Sumak", sumak_col, rough=0.9, bump=("noise", 80, 0.25))
    pts = L.scatter_disc(520, 0.66, 0.66, rnd, min_dist=0.0, z=0.3, hmax=0.2, tries=1)
    L.blob_cloud("Sumak", pts, dust, radius=0.028, jitter=0.45, seed=6, subdiv=1, flat=0.6)
    L.render(f"{out}/sumak_kase.png", 512, 512)


def build_all(out):
    build_sumak(out)
    build_bread(out)
    build_toppings(out)
    build_bowls(out)
    build_stack(out)
    build_durum(out)
