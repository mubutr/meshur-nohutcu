"""Ortak Blender yardımcıları (Blender 5.x, arka planda çalışır: blender -b -P ...).

Tüm sanat bu betiklerle sıfırdan üretilir; harici model/doku kullanılmaz.
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector


# --------------------------------------------------------------------- sahne
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 6
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    set_world((0.62, 0.66, 0.74), 0.32)
    return scn


def set_world(color, strength):
    scn = bpy.context.scene
    if scn.world is None:
        scn.world = bpy.data.worlds.new("World")
    w = scn.world
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*color, 1)
    bg.inputs["Strength"].default_value = strength


def setup_camera(elev_deg=48, dist=12, ortho_scale=4.0, target=(0, 0, 0), azim_deg=0):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam_data.clip_start = 0.1
    cam_data.clip_end = 100
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    th = math.radians(90 - elev_deg)  # Blender X dönüşü
    az = math.radians(azim_deg)
    d = Vector((math.sin(az) * math.sin(th), math.cos(az) * math.sin(th), -math.cos(th)))
    cam.location = Vector(target) - d * dist
    cam.rotation_euler = Euler((th, 0, az), "XYZ")
    bpy.context.scene.camera = cam
    return cam


def add_sun(rot_deg=(50, 0, 25), strength=3.5, color=(1, 0.95, 0.88), angle_deg=6):
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy = strength
    d.color = color
    d.angle = math.radians(angle_deg)
    o = bpy.data.objects.new("Sun", d)
    o.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    bpy.context.scene.collection.objects.link(o)
    return o


def add_area(loc, size=4, energy=200, color=(1, 1, 1), look_at=(0, 0, 0)):
    d = bpy.data.lights.new("Area", "AREA")
    d.energy = energy
    d.size = size
    d.color = color
    o = bpy.data.objects.new("Area", d)
    o.location = loc
    bpy.context.scene.collection.objects.link(o)
    aim(o, look_at)
    return o


def add_point(loc, energy=300, color=(1, 0.6, 0.3), radius=0.3):
    d = bpy.data.lights.new("Pt", "POINT")
    d.energy = energy
    d.color = color
    d.shadow_soft_size = radius
    o = bpy.data.objects.new("Pt", d)
    o.location = loc
    bpy.context.scene.collection.objects.link(o)
    return o


def aim(obj, target):
    dirv = Vector(target) - Vector(obj.location)
    obj.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()


def render(path, w, h, samples=None):
    scn = bpy.context.scene
    scn.render.resolution_x = w
    scn.render.resolution_y = h
    scn.render.resolution_percentage = 100
    if samples:
        scn.cycles.samples = samples
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ malzeme
def make_mat(name, color, rough=0.6, metal=0.0, emission=None, em_strength=0.0, sss=0.0, bump=None):
    """bump = (tür, ölçek, güç)  tür: 'noise' | 'voronoi' | 'fine'"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if sss and "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = (0.6, 0.35, 0.2)
        bsdf.inputs["Subsurface Scale"].default_value = 0.08
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = em_strength
    if bump:
        kind, scale, strength = bump
        if kind == "voronoi":
            tex = nt.nodes.new("ShaderNodeTexVoronoi")
            tex.inputs["Scale"].default_value = scale
            out = tex.outputs["Distance"]
        else:
            tex = nt.nodes.new("ShaderNodeTexNoise")
            tex.inputs["Scale"].default_value = scale
            tex.inputs["Detail"].default_value = 8 if kind == "fine" else 4
            out = tex.outputs["Fac"]
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = strength
        nt.links.new(out, b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def bread_material():
    """Tırnaklı ekmek: altın kabuk, çukurlarda koyu kavrulma, kabarık kenar."""
    m = bpy.data.materials.new("Ekmek")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.72
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 17.0
    vor.inputs["Randomness"].default_value = 0.85
    vor.feature = "F1"
    nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.0
    noise.inputs["Detail"].default_value = 5
    nt.links.new(tc.outputs["Generated"], noise.inputs["Vector"])
    # çukur (koyu kavrulma) -> kabuk (altın)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.06
    ramp.color_ramp.elements[0].color = (0.62, 0.36, 0.14, 1)
    ramp.color_ramp.elements[1].position = 0.40
    ramp.color_ramp.elements[1].color = (1.0, 0.90, 0.64, 1)
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    # geniş leke: kabuğun rengi yer yer açılıp koyulaşır
    tone = nt.nodes.new("ShaderNodeValToRGB")
    tone.color_ramp.elements[0].position = 0.35
    tone.color_ramp.elements[0].color = (0.92, 0.88, 0.82, 1)
    tone.color_ramp.elements[1].position = 0.65
    tone.color_ramp.elements[1].color = (1.15, 1.1, 1.0, 1)
    nt.links.new(noise.outputs["Fac"], tone.inputs["Fac"])
    m1 = nt.nodes.new("ShaderNodeMix")
    m1.data_type = "RGBA"
    m1.blend_type = "MULTIPLY"
    m1.inputs[0].default_value = 1.0
    nt.links.new(ramp.outputs["Color"], m1.inputs["A"])
    nt.links.new(tone.outputs["Color"], m1.inputs["B"])
    # kenar kızarması: merkezden uzaklaştıkça koyulaşır
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (-0.5, -0.5, 0)
    mp.inputs["Scale"].default_value = (2, 2, 2)
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    nt.links.new(mp.outputs["Vector"], grad.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeValToRGB")
    edge.color_ramp.elements[0].position = 0.0
    edge.color_ramp.elements[0].color = (0.80, 0.52, 0.26, 1)
    edge.color_ramp.elements[1].position = 0.22
    edge.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(grad.outputs["Fac"], edge.inputs["Fac"])
    m2 = nt.nodes.new("ShaderNodeMix")
    m2.data_type = "RGBA"
    m2.blend_type = "MULTIPLY"
    m2.inputs[0].default_value = 1.0
    nt.links.new(m1.outputs["Result"], m2.inputs["A"])
    nt.links.new(edge.outputs["Color"], m2.inputs["B"])
    nt.links.new(m2.outputs["Result"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.2
    bump.inputs["Distance"].default_value = 0.05
    nt.links.new(vor.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# ----------------------------------------------------------------- geometri
def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def smooth(obj):
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.update()


def sphere(loc, r=1.0, scale=(1, 1, 1), mat=None, seg=32, rings=16, rot=(0, 0, 0), name="Sph"):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    smooth(o)
    if mat:
        assign(o, mat)
    return o


def cylinder(loc, r=1.0, depth=2.0, mat=None, rot=(0, 0, 0), verts=48, name="Cyl", scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    o.scale = scale
    smooth(o)
    if mat:
        assign(o, mat)
    return o


def cube(loc, size=(1, 1, 1), mat=None, rot=(0, 0, 0), name="Cube", bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    if bevel:
        bm = o.modifiers.new("Bevel", "BEVEL")
        bm.width = bevel
        bm.segments = 3
    if mat:
        assign(o, mat)
    return o


def plane(loc, size=(10, 10), mat=None, rot=(0, 0, 0), name="Plane"):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], 1)
    o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    if mat:
        assign(o, mat)
    return o


def torus(loc, major=1.0, minor=0.1, mat=None, rot=(0, 0, 0), name="Tor", scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    o.scale = scale
    smooth(o)
    if mat:
        assign(o, mat)
    return o


def blob_cloud(name, positions, mat, radius=0.07, jitter=0.15, seed=1, subdiv=2, flat=1.0):
    """Çok sayıda küçük küreyi (nohut, kırıntı…) tek mesh olarak üretir."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    for p in positions:
        s = radius * (1 + rnd.uniform(-jitter, jitter))
        sx, sy, sz = (1 + rnd.uniform(-jitter, jitter) for _ in range(3))
        rx, ry, rz = (rnd.uniform(0, math.tau) for _ in range(3))
        m = (Matrix.Translation(p) @ Euler((rx, ry, rz)).to_matrix().to_4x4()
             @ Matrix.Diagonal((sx * s, sy * s, sz * s * flat, 1)))
        ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        bmesh.ops.transform(bm, matrix=m, verts=ret["verts"])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    smooth(o)
    assign(o, mat)
    return o


def scatter_disc(n, rx, ry, rnd, min_dist=0.0, z=0.0, hmax=0.0, tries=60):
    """Elips içinde n nokta (yaklaşık Poisson); yığın yüksekliği hmax merkeze doğru artar."""
    pts = []
    for _ in range(n * tries):
        if len(pts) >= n:
            break
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random())
        x, y = r * math.cos(a) * rx, r * math.sin(a) * ry
        if any((x - px) ** 2 + (y - py) ** 2 < min_dist ** 2 for px, py, _ in pts):
            continue
        h = z + hmax * (1 - r * r) + rnd.uniform(0, 0.02)
        pts.append((x, y, h))
    return [Vector(p) for p in pts]


def look_dir(rot_deg):
    return Euler([math.radians(a) for a in rot_deg], "XYZ")
