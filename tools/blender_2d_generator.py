"""Kayıp Kuleler — Blender ile 2D görseller (birleştirme: tools/compose_2d.py, sistem python3 + Pillow) (tools/blender_scene_generator.py içinden çağrılır; Cycles CPU).

    build_icon()   art/icon-4096.png (kule + Robo + ışıyan hedef çipi, gün batımı gradyanı) → tools/make_icons.py
                   ile Godot / Android başlatıcı simgeleri (icon.png, launcher/icon_*.png, mipmap'ler)
    build_cmds()   godot-program/assets/ui/cmd_<C>.png  (F L R J A W 1 2 C; 160×160, şeffaf, beyaz kabartma)
    build_store()  store/feature_graphic.png (1024×500) — başlık dioraması + yazı
"""
import os
import sys
import math
import subprocess

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
GP = os.path.join(ROOT, "godot-program")
FONT = os.path.join(GP, "fonts", "Nunito.ttf")
import blender_asset_generator as A  # noqa: E402
import blender_scene_generator as S  # noqa: E402
from blender_asset_generator import mat, box, cyl, cone, torus, sphere, reset  # noqa: E402

def _import_glb(path, loc=(0, 0, 0), rot_z=0.0, scale=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location = mathutils.Vector(r.location) * scale + mathutils.Vector(loc)
        r.rotation_euler[2] += rot_z
        r.scale = mathutils.Vector(r.scale) * scale
    return new

# ---------------------------------------------------------------------------
def build_icon():
    """Marka: devre elemanlarından kule + Robo + tepede ışıyan hedef çipi."""
    reset()
    m = S.M()
    core = mat("CrystalCore", "#ffb23c", 0.1, 0.1, emission="#ff8a1f", strength=2.2)
    terra = mat("Terracotta", "#c8643c", 0.05, 0.55)
    terra2 = mat("TerracottaLight", "#e88a52", 0.05, 0.5)
    led = mat("TowerLED", "#6ff6ff", 0.0, 0.3, emission="#6ff6ff", strength=3.0)
    # kule: üç kat SMD gövdeli blok, sıcak terrakota tonları (eski simgenin rengi)
    floors = [((0, 0, 0), 1.9, 0.9), ((0, 0.9, 0), 1.45, 0.85), ((0, 1.75, 0), 1.05, 0.8)]
    for k, ((x, y, z), w, h) in enumerate(floors):
        box((x, y + h / 2, z), (w, h, w), terra if k % 2 == 0 else terra2, bevel=0.06)
        box((x, y + h - 0.02, z), (w * 0.84, 0.04, w * 0.84), m["epoxy"], bevel=0.01)
        n = max(3, int(w / 0.28))
        for i in range(n):
            t = -w / 2 + (i + 0.5) * w / n
            for sgn in (-1, 1):
                box((x + t, y + 0.18, z + sgn * (w / 2 + 0.04)), (0.1, 0.26, 0.08), m["tin"], bevel=0.015)
                box((x + sgn * (w / 2 + 0.04), y + 0.18, z + t), (0.08, 0.26, 0.1), m["tin"], bevel=0.015)
        box((x, y + h * 0.55, z + w / 2 + 0.005), (w * 0.5, 0.07, 0.01), led, bevel=0)
        box((x + w / 2 + 0.005, y + h * 0.55, z), (0.01, 0.07, w * 0.5), led, bevel=0)
    # tepede hedef: altın çip + ışıyan kristal
    box((0, 2.6, 0), (0.62, 0.1, 0.62), m["gold"], bevel=0.02)
    cone((0, 3.08, 0), 0.3, 0.0, 0.8, core, "y", 6)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.3, radius2=0.0, depth=0.36, location=A.G(0, 2.86, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, core, 0)
    torus((0, 2.95, 0), 0.48, 0.03, m["gold"], "x", 48, 8)
    # alt devre adası
    cyl((0, -0.1, 0), 1.55, 0.2, m["pcb"], "y", 64)
    torus((0, 0.0, 0), 1.53, 0.03, m["gold"], "y", 96, 6)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.45, radius2=0.12, depth=1.1, location=A.G(0, -0.75, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, mat("IslandRock", "#5a3e6e", 0.0, 0.85), 0)
    # Robo: önde, kuleye doğru bakarak selam verir (iskeletli modelin wave pozu)
    rb = os.path.join(GP, "assets", "models", "robot.glb")
    if os.path.exists(rb):
        objs = _import_glb(rb, loc=A.G(0.95, 0.0, 1.05), rot_z=0.35, scale=1.25)
        arm = [o for o in objs if o.type == "ARMATURE"]
        if arm and arm[0].animation_data:
            act = bpy.data.actions.get("wave")
            if act:
                arm[0].animation_data.action = act
                bpy.context.scene.frame_set(8)
    S._cycles(4096, 4096, samples=24, transparent=True)
    S._studio(target=(0.0, 0.0, 1.2), dist=12.0, elev=0.5, az=0.62, ortho=5.9)
    tmp = os.path.join(S.SCRATCH, "icon_subject.png")
    S._render(tmp)
    subprocess.run(["python3", os.path.join(HERE, "compose_2d.py"), "icon", tmp], check=True)
    return {"file": "art/icon-4096.png", "tris": 0, "budget": 0, "ok": True}

# ---------------------------------------------------------------------------
# komut ikonları: ön görünüşte (Godot x→sağ, y→yukarı; kamera +Z'den bakar) beyaz kabartma glifler
def _tube(points, r, m):
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, (x, y) in enumerate(points):
        sp.points[i].co = (*A.G(x, y, 0), 1.0)
    o = bpy.data.objects.new("tube", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o

def _head(x, y, ang, size, m):
    """Ok ucu: ang yönünü gösteren üçgen prizma (radyan, 0 = sağ; ön görünüş düzleminde)."""
    import bmesh
    me = bpy.data.meshes.new("head")
    bm = bmesh.new()
    pts = []
    for a in (0.0, 2.45, -2.45):
        px = x + math.cos(ang + a) * size * (1.0 if a == 0.0 else 1.0)
        py = y + math.sin(ang + a) * size * (1.0 if a == 0.0 else 1.0)
        pts.append((px, py))
    f = [bm.verts.new(A.G(px, py, 0.1)) for px, py in pts]
    b2 = [bm.verts.new(A.G(px, py, -0.1)) for px, py in pts]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b2)))
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new([f[j], f[i], b2[i], b2[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("head", me)
    bpy.context.scene.collection.objects.link(o)
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = 0.03
    b.segments = 3
    o.data.materials.append(m)
    return o

def _glyph(kind, m):
    w = 0.13
    if kind == "F":
        _tube([(0, -0.8), (0, 0.2)], w, m)
        _head(0, 0.42, math.pi / 2, 0.5, m)
    elif kind in ("L", "R"):
        sg = -1 if kind == "L" else 1
        pts = [(-0.35 * sg, -0.8), (-0.35 * sg, -0.05)]
        for k in range(1, 13):
            a = math.pi - (math.pi / 2) * k / 12
            pts.append(((-0.35 + 0.45 + 0.45 * math.cos(a)) * sg, -0.05 + 0.45 * math.sin(a)))
        pts.append((0.2 * sg, 0.4))
        _tube(pts, w, m)
        _head(0.45 * sg, 0.4, 0 if sg > 0 else math.pi, 0.36, m)
    elif kind == "J":
        pts = [(-0.75 + 1.3 * k / 16, -0.6 + 1.05 * math.sin(math.pi * k / 16) * (1 - 0.25 * k / 16)) for k in range(17)]
        _tube(pts[:15], w, m)
        _head(0.52, -0.42, -1.0, 0.3, m)
        box((-0.75, -0.82, 0), (0.5, 0.12, 0.2), m, bevel=0.04)
        box((0.6, -0.82, 0), (0.5, 0.12, 0.2), m, bevel=0.04)
    elif kind == "A":
        torus((0, 0, 0), 0.3, 0.1, m, "z", 40, 12)
        for k in range(8):
            a = k * math.pi / 4
            o = box((math.cos(a) * 0.62, math.sin(a) * 0.62, 0), (0.28, 0.16, 0.2), m, bevel=0.05)
            o.rotation_euler = (0, -a, 0)
    elif kind == "W":
        for x in (-0.3, 0.3):
            box((x, 0, 0), (0.3, 1.3, 0.24), m, bevel=0.08)
    elif kind == "C":
        hollow = mat("GlyphGhost", "#ffffff", 0.0, 0.35, alpha=0.5)
        for x, y, mm in ((0.18, 0.18, hollow), (-0.18, -0.18, m)):
            box((x, y, 0 if mm is m else -0.2), (0.95, 0.85, 0.24), mm, bevel=0.12)
        eye = mat("GlyphEye", "#38c6d8", 0.0, 0.3, emission="#38c6d8", strength=1.5)
        for x in (-0.4, 0.04):
            cyl((x, -0.12, 0.13), 0.1, 0.06, eye, "z", 20)
    elif kind in ("1", "2"):
        cu = bpy.data.curves.new("txt", "FONT")
        cu.body = "F" + kind
        cu.font = bpy.data.fonts.load(FONT)
        cu.extrude = 0.08
        cu.bevel_depth = 0.075
        cu.offset = 0.0
        cu.size = 1.25
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        o = bpy.data.objects.new("txt", cu)
        o.rotation_euler = (math.pi / 2, 0, 0)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(m)

def build_cmds():
    out = []
    for kind in ("F", "L", "R", "J", "A", "W", "1", "2", "C"):
        reset()
        white = mat("GlyphWhite", "#ffffff", 0.0, 0.32)
        _glyph(kind, white)
        S._cycles(160, 160, samples=48, transparent=True)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        bpy.context.scene.collection.objects.link(cam)
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.2
        cam.location = (0, -6, 0)
        cam.rotation_euler = (math.pi / 2, 0, 0)
        bpy.context.scene.camera = cam
        for loc, e, c in (((-3, -4, 4), 700, (1, 1, 1)), ((4, -3, -2), 180, (0.85, 0.9, 1.0))):
            l = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
            bpy.context.scene.collection.objects.link(l)
            l.location = loc
            l.data.energy = e
            l.data.size = 3
            l.data.color = c
            l.rotation_euler = (mathutils.Vector((0, 0, 0)) - mathutils.Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        w = bpy.data.worlds.new("W")
        bpy.context.scene.world = w
        w.color = (0.55, 0.55, 0.6)
        S._render(os.path.join(GP, "assets", "ui", "cmd_%s.png" % kind))
        out.append({"file": "ui/cmd_%s.png" % kind, "tris": 0, "budget": 0, "ok": True})
    return out

# ---------------------------------------------------------------------------
def build_store():
    reset()
    S.M()
    d = os.path.join(GP, "assets", "models", "scenes", "title_diorama.glb")
    _import_glb(d)
    rb = os.path.join(GP, "assets", "models", "robot.glb")
    if os.path.exists(rb):
        objs = _import_glb(rb, loc=A.G(2.7, 0.0, 0.05), rot_z=0.4, scale=1.6)
        arm = [o for o in objs if o.type == "ARMATURE"]
        act = bpy.data.actions.get("wave")
        if arm and act:
            arm[0].animation_data.action = act
            bpy.context.scene.frame_set(8)
    S._cycles(1024, 500, samples=48, transparent=True)
    S._studio(target=(-3.6, 1.2, 0.4), dist=22.0, elev=0.42, az=0.62, ortho=16.5)
    tmp = os.path.join(S.SCRATCH, "store_subject.png")
    S._render(tmp)
    subprocess.run(["python3", os.path.join(HERE, "compose_2d.py"), "store", tmp], check=True)
    return {"file": "store/feature_graphic.png", "tris": 0, "budget": 0, "ok": True}
