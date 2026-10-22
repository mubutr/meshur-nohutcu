"""Restoran arka planı (bg_restoran.png) ve ön tezgâh katmanı (tezgah_on.png). Aynı kamera: kayıt (registration) birebir."""
import math
import random

import bpy

import bl_lib as L

W, H = 1600, 900
CAM = dict(elev_deg=7, dist=40, ortho_scale=16.0, target=(0, 0, 4.4))


def _apply(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def _wall(loc, size, mat, rot=(90, 0, 0)):
    p = L.plane(loc, size, mat, rot=rot)
    _apply(p)
    return p


def brick_material(name, c1, c2, mortar, scale=3.2, bw=0.5, rh=0.2, xz=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = (*c1, 1)
    br.inputs["Color2"].default_value = (*c2, 1)
    br.inputs["Mortar"].default_value = (*mortar, 1)
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = 0.025
    br.inputs["Brick Width"].default_value = bw
    br.inputs["Row Height"].default_value = rh
    br.inputs["Bias"].default_value = 0.0
    if xz:  # duvar XZ düzleminde: desen (x, z) koordinatlarından okunur
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        comb = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        nt.links.new(sep.outputs["X"], comb.inputs["X"])
        nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
        nt.links.new(comb.outputs["Vector"], br.inputs["Vector"])
    else:
        nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.7
    bump.inputs["Distance"].default_value = 0.03
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def checker_material(name, c1, c2, scale=6.0, rough=0.35):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ck = nt.nodes.new("ShaderNodeTexChecker")
    ck.inputs["Color1"].default_value = (*c1, 1)
    ck.inputs["Color2"].default_value = (*c2, 1)
    ck.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], ck.inputs["Vector"])
    nt.links.new(ck.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _base():
    L.reset_scene()
    L.set_world((0.8, 0.75, 0.68), 0.22)
    L.setup_camera(**CAM)
    L.add_sun(rot_deg=(58, 8, -30), strength=1.25, color=(1, 0.92, 0.8))
    L.add_area((0, -9, 9), size=14, energy=230, color=(1, 0.93, 0.85), look_at=(0, 2, 3.5))


# ------------------------------------------------------------------ temalar (bölümle lüksleşir)
# Aynı kamera ve yerleşim; yalnız malzeme, ışık ve mobilya değişir -> dekor katmanları ortak kalır.
THEMES = {
    "t1": dict(title="Mahalle Esnafı", world=(0.66, 0.68, 0.70), sky_light=1.0),
    "t2": dict(title="Çarşı Lokantası", world=(0.80, 0.75, 0.68), sky_light=1.0),
    "t3": dict(title="Lokanta", world=(0.82, 0.72, 0.60), sky_light=1.0),
    "t4": dict(title="Saray Sofrası", world=(0.78, 0.72, 0.62), sky_light=1.0),
}

# pencere deliği (gökyüzü Flutter'da çizilir; duvar burada kesilir)
HOLE = (3.65, 6.75, 4.75, 7.25)  # x0, x1, z0, z1


def _wall_rects(z0, z1):
    hx0, hx1, hz0, hz1 = HOLE
    rects = [(-11, hx0, z0, z1), (hx1, 11, z0, z1)]
    lo, hi = max(z0, 0), z1
    if lo < hz0:
        rects.append((hx0, hx1, lo, min(hz0, hi)))
    if hi > hz1:
        rects.append((hx0, hx1, max(hz1, lo), hi))
    return [r for r in rects if r[1] > r[0] and r[3] > r[2]]


def _wall_mesh(name, rects, mat, y=3.0):
    """Duvarı dünya koordinatlı dörtgenlerle kurar (malzeme 'Object' koordinatı dikişsiz sürer)."""
    import bmesh
    bm = bmesh.new()
    for (x0, x1, z0, z1) in rects:
        vs = [bm.verts.new(v) for v in ((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1))]
        bm.faces.new(vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def _lamp_pendant(x, mat_emit, dark, shade=None, gold=None):
    L.cylinder((x, 1.6, 8.4), 0.015, 1.4, dark, name="Ip")
    if shade is not None:  # bakır/altın başlık
        L.sphere((x, 1.6, 7.62), 0.4, (1, 1, 0.75), shade, seg=28, rings=12, name="Baslik")
    L.sphere((x, 1.6, 7.52), 0.34, (1, 1, 1.15), mat_emit, seg=24, rings=12, name="Lamba")


def build_background(out, theme="t2"):
    th = THEMES[theme]
    _base()
    L.set_world(th["world"], 0.22)
    wood = L.make_mat("Ahsap", (0.42, 0.24, 0.11), rough=0.6, bump=("fine", 30, 0.3))
    dark = L.make_mat("Kor", (0.02, 0.01, 0.01), rough=1.0)
    copper = L.make_mat("Bakir", (0.85, 0.42, 0.22), rough=0.28, metal=1.0)
    gold = L.make_mat("Altin", (0.88, 0.66, 0.2), rough=0.22, metal=1.0)
    steel = L.make_mat("Celik", (0.74, 0.76, 0.78), rough=0.3, metal=1.0, bump=("fine", 120, 0.05))
    plaster = L.make_mat("Siva", (0.93, 0.86, 0.74), rough=0.95, bump=("noise", 6, 0.08))

    # zemin / duvar malzemeleri
    if theme == "t1":
        floor = checker_material("Zemin", (0.58, 0.60, 0.61), (0.84, 0.85, 0.85), scale=1.8, rough=0.18)
        lower = brick_material("Fayans", (0.93, 0.94, 0.93), (0.89, 0.91, 0.9), (0.62, 0.65, 0.66), scale=4.2, bw=0.4, rh=0.25, xz=True)
        upper = L.make_mat("Boya", (0.74, 0.88, 0.82), rough=0.8, bump=("noise", 6, 0.05))
        trim = steel
        frame = L.make_mat("Alu", (0.85, 0.86, 0.88), rough=0.35, metal=0.6)
    elif theme == "t2":
        floor = checker_material("Zemin", (0.74, 0.4, 0.28), (0.9, 0.82, 0.68), scale=1.4)
        lower = brick_material("Tugla", (0.7, 0.38, 0.27), (0.6, 0.3, 0.2), (0.88, 0.8, 0.68), scale=3.0, xz=True)
        upper = plaster
        trim = wood
        frame = wood
    elif theme == "t3":
        floor = checker_material("Zemin", (0.62, 0.32, 0.2), (0.82, 0.55, 0.38), scale=1.1, rough=0.45)
        lower = brick_material("TasBlok", (0.86, 0.73, 0.52), (0.78, 0.64, 0.44), (0.66, 0.56, 0.42), scale=2.0, bw=0.9, rh=0.38, xz=True)
        upper = L.make_mat("SivaSicak", (0.96, 0.82, 0.58), rough=0.95, bump=("noise", 5, 0.1))
        trim = L.make_mat("Ceviz", (0.28, 0.15, 0.07), rough=0.55, bump=("fine", 30, 0.3))
        frame = trim
    else:
        floor = checker_material("Zemin", (0.04, 0.04, 0.05), (0.93, 0.92, 0.88), scale=1.6, rough=0.08)
        lower = L.make_mat("Kadife", (0.06, 0.26, 0.19), rough=0.7, bump=("fine", 140, 0.18))
        upper = L.make_mat("KremSiva", (0.96, 0.92, 0.82), rough=0.8, bump=("noise", 5, 0.05))
        trim = gold
        frame = gold

    _apply(L.plane((0, -3, 0), (22, 14), floor))
    _wall_mesh("DuvarAlt", _wall_rects(0, 5.4), lower)
    _wall_mesh("DuvarUst", _wall_rects(5.4, 9.0), upper)
    L.cube((0, 2.9, 5.45), (22, 0.15, 0.3), trim, name="Cita")
    L.cube((0, 2.9, 0.12), (22, 0.15, 0.25), trim, name="Supurgelik")
    if theme == "t4":
        L.cube((0, 2.9, 3.0), (22, 0.1, 0.07), gold, name="AltinSerit")
        L.cube((0, 2.9, 8.4), (22, 0.1, 0.07), gold, name="AltinSerit2")

    # taş fırın (sol)
    fire = L.make_mat("FirinTas", (0.55, 0.35, 0.25), rough=0.9, bump=("voronoi", 8, 0.5))
    if theme == "t4":
        fire = L.make_mat("FirinMermer", (0.82, 0.80, 0.76), rough=0.2, bump=("noise", 12, 0.06))
    L.cube((-4.7, 2.75, 3.0), (3.6, 0.9, 3.3), fire, name="FirinGovde", bevel=0.08)
    L.cube((-4.7, 2.28, 2.95), (2.3, 0.2, 1.55), dark, name="FirinAgiz", bevel=0.1)
    L.cube((-4.7, 2.17, 2.75), (2.0, 0.05, 0.9), emissive("Kor", (1.0, 0.36, 0.06), 3.2), name="Kor")
    L.cube((-4.7, 2.17, 3.35), (2.0, 0.05, 0.4), emissive("KorUst", (1.0, 0.55, 0.15), 2.2), name="KorUst")
    L.add_point((-4.7, 1.2, 2.9), energy=500, color=(1, 0.5, 0.2), radius=0.6)
    L.cube((-4.7, 2.7, 5.3), (1.2, 0.7, 1.4), L.make_mat("Baca", (0.5, 0.32, 0.23), rough=0.9), name="Baca")

    # pencere çerçevesi + dışarıdaki taş evler (gökyüzü deliği çerçevenin içinde şeffaf kalır)
    stone = L.make_mat("Tas", (0.88, 0.76, 0.58), rough=0.9, bump=("voronoi", 10, 0.3))
    for x, w, h in ((4.2, 0.9, 1.1), (5.0, 1.2, 1.7), (5.9, 0.8, 1.3)):
        L.cube((x, 2.9, 4.75 + h / 2 + 0.3), (w, 0.04, h), stone, name="Ev")
    for sx in (-1, 1):
        L.cube((5.2 + sx * 1.65, 2.82, 6.0), (0.22, 0.2, 2.9), frame, name="PencereKasa")
    L.cube((5.2, 2.82, 7.3), (3.5, 0.2, 0.22), frame, name="PencereUst")
    L.cube((5.2, 2.82, 4.7), (3.5, 0.28, 0.22), frame, name="PencereAlt")
    L.cube((5.2, 2.8, 6.0), (0.1, 0.12, 2.6), frame, name="PencereOrta")

    # raf + kavanozlar (+ tema süsleri)
    shelf = steel if theme == "t1" else (gold if theme == "t4" else wood)
    L.cube((0.4, 2.6, 4.3), (4.6, 0.7, 0.14), shelf, name="Raf", bevel=0.03)
    colors = [(0.8, 0.2, 0.1), (0.9, 0.75, 0.25), (0.35, 0.55, 0.2), (0.9, 0.9, 0.85), (0.6, 0.25, 0.1)]
    for i in range(7):
        c = colors[i % len(colors)]
        L.cylinder((-1.5 + i * 0.62, 2.6, 4.38 + 0.28), 0.2, 0.55, L.make_mat("Kavanoz", c, rough=0.3), verts=24, name="Kavanoz")
    if theme in ("t2", "t3", "t4"):
        tray_in = L.make_mat("Tabak", (0.9, 0.55, 0.3), rough=0.3, metal=1.0)
        plates = ((-0.6, 6.4, 0.55), (0.5, 6.7, 0.7), (1.7, 6.3, 0.5), (-2.0, 6.1, 0.45))
        if theme == "t3":
            plates += ((-3.0, 7.0, 0.4), (2.8, 6.9, 0.38))
        for x, z, r in plates:
            L.cylinder((x, 2.9, z), r, 0.06, copper if theme != "t4" else gold, rot=(90, 0, 0), name="BakirTabak")
            L.cylinder((x, 2.86, z), r * 0.62, 0.05, tray_in, rot=(90, 0, 0), name="BakirIc")
    else:
        # esnaf: duvarda fiyat/menü panoları
        board = L.make_mat("MenuPano", (0.96, 0.94, 0.88), rough=0.8)
        redm = L.make_mat("MenuKirmizi", (0.78, 0.12, 0.10), rough=0.7)
        for x in (-1.6, 0.5, 2.6):
            L.cube((x, 2.9, 6.4), (1.5, 0.05, 1.0), board, name="Menu")
            L.cube((x, 2.86, 6.78), (1.5, 0.04, 0.16), redm, name="MenuBas")
            for k in range(3):
                L.cube((x - 0.15, 2.86, 6.45 - k * 0.18), (0.9, 0.03, 0.05), dark, name="MenuSatir")

    # lambalar
    if theme == "t1":
        tube = emissive("Floresan", (0.92, 0.96, 1.0), 2.4)
        for x in (-2.0, 2.4):
            L.cylinder((x, 1.6, 7.9), 0.06, 2.2, tube, rot=(0, 90, 0), name="Floresan")
            L.cylinder((x, 1.6, 8.15), 0.012, 0.5, dark, name="Ip")
            L.add_point((x, 1.2, 7.7), energy=110, color=(0.9, 0.95, 1), radius=0.3)
    else:
        lamp = emissive("Lamba", (1.0, 0.8, 0.45), 2.6)
        shade = copper if theme == "t3" else (gold if theme == "t4" else None)
        for x in (-2.4, 2.8):
            _lamp_pendant(x, lamp, dark, shade)
            L.add_point((x, 1.2, 7.4), energy=260, color=(1, 0.78, 0.5), radius=0.2)
        if theme == "t4":
            for x in (-6.9, 7.1):  # duvar aplikleri
                L.sphere((x, 2.6, 6.1), 0.22, (1, 1, 1.4), emissive("Aplik", (1.0, 0.82, 0.5), 2.4), name="Aplik")
                L.cube((x, 2.8, 5.8), (0.3, 0.12, 0.08), gold, name="AplikTaban")
                L.add_point((x, 2.0, 6.1), energy=90, color=(1, 0.78, 0.5), radius=0.2)

    # tabela tahtası (yazı Flutter tarafından bindirilir)
    sign_frame = {"t1": steel, "t2": wood, "t3": trim, "t4": gold}[theme]
    sign_in = {"t1": (0.78, 0.12, 0.10), "t2": (0.14, 0.38, 0.33), "t3": (0.14, 0.34, 0.30), "t4": (0.05, 0.2, 0.15)}[theme]
    L.cube((0.3, 2.85, 7.7), (5.6, 0.12, 1.1), sign_frame, name="Tabela", bevel=0.06)
    L.cube((0.3, 2.78, 7.7), (5.3, 0.04, 0.85), L.make_mat("TabelaIc", sign_in, rough=0.7), name="TabelaIc")

    L.render(f"{out}/bg_{theme}.png", W, H, samples=64)


def _counter_materials(theme):
    if theme == "t1":
        top = L.make_mat("TezgahCelik", (0.76, 0.78, 0.8), rough=0.28, metal=1.0, bump=("fine", 160, 0.04))
        edge = L.make_mat("TezgahKenar", (0.62, 0.64, 0.66), rough=0.3, metal=1.0)
        tile = checker_material("Cini", (0.9, 0.92, 0.92), (0.78, 0.8, 0.82), scale=3.0, rough=0.2)
    elif theme == "t2":
        top = L.make_mat("TezgahTas", (0.9, 0.84, 0.72), rough=0.55, bump=("voronoi", 12, 0.18))
        edge = L.make_mat("Ahsap", (0.42, 0.24, 0.11), rough=0.6, bump=("fine", 30, 0.3))
        tile = checker_material("Cini", (0.12, 0.38, 0.42), (0.95, 0.93, 0.85), scale=2.4, rough=0.25)
    elif theme == "t3":
        top = L.make_mat("TezgahTas3", (0.84, 0.72, 0.52), rough=0.6, bump=("voronoi", 9, 0.22))
        edge = L.make_mat("Ceviz", (0.28, 0.15, 0.07), rough=0.5, bump=("fine", 30, 0.3))
        tile = checker_material("Cini", (0.16, 0.36, 0.34), (0.9, 0.78, 0.5), scale=2.0, rough=0.25)
    else:
        top = L.make_mat("TezgahMermer", (0.94, 0.93, 0.9), rough=0.12, bump=("noise", 7, 0.05))
        edge = L.make_mat("Altin", (0.88, 0.66, 0.2), rough=0.2, metal=1.0)
        tile = checker_material("Cini", (0.05, 0.2, 0.15), (0.9, 0.78, 0.4), scale=2.6, rough=0.2)
    return top, edge, tile


def build_counter(out, theme="t2"):
    th = THEMES[theme]
    _base()
    L.set_world(th["world"], 0.22)
    top, edge, tile = _counter_materials(theme)
    front = L.plane((0, -2.2, 1.25), (22, 2.5), tile, rot=(90, 0, 0))
    _apply(front)
    L.cube((0, -1.75, 2.6), (22, 1.5, 0.22), top, name="TezgahUst", bevel=0.05)
    L.cube((0, -2.3, 2.58), (22, 0.12, 0.26), edge, name="TezgahOn", bevel=0.03)
    L.cube((0, -2.25, 0.1), (22, 0.2, 0.2), edge, name="Sup")
    if theme == "t1":  # cam sıcak tutucu çerçevesi izi: ince çelik korkuluk
        L.cylinder((0, -2.36, 2.8), 0.04, 22, edge, rot=(0, 90, 0), name="Korkuluk", verts=12)
    if theme == "t3":
        copper = L.make_mat("Bakir", (0.85, 0.42, 0.22), rough=0.28, metal=1.0)
        L.cylinder((0, -2.36, 2.76), 0.035, 22, copper, rot=(0, 90, 0), name="BakirKorkuluk", verts=12)
    if theme == "t4":
        L.cube((0, -2.36, 2.72), (22, 0.04, 0.07), edge, name="AltinSerit")
    L.render(f"{out}/tezgah_{theme}.png", W, H, samples=48)


def build_theme(out, theme):
    build_background(out, theme)
    build_counter(out, theme)


def build_all(out):
    for t in THEMES:
        build_theme(out, t)
