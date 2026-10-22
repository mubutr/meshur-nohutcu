"""Uygulama simgesi için kahraman görsel: açık ucundan nohut, maydanoz ve soğan taşan dürüm.

blender -b -P tools/blender/build_assets.py -- <çıktı_klasörü> icon
Çıktı: icon_durum.png (şeffaf zemin, gölge yakalayıcılı). Simge kompozisyonu tools/make_icons.py içindedir.
"""
import math
import random

import bpy
from mathutils import Vector

import bl_lib as L
from items import NOHUT_COL, _bread, _catcher

RES = 1200


def build_icon(out):
    """İki geçiş: gölgeli (icon_durum.png) ve yalnız nesne (icon_durum_temiz.png; simgede kendi gölgemizi çizeriz)."""
    _build(out, "icon_durum_temiz.png", shadow=False)


def _build(out, name, shadow):
    L.reset_scene()
    target = Vector((0.45, 0.1, 0.45))
    cam = L.setup_camera(elev_deg=24, dist=14, ortho_scale=3.3, target=tuple(target))
    # kamera +x tarafına (açık uca) kayar: setup_camera'nın azim işareti farklı olduğundan elle konumlanır
    el, az, dist = math.radians(30), math.radians(66), 14
    cam.location = target + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
    L.aim(cam, tuple(target))
    L.add_sun(rot_deg=(52, 0, -35), strength=3.6, color=(1, 0.92, 0.8))
    L.add_area((3.5, -4, 5), size=5, energy=90, color=(1, 0.95, 0.88), look_at=(0, 0, 0.4))
    L.add_area((-4, 3, 3), size=5, energy=40, color=(0.9, 0.93, 1), look_at=(0, 0, 0.4))
    if shadow:
        _catcher(z=0.0, size=20)

    bread = L.bread_material()
    paper = L.make_mat("Kagit", (0.97, 0.95, 0.9), rough=0.9, bump=("fine", 14, 0.25))
    yaw = 18
    # ekmek tüpü: kâğıttan taşan uç daha uzun; dolgu ağızdan kabarır
    L.cylinder((0, 0, 0.42), 0.42, 2.1, bread, rot=(0, 90, yaw), name="Durum")
    L.cylinder((-0.52, -0.16, 0.42), 0.455, 1.1, paper, rot=(0, 90, yaw), name="Kagit")

    rnd = random.Random(7)
    nohut = L.make_mat("Nohut", NOHUT_COL, rough=0.45, sss=0.3)
    ya = math.radians(yaw)
    axis = Vector((math.cos(ya), math.sin(ya), 0))
    side = Vector((-math.sin(ya), math.cos(ya), 0))
    up = Vector((0, 0, 1))
    end = axis * 1.05 + Vector((0, 0, 0.42))  # tüpün açık ucunun merkezi

    # ağızdan taşan dolgu: uç diskini dolduran ve dışarı kabaran nohut kümesi
    pts = []
    for _ in range(70):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * 0.36
        pts.append(end + side * (r * math.cos(a)) + up * (r * math.sin(a)) + axis * rnd.uniform(0.0, 0.34 * (1 - r / 0.45)))
    L.blob_cloud("Dolgu", pts, nohut, radius=0.115, jitter=0.1, seed=11)

    green = L.make_mat("Maydanoz", (0.16, 0.5, 0.12), rough=0.55)
    onion = L.make_mat("Sogan", (0.78, 0.34, 0.52), rough=0.45)
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.12, 0.36)
        pos = end + side * (r * math.cos(a)) + up * (r * math.sin(a)) + axis * rnd.uniform(0.18, 0.4)
        L.sphere(tuple(pos), 0.055, (1, 1.8, 0.45), green, seg=8, rings=6, rot=(rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3)))
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.1, 0.34)
        pos = end + side * (r * math.cos(a)) + up * (r * math.sin(a)) + axis * rnd.uniform(0.2, 0.42)
        L.torus(tuple(pos), 0.08, 0.018, onion, rot=(rnd.uniform(0, 180), rnd.uniform(0, 180), rnd.uniform(0, 180)))

    # önde dökülmüş birkaç nohut
    for (x, y) in ((1.25, -0.2), (0.95, -0.45), (1.55, 0.05), (0.7, -0.62), (1.7, -0.3), (1.35, -0.58)):
        L.sphere((x, y, 0.085), 0.085, (1, 1, 0.95), nohut, seg=16, rings=10, rot=(0, 0, rnd.uniform(0, 3)))

    L.render(f"{out}/{name}", RES, RES, samples=110)
