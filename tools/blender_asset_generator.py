"""Kayıp Kuleler — Blender ile .glb oyun varlıkları üretimi (Blender 5.x, ekransız).

    blender --background --python tools/blender_asset_generator.py -- [--out godot-program/assets/models] [--only robot,components,parts]

Üretilenler (Godot'daki scripts/assets/asset_loader.gd bu yolları kendiliğinden yükler):
    assets/models/robot.glb
    assets/models/components/{smd_transistor,diode,capacitor,resistor,relay,bridge}.glb
    assets/models/pc_parts/part_001.glb … part_100.glb   (tools/pc_parts.py'deki montaj kutularına birebir)

Kurallar: her modelden önce sahne sıfırlanır; her parçaya ince pah (Bevel, 2–3 segment, 0.015–0.025, ince
parçalarda boyuta göre kısılır), açıyla yumuşatma ve WeightedNormal uygulanır; parçalar tek mesh'te birleştirilir,
ölçek/dönüş uygulanır, orijin taban merkezine (Blender Z=0 → Godot Y=0) alınır; Smart UV Project ile UV açılır;
malzemeler Principled BSDF (Base Color, Metallic, Roughness, Emission, Transmission/Alpha) olur. Godot'nun adla
bulduğu özel malzeme yuvaları: RobotLED (tema rengi), Band1..Band4 (direnç gecikmesi), MonitorScreen (BIOS ekranı),
Pins (bastıkça parlayan bacaklar), RelayCover, ChargeRing, DiodeArrow, BridgeLED.
Koordinatlar Godot düzeninde yazılır (x sağ, y yukarı, z kameraya doğru); glTF dışa aktarımı Y-up'a çevirir.
Robotun ve diyotun "ileri" yönü Godot +Z / -Z (aşağıdaki notlara bakın). Sonunda üçgen bütçeleri denetlenir ve
tools/blender_assets_report.json yazılır.
"""
import bpy
import bmesh
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pc_parts  # noqa: E402  (100 parçanın montaj kutuları ve şekilleri)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def _arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(_arg("--out", os.path.join(HERE, "..", "godot-program", "assets", "models")))
ONLY = set(_arg("--only", "robot,components,parts").split(","))

BUDGET_ROBOT = 10000
BUDGET_COMPONENT = 8000
BUDGET_PART = 6000
BUDGET_PART_BIG = 14000
BIG_SHAPES = {"keys", "fins_z", "fins_y", "shroud", "dimm", "psu", "pins", "heatsink", "frame_top", "pcb_board", "vram", "panel_v"}

# ---------------------------------------------------------------------------
# sahne / malzeme
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def mat(name, color="#808080", metallic=0.0, rough=0.5, emission=None, strength=0.0, transmission=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    p = [n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
    p.inputs["Base Color"].default_value = (*srgb(color), 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if emission:
        p.inputs["Emission Color"].default_value = (*srgb(emission), 1.0)
        p.inputs["Emission Strength"].default_value = strength
    if transmission:
        p.inputs["Transmission Weight"].default_value = transmission
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    return m

# Godot (x, y, z) → Blender (x, -z, y)
def G(x, y, z):
    return (x, -z, y)

def _finish_obj(o, m, bevel):
    o.data.materials.append(m)
    if bevel and bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2 if bevel < 0.02 else 3
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(35)
        b.use_clamp_overlap = True
    return o

def bw(*dims, base=0.02):
    """Pah genişliği: 0.015–0.025, ince parçalarda boyuta göre kısılır."""
    return max(0.0, min(base, 0.22 * min(dims)))

def box(c, s, m, rot=None, bevel=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(*c))
    o = bpy.context.active_object
    o.scale = (s[0], s[2], s[1])
    if rot:
        o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish_obj(o, m, bw(*s) if bevel is None else bevel)

_AX = {"x": (0, math.pi / 2, 0), "y": (0, 0, 0), "z": (math.pi / 2, 0, 0)}   # Godot eksenleri (Blender'da y↔z)
def cyl(c, r, h, m, axis="y", verts=24, bevel=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=G(*c), rotation=_AX[axis])
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish_obj(o, m, bw(r * 2, h) if bevel is None else bevel)

def cone(c, r1, r2, h, m, axis="y", verts=24):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=G(*c), rotation=_AX[axis])
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish_obj(o, m, 0)

def torus(c, R, r, m, axis="y", major=32, minor=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major, minor_segments=minor, location=G(*c), rotation=_AX[axis])
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish_obj(o, m, 0)

def sphere(c, r, m, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=G(*c))
    return _finish_obj(bpy.context.active_object, m, 0)

def fan(c, size, axis, frame_m, blade_m, hub_m, blades=7, depth=None):
    """Kare çerçeveli eksenel fan: çerçeve, 4 köşe vidası, hub, açılı 7 kanat."""
    w = size
    d = depth if depth else max(0.02, w * 0.18)
    ax = {"x": 0, "y": 1, "z": 2}[axis]
    def P(u, v, t):   # yerel (u, v düzlem; t eksen) → Godot
        p = [0, 0, 0]
        order = {"x": (2, 1, 0), "y": (0, 2, 1), "z": (0, 1, 2)}[axis]
        p[order[0]], p[order[1]], p[order[2]] = u, v, t
        return (c[0] + p[0], c[1] + p[1], c[2] + p[2])
    def S(u, v, t):
        p = [0, 0, 0]
        order = {"x": (2, 1, 0), "y": (0, 2, 1), "z": (0, 1, 2)}[axis]
        p[order[0]], p[order[1]], p[order[2]] = u, v, t
        return p
    e = w * 0.09
    for sgn in (-1, 1):
        box(P(0, sgn * (w / 2 - e / 2), 0), S(w, e, d), frame_m)
        box(P(sgn * (w / 2 - e / 2), 0, 0), S(e, w - 2 * e, d), frame_m)
    torus(P(0, 0, 0), w * 0.41, d * 0.32, frame_m, axis, 40, 8)
    cyl(P(0, 0, 0), w * 0.15, d * 0.9, hub_m, axis, 24)
    for i in range(blades):
        a = i * 2 * math.pi / blades
        u, v = math.cos(a) * w * 0.27, math.sin(a) * w * 0.27
        bl = box(P(u, v, 0), S(w * 0.22, w * 0.1, d * 0.12), blade_m, bevel=0.004)
        # kanadı ekseni etrafında çevir ve eğ
        rot_axis = {"x": "X", "y": "Z", "z": "Y"}[axis]
        bl.rotation_mode = "XYZ"
        r = [0.0, 0.0, 0.0]
        r[{"X": 0, "Y": 1, "Z": 2}[rot_axis]] = -a if axis == "z" else a
        bl.rotation_euler = r
        bpy.ops.object.select_all(action="DESELECT")
        bl.select_set(True)
        bpy.context.view_layer.objects.active = bl
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

# ---------------------------------------------------------------------------
# birleştir, normal, UV, dışa aktar
def _planar_uv(o, mat_name):
    """Belirli bir malzemenin yüzlerine sınırlarına göre 0..1 düzlemsel UV (MonitorScreen → BIOS dokusu)."""
    idx = [i for i, m in enumerate(o.data.materials) if m and m.name == mat_name]
    if not idx:
        return
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uv = bm.loops.layers.uv.active
    faces = [f for f in bm.faces if f.material_index in idx]
    if faces and uv:
        xs = [v.co.x for f in faces for v in f.verts]
        zs = [v.co.z for f in faces for v in f.verts]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        for f in faces:
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x - x0) / max(1e-6, x1 - x0), (l.vert.co.z - z0) / max(1e-6, z1 - z0))
    bm.to_mesh(o.data)
    bm.free()

def finalize(path, budget):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")          # pahları uygula
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # orijin: taban merkezi (Blender Z min = Godot Y=0)
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    off = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs))
    for v in o.data.vertices:
        v.co.x -= off[0]
        v.co.y -= off[1]
        v.co.z -= off[2]
    # normaller: açıyla yumuşatma + ağırlıklı normal
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    tri = o.modifiers.new("Triangulate", "TRIANGULATE")   # tanjant üretimi için (export_tangents)
    tri.keep_custom_normals = True
    bpy.ops.object.convert(target="MESH")
    # UV
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    _planar_uv(o, "MonitorScreen")
    # üçgen sayısı
    o.data.calc_loop_triangles()
    tris = len(o.data.loop_triangles)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_tangents=True, use_selection=False)
    return {"file": os.path.relpath(path, OUT), "tris": tris, "budget": budget, "ok": tris <= budget,
            "materials": [m.name for m in o.data.materials if m]}

# ---------------------------------------------------------------------------
# 1) Robot: devre tamir dronu (ön yüz Godot +Z = robotun yürüme yönü)
def build_robot():
    reset()
    amber = mat("AmberCeramic", "#ff9a3c", 0.1, 0.45)
    visor = mat("Anthracite", "#2a2c33", 0.3, 0.5)
    glass = mat("LensGlass", "#cfefff", 0.0, 0.05, transmission=0.8, alpha=0.55)
    led = mat("RobotLED", "#6ff6ff", 0.0, 0.3, emission="#6ff6ff", strength=4.0)
    metal = mat("BrushedDarkMetal", "#3a3d44", 0.85, 0.35)
    copper = mat("Copper", "#c87533", 0.95, 0.28)
    rubber = mat("TreadRubber", "#1c1d22", 0.0, 0.8)
    # gövde (hafif eğimli üst)
    box((0, 0.34, 0), (0.5, 0.36, 0.44), amber, bevel=0.045)
    box((0, 0.545, -0.01), (0.44, 0.07, 0.38), amber, bevel=0.03)
    box((0, 0.17, 0), (0.46, 0.04, 0.4), metal)
    # vizör + mercek (+Z ön)
    box((0, 0.37, 0.215), (0.38, 0.22, 0.04), visor, bevel=0.02)
    cyl((0, 0.37, 0.238), 0.085, 0.02, visor, "z", 32)
    cyl((0, 0.37, 0.245), 0.07, 0.02, glass, "z", 32)
    cyl((0, 0.37, 0.24), 0.05, 0.01, led, "z", 24)
    for sx in (-1, 1):
        box((sx * 0.13, 0.42, 0.236), (0.05, 0.025, 0.01), led, bevel=0.003)
    # palet takımları
    for sx in (-1, 1):
        x = sx * 0.3
        box((x, 0.1, 0), (0.12, 0.13, 0.46), rubber, bevel=0.03)
        for k in range(10):
            z = -0.21 + k * 0.047
            box((x, 0.03, z), (0.13, 0.02, 0.025), rubber, bevel=0.005)
        for z in (-0.16, 0.0, 0.16):
            cyl((x + sx * 0.055, 0.1, z), 0.045, 0.02, metal, "x", 20)
        # bakır pistonlar gövdeye
        for z in (-0.1, 0.1):
            cyl((sx * 0.25, 0.2, z), 0.018, 0.12, copper, "x", 12)
            cyl((sx * 0.235, 0.2, z), 0.028, 0.03, metal, "x", 12)
    # anten: bobinli çubuk + parlayan uç
    cyl((0, 0.67, -0.05), 0.012, 0.18, metal, "y", 12)
    for k in range(5):
        torus((0, 0.61 + k * 0.022, -0.05), 0.022, 0.006, copper, "y", 16, 6)
    sphere((0, 0.775, -0.05), 0.03, led, 16)
    # arka soğutma ızgarası
    for k in range(7):
        box((-0.15 + k * 0.05, 0.36, -0.235), (0.018, 0.2, 0.04), metal, bevel=0.004)
    return finalize(os.path.join(OUT, "robot.glb"), BUDGET_ROBOT)

# ---------------------------------------------------------------------------
# 2) Devre elemanları: 1×1 taban, üst yüz y=1.0 (Godot), orijin taban merkezi
def _pcb_base(h=0.06):
    pcb = mat("PCB", "#0b3b2a", 0.0, 0.55)
    pad = mat("Copper", "#c87533", 0.95, 0.28)
    box((0, h / 2, 0), (1.0, h, 1.0), pcb, bevel=0.015)
    return pcb, pad

def build_smd():
    reset()
    _, pad = _pcb_base()
    epoxy = mat("Epoxy", "#1a1c20", 0.0, 0.72)
    tin = mat("Pins", "#d9dde3", 0.95, 0.22)
    mark = mat("Marking", "#8a8d96", 0.0, 0.6)
    box((0, 0.53, 0), (0.8, 0.94, 0.8), epoxy, bevel=0.025)
    # girintili yürünebilir çerçeve + pin-1 noktası
    for sgn in (-1, 1):
        box((0, 0.995, sgn * 0.37), (0.78, 0.012, 0.035), epoxy, bevel=0.004)
        box((sgn * 0.37, 0.995, 0), (0.035, 0.012, 0.71), epoxy, bevel=0.004)
    cyl((-0.27, 0.995, -0.27), 0.04, 0.012, mark, "y", 16)
    box((0.02, 0.993, 0.08), (0.36, 0.006, 0.04), mark, bevel=0)
    # 3 bacak: -x yanda 2, +x yanda 1; gövdeden çıkıp PCB'ye kıvrılarak iner
    for sx, z in ((-1, -0.2), (-1, 0.2), (1, 0.0)):
        box((sx * 0.43, 0.42, z), (0.08, 0.05, 0.13), tin, bevel=0.012)
        box((sx * 0.47, 0.26, z), (0.045, 0.3, 0.13), tin, rot=None, bevel=0.012)
        box((sx * 0.48, 0.075, z), (0.1, 0.03, 0.15), tin, bevel=0.008)
        box((sx * 0.48, 0.062, z), (0.14, 0.006, 0.19), pad, bevel=0)
    return finalize(os.path.join(OUT, "components", "smd_transistor.glb"), BUDGET_COMPONENT)

def build_diode():
    """Gövde ekseni Godot Z; akım yönü (ok) -Z. Oyun yön 0'ı +X kabul eder: ComponentFactory -PI/2 ofset uygular."""
    reset()
    pcb, pad = _pcb_base(0.08)
    body = mat("DiodeGlass", "#2a1610", 0.1, 0.18, transmission=0.3)
    band = mat("CathodeBand", "#e3e7ee", 0.9, 0.2)
    orange = mat("DiodeArrow", "#ff8a1f", 0.0, 0.35, emission="#ff8a1f", strength=2.5)
    tin = mat("Pins", "#d9dde3", 0.95, 0.22)
    cyl((0, 0.55, 0), 0.43, 0.82, body, "z", 40)
    for sz in (-1, 1):
        box((0, 0.19, sz * 0.3), (0.62, 0.22, 0.12), pcb)
    # katot bandı (-Z ucu) + turuncu şerit
    cyl((0, 0.55, -0.3), 0.445, 0.12, band, "z", 40)
    cyl((0, 0.55, -0.37), 0.446, 0.025, orange, "z", 40)
    # üst düz yürüme şeridi ve kabartma ok (-Z yönünde)
    box((0, 0.985, 0), (0.3, 0.03, 0.8), body, bevel=0.01)
    box((0, 1.005, 0.06), (0.07, 0.012, 0.34), orange, bevel=0.003)
    for sx in (-1, 1):
        box((sx * 0.06, 1.005, -0.16), (0.06, 0.012, 0.2), orange, rot=(0, 0, sx * 0.75), bevel=0.003)
    for sz in (-1, 1):
        cyl((0, 0.55, sz * 0.46), 0.04, 0.1, tin, "z", 12)
        box((0, 0.3, sz * 0.48), (0.06, 0.5, 0.05), tin)
        box((0, 0.085, sz * 0.48), (0.16, 0.012, 0.1), pad, bevel=0)
    return finalize(os.path.join(OUT, "components", "diode.glb"), BUDGET_COMPONENT)

def build_capacitor():
    reset()
    _pcb_base()
    rubber = mat("RubberBase", "#1d1f26", 0.0, 0.8)
    sleeve = mat("Sleeve", "#1c2a5a", 0.1, 0.45)
    alu = mat("Aluminum", "#c9ced6", 0.9, 0.25)
    stripe = mat("SleeveStripe", "#c8d0dc", 0.0, 0.5)
    ring = mat("ChargeRing", "#59e1ff", 0.0, 0.3, emission="#59e1ff", strength=3.0)
    tin = mat("Pins", "#d9dde3", 0.95, 0.22)
    cyl((0, 0.1, 0), 0.47, 0.08, rubber, "y", 48)
    cyl((0, 0.5, 0), 0.43, 0.76, sleeve, "y", 48)
    box((0.41, 0.5, 0), (0.05, 0.7, 0.24), stripe, bevel=0.01)
    cyl((0, 0.93, 0), 0.425, 0.12, alu, "y", 48)
    # çapraz basınç çentiği (K / +)
    for a in (0.0, math.pi / 2):
        box((0, 0.993, 0), (0.56, 0.014, 0.035), rubber, rot=(0, 0, a), bevel=0.004)
    box((0.22, 0.996, -0.22), (0.09, 0.008, 0.025), ring, bevel=0)
    box((0.22, 0.996, -0.22), (0.025, 0.008, 0.09), ring, bevel=0)
    torus((0, 0.995, 0), 0.36, 0.012, ring, "y", 48, 6)
    for sx in (-1, 1):
        cyl((sx * 0.2, 0.06, 0.38), 0.03, 0.06, tin, "y", 10)
    return finalize(os.path.join(OUT, "components", "capacitor.glb"), BUDGET_COMPONENT)

def build_resistor():
    """Gövde ekseni Godot X. Band1..Band4 ayrı malzeme yuvaları (Godot gecikmeye göre renklendirir)."""
    reset()
    pcb, pad = _pcb_base(0.08)
    ceramic = mat("Ceramic", "#d9c49c", 0.0, 0.8)
    tin = mat("Pins", "#d9dde3", 0.95, 0.22)
    bands = [mat("Band1", "#6b3a1e", 0.0, 0.6), mat("Band2", "#151515", 0.0, 0.6), mat("Band3", "#c0392b", 0.0, 0.6), mat("Band4", "#d4af37", 0.85, 0.3)]
    # köpek kemiği gövde: kalın uçlar, boğumlu orta
    for sx in (-1, 1):
        cyl((sx * 0.31, 0.55, 0), 0.44, 0.2, ceramic, "x", 40)
        cyl((sx * 0.43, 0.55, 0), 0.3, 0.05, tin, "x", 32)
        cyl((sx * 0.47, 0.55, 0), 0.04, 0.06, tin, "x", 12)
        box((sx * 0.48, 0.3, 0), (0.05, 0.5, 0.06), tin)
        box((sx * 0.48, 0.085, 0), (0.1, 0.012, 0.16), pad, bevel=0)
    cyl((0, 0.55, 0), 0.4, 0.44, ceramic, "x", 40)
    for i, x in enumerate((-0.31, -0.13, 0.03, 0.28)):
        r = 0.446 if abs(x) > 0.2 else 0.406
        cyl((x, 0.55, 0), r, 0.07, bands[i], "x", 40)
    for sz in (-1, 1):
        box((0, 0.2, sz * 0.3), (0.7, 0.24, 0.12), pcb)
    box((0, 0.985, 0), (0.8, 0.03, 0.28), ceramic, bevel=0.012)
    return finalize(os.path.join(OUT, "components", "resistor.glb"), BUDGET_COMPONENT)

def build_relay():
    reset()
    base = mat("RelayBase", "#1d1f26", 0.1, 0.6)
    copper = mat("Copper", "#c87533", 0.95, 0.28)
    brass = mat("Brass", "#d4a94a", 0.9, 0.3)
    tin = mat("Pins", "#d9dde3", 0.95, 0.22)
    cover = mat("RelayCover", "#bfe4ff", 0.0, 0.08, transmission=0.85, alpha=0.28)
    box((0, 0.08, 0), (1.0, 0.16, 1.0), base, bevel=0.02)
    for x in (-0.3, 0.0, 0.3):
        for z in (-0.3, 0.3):
            cyl((x, 0.02, z), 0.03, 0.04, tin, "y", 10)
    # sarılmış bakır bobin (çekirdek + sargılar)
    cyl((-0.18, 0.42, 0), 0.07, 0.5, tin, "y", 20)
    for k in range(10):
        torus((-0.18, 0.22 + k * 0.042, 0), 0.13, 0.022, copper, "y", 24, 8)
    box((-0.18, 0.2, 0), (0.34, 0.04, 0.34), base, bevel=0.01)
    box((-0.18, 0.69, 0), (0.34, 0.04, 0.34), base, bevel=0.01)
    # hareketli pirinç kontak kolu ve kontaklar
    box((0.1, 0.74, 0), (0.42, 0.035, 0.12), brass, bevel=0.008)
    box((0.3, 0.5, 0), (0.05, 0.46, 0.12), brass, bevel=0.008)
    sphere((0.3, 0.27, 0.0), 0.035, brass, 12)
    box((0.3, 0.22, 0), (0.12, 0.08, 0.12), base, bevel=0.01)
    # şeffaf akrilik kapak
    box((0, 0.58, 0), (0.94, 0.84, 0.94), cover, bevel=0.025)
    return finalize(os.path.join(OUT, "components", "relay.glb"), BUDGET_COMPONENT)

def build_bridge():
    reset()
    pcb = mat("BridgePCB", "#0b3b2a", 0.0, 0.5)
    copper = mat("Copper", "#c87533", 0.95, 0.28)
    led = mat("BridgeLED", "#3cf08a", 0.0, 0.3, emission="#3cf08a", strength=3.0)
    hinge = mat("Hinge", "#9aa0a8", 0.9, 0.3)
    box((0, 0.87, 0), (1.0, 0.26, 1.0), pcb, bevel=0.025)
    for k in range(5):
        box((-0.36 + k * 0.18, 1.003, 0), (0.035, 0.008, 0.9), copper, bevel=0)
    for sz in (-1, 1):
        box((0, 0.87, sz * 0.495), (0.92, 0.05, 0.02), led, bevel=0.004)
        cyl((sz * 0.5, 0.8, 0), 0.05, 0.9, hinge, "z", 16)
    for x in (-0.3, 0.3):
        box((x, 0.65, 0), (0.08, 0.2, 0.8), pcb, bevel=0.01)
    return finalize(os.path.join(OUT, "components", "bridge.glb"), BUDGET_COMPONENT)

# ---------------------------------------------------------------------------
# 3) Bilgisayar parçaları: her parça montaj kutusunu (sx, sy, sz) tam doldurur, merkez orijinde kurulur
M = {}
def pm():
    """Parça malzemeleri (her sahne sıfırlamasından sonra yeniden)."""
    return {
        "pcb": mat("PCB", "#0b3b2a", 0.0, 0.55), "copper": mat("Copper", "#c87533", 0.95, 0.28),
        "gold": mat("Gold", "#d4af37", 1.0, 0.25), "tin": mat("Pins", "#d9dde3", 0.95, 0.22),
        "epoxy": mat("Epoxy", "#1a1c20", 0.0, 0.72), "plastic": mat("BlackPlastic", "#202128", 0.0, 0.6),
        "white": mat("WhitePlastic", "#ecedf0", 0.0, 0.5), "alu": mat("Aluminum", "#b8bec7", 0.9, 0.3),
        "nickel": mat("Nickel", "#c9ced6", 0.95, 0.18), "dark": mat("DarkMetal", "#30333b", 0.85, 0.4),
        "rubber": mat("Rubber", "#141518", 0.0, 0.85), "glass": mat("TemperedGlass", "#bfe4ff", 0.0, 0.04, transmission=0.9, alpha=0.18),
        "rgb": mat("RGB", "#8a5cff", 0.0, 0.3, emission="#8a5cff", strength=3.0), "cyan": mat("Accent", "#62f2c8", 0.0, 0.3, emission="#62f2c8", strength=2.5),
        "screen": mat("MonitorScreen", "#0e2a4a", 0.0, 0.2, emission="#1b4f8a", strength=1.5), "blue": mat("BluePlastic", "#2f6fe0", 0.0, 0.5),
        "green_led": mat("PowerLED", "#3cf08a", 0.0, 0.3, emission="#3cf08a", strength=3.0),
    }

def _along(s):
    return "x" if s[0] >= s[2] else "z"

def shape(name, s, col):
    x, y, z = s
    hx, hy, hz = x / 2, y / 2, z / 2
    m = M
    body = mat("Body_" + col.lstrip("#"), col, 0.2, 0.5)
    if name in ("pcb_board", "ssd", "substrate", "gpu_pcb"):
        box((0, 0, 0), s, m["pcb"])
        if name == "gpu_pcb":
            box((0, -hy + 0.03, 0), (x * 0.5, 0.06, z * 1.02), m["gold"], bevel=0.003)
            for i in range(8):
                box((-hx * 0.8 + i * x * 0.11, 0.05, hz + 0.002), (0.025, y * 0.6, 0.004), m["copper"], bevel=0)
        else:
            n = 7 if name == "pcb_board" else 4
            for i in range(n):
                box((0, hy + 0.002, -hz * 0.85 + i * (z * 0.85 * 2) / max(1, n - 1) / 2 * 1.0), (x * 0.84, 0.004, 0.012), m["copper"], bevel=0)
            for sx in (-1, 1):
                for sz in (-1, 1):
                    torus((sx * (hx - 0.08), hy + 0.002, sz * (hz - 0.08)), 0.035, 0.008, m["gold"], "y", 16, 6)
            if name == "ssd":
                box((-hx * 0.25, hy + 0.004, 0), (x * 0.45, 0.006, z * 0.7), m["white"], bevel=0)
                box((hx - 0.03, 0, 0), (0.05, y * 1.05, z * 0.9), m["gold"], bevel=0.002)
            if name == "substrate":
                for a in range(6):
                    for b in range(6):
                        box((-hx * 0.8 + a * x * 0.32, -hy - 0.001, -hz * 0.8 + b * z * 0.32), (0.025, 0.002, 0.025), m["gold"], bevel=0)
    elif name in ("standoff", "screw"):
        cyl((0, 0, 0), min(hx, hz) * 0.9, y, m["gold"] if name == "standoff" else m["nickel"], "y", 6)
        cyl((0, hy - 0.012, 0), min(hx, hz), 0.024, m["gold"] if name == "standoff" else m["nickel"], "y", 6 if name == "standoff" else 20)
    elif name in ("trace", "coldplate"):
        box((0, 0, 0), s, m["copper"], bevel=bw(*s, base=0.015))
    elif name in ("chip", "chip_flat", "die", "die_v"):
        if name in ("die", "die_v"):
            box((0, 0, 0), s, mat("Die", col, 0.3, 0.25, emission=col, strength=1.2))
        else:
            box((0, -hy * 0.1, 0), (x * 0.84, y * 0.9, z * 0.84), m["epoxy"])
            n = int(max(3, min(12, x / 0.05)))
            for i in range(n):
                xx = -hx * 0.8 + i * (x * 0.8) / max(1, n - 1)
                for sz in (-1, 1):
                    box((xx, -hy * 0.55, sz * hz * 0.92), (0.012, y * 0.32, z * 0.09), m["tin"], bevel=0.002)
            cyl((-hx * 0.6, hy * 0.82, -hz * 0.5), min(x, z) * 0.06, 0.004, m["white"], "y", 12)
    elif name == "battery":
        cyl((0, 0, 0), min(hx, hz), y, m["nickel"], "y", 40)
        box((0, hy + 0.002, 0), (0.07, 0.004, 0.018), m["epoxy"], bevel=0)
        box((0, hy + 0.002, 0), (0.018, 0.004, 0.07), m["epoxy"], bevel=0)
    elif name in ("header", "connector", "m2_slot", "dimm_slot", "pcie_slot", "clip"):
        shell = m["white"] if col.lower() in ("#f2f2f2", "#e8e8ee") else m["plastic"]
        box((0, -hy * 0.2, 0), (x, y * 0.8, z), shell)
        ax = _along(s)
        L = x if ax == "x" else z
        n = int(max(2, min(24, L / 0.06)))
        for i in range(n):
            t = -L / 2 * 0.9 + i * L * 0.9 / max(1, n - 1)
            p = (t, hy * 0.6, 0) if ax == "x" else (0, hy * 0.6, t)
            if name == "header":
                box(p, (0.015, y * 0.55, 0.015), m["gold"], bevel=0.002)
            else:
                box(p, (0.02 if ax == "x" else x * 0.5, 0.006, z * 0.5 if ax == "x" else 0.02), m["rubber"], bevel=0)
        if name in ("dimm_slot", "pcie_slot"):
            # metal zırh + kilit mandalları
            if name == "pcie_slot":
                box((0, 0, hz + 0.004), (x * 0.96, y * 0.6, 0.008), m["nickel"], bevel=0.002)
                box((0, 0, -hz - 0.004), (x * 0.96, y * 0.6, 0.008), m["nickel"], bevel=0.002)
            e = (0, 0, hz - 0.03) if ax == "z" else (hx - 0.03, 0, 0)
            box(e, (x if ax == "z" else 0.06, y, 0.06 if ax == "z" else z), m["white"])
    elif name == "psu":
        box((0, 0, 0), s, m["dark"], bevel=0.03)
        # petek ızgara (yan yüz) ve modüler soketler (ön)
        for a in range(10):
            for b in range(5):
                cyl((-hx * 0.8 + a * x * 0.18, -hy * 0.6 + b * y * 0.3, hz + 0.004), 0.035, 0.01, m["rubber"], "z", 6)
        box((0, 0.05, -hz - 0.004), (x * 0.55, y * 0.4, 0.008), mat("Label", "#e8b949", 0.0, 0.5), bevel=0)
        for k in range(4):
            cyl((-hx * 0.5 + k * x * 0.3, hy * 0.2, -hz * 0.3), 0.08, 0.02, m["copper"], "y", 20)
    elif name == "grille_y":
        for r in (0.48, 0.38, 0.28, 0.18):
            torus((0, 0, 0), min(hx, hz) * r / 0.5, y * 0.35, m["alu"], "y", 40, 6)
        box((0, 0, 0), (x * 0.96, y, 0.02), m["alu"], bevel=0.002)
        box((0, 0, 0), (0.02, y, z * 0.96), m["alu"], bevel=0.002)
    elif name in ("panel_conn", "io_shield", "port", "usb"):
        shell = m["nickel"] if name in ("io_shield", "port") and name != "panel_conn" else m["plastic"]
        box((0, 0, 0), s, shell)
        cols, rows = (3, 2) if name != "port" else (1, 2)
        face_z = z <= x
        for a in range(cols):
            for b in range(rows):
                u = (a + 0.5) / cols - 0.5
                v = (b + 0.5) / rows - 0.5
                hole = m["blue"] if name == "usb" else m["rubber"]
                if face_z:
                    box((u * x * 0.8, v * y * 0.7, -hz - 0.003), (x * 0.7 / cols, y * 0.25, 0.006), hole, bevel=0)
                else:
                    box((hx + 0.003, v * y * 0.7, u * z * 0.8), (0.006, y * 0.25, z * 0.7 / cols), hole, bevel=0)
    elif name in ("choke_row", "mosfet_row"):
        ax = _along(s)
        L = x if ax == "x" else z
        n = int(max(2, min(12, L / (0.12 if name == "choke_row" else 0.09))))
        for i in range(n):
            t = -L / 2 + (i + 0.5) * L / n
            w = L / n * 0.8
            c = (t, 0, 0) if ax == "x" else (0, 0, t)
            sz = (w, y, z * 0.9) if ax == "x" else (x * 0.9, y, w)
            box(c, sz, m["dark"] if name == "choke_row" else m["epoxy"])
            box((c[0], hy + 0.002, c[2]), (sz[0] * 0.6, 0.004, sz[2] * 0.6), m["copper"] if name == "choke_row" else m["tin"], bevel=0)
    elif name in ("cable_x", "cable_y", "cable_z"):
        ax = name[-1]
        L = {"x": x, "y": y, "z": z}[ax]
        r = (min(y, z) if ax == "x" else (min(x, y) if ax == "z" else min(x, z))) / 2
        sleeve = mat("Sleeve_" + col.lstrip("#"), col, 0.0, 0.7)
        for i in range(3):
            o = (0, (i - 1) * r * 0.6, 0) if ax != "y" else ((i - 1) * r * 0.6, 0, 0)
            cyl(o, r * 0.42, L, sleeve, ax, 12)
        for j in range(6):
            t = -L / 2 + (j + 0.5) * L / 6
            c = {"x": (t, 0, 0), "y": (0, t, 0), "z": (0, 0, t)}[ax]
            cyl(c, r * 0.98, min(0.03, L / 8), m["rgb"] if j % 2 == 0 else m["dark"], ax, 16)
    elif name == "socket":
        box((0, -hy * 0.5, 0), (x, y * 0.5, z), m["plastic"])
        for k in range(4):
            if k % 2 == 0:
                box((0, hy * 0.2, (1 if k == 0 else -1) * hz * 0.92), (x, y * 0.6, z * 0.08), m["nickel"])
            else:
                box(((1 if k == 1 else -1) * hx * 0.92, hy * 0.2, 0), (x * 0.08, y * 0.6, z), m["nickel"])
    elif name == "pins":
        box((0, -hy * 0.5, 0), (x, y * 0.5, z), m["plastic"])
        for a in range(10):
            for b in range(10):
                box((-hx * 0.9 + a * x * 0.2, hy * 0.25, -hz * 0.9 + b * z * 0.2), (0.012, y * 0.5, 0.012), m["gold"], bevel=0)
    elif name == "lever":
        cyl((0, -hy * 0.3, 0), min(hx, hy) * 0.6, z, m["nickel"], "z", 10)
        box((0, 0, hz - 0.02), (x, y, 0.04), m["nickel"])
    elif name == "ihs":
        box((0, 0, 0), s, m["nickel"], bevel=bw(*s, base=0.02))
        box((0, hy + 0.002, -hz * 0.3), (x * 0.6, 0.004, 0.02), m["dark"], bevel=0)
        box((0, hy + 0.002, 0), (x * 0.45, 0.004, 0.02), m["dark"], bevel=0)
    elif name == "paste":
        cyl((0, 0, 0), min(hx, hz), y, mat("Paste", "#9da4ad", 0.2, 0.7), "y", 32)
    elif name in ("backplate", "backplate_v", "panel_v", "tray", "mon_base", "neck", "pad", "kb_base"):
        mt = m["dark"] if name in ("backplate", "backplate_v", "mon_base", "neck", "panel_v", "tray") else m["plastic"]
        if name == "pad":
            mt = m["rubber"]
        box((0, 0, 0), s, mt)
        if name == "panel_v":
            torus((0.3, 0.9, hz + 0.004), 0.55, 0.02, m["alu"], "z", 48, 6)
            for i in range(12):
                box((-hx + 0.4 + i * 0.12, -hy + 0.6, hz + 0.004), (0.05, 0.4, 0.008), m["rubber"], bevel=0)
        elif name == "tray":
            for sx in (-1, 1):
                for sz in (-1, 1):
                    cyl((sx * (hx - 0.2), -hy + 0.01, sz * (hz - 0.2)), 0.12, 0.02, m["rubber"], "y", 20)
        elif name == "backplate_v":
            for i in range(10):
                box((-hx * 0.85 + i * x * 0.19, 0, -hz - 0.003), (0.05, y * 0.5, 0.006), m["rubber"], bevel=0)
        elif name == "kb_base":
            box((hx * 0.8, hy + 0.002, -hz * 0.8), (0.1, 0.004, 0.03), m["green_led"], bevel=0)
    elif name == "vram":
        for a in range(4):
            for b in range(2):
                box((-hx + (a + 0.5) * x / 4, -hy + (b + 0.5) * y / 2, 0), (x / 4 * 0.7, y / 2 * 0.7, z), m["epoxy"])
    elif name in ("heatsink", "fins_y", "fins_z"):
        if name == "fins_y":
            n = int(max(4, min(28, y / 0.04)))
            for i in range(n):
                box((0, -hy + (i + 0.5) * y / n, 0), (x, y / n * 0.4, z), m["alu"], bevel=0.003)
            for k in range(4):
                cyl((-hx * 0.5 + k * x * 0.33, 0, 0), min(x, z) * 0.06, y, m["copper"], "y", 12)
        elif name == "fins_z":
            n = int(max(4, min(70, x / 0.035)))
            for i in range(n):
                box((-hx + (i + 0.5) * x / n, 0, 0), (x / n * 0.4, y, z), m["alu"], bevel=0.002)
            for k in range(3):
                cyl((0, -hy * 0.6 + k * y * 0.6, 0), min(y, z) * 0.12, x * 0.98, m["copper"], "x", 12)
        else:
            box((0, -hy * 0.7, 0), (x, y * 0.3, z), m["alu"])
            ax = _along(s)
            L = z if ax == "x" else x
            n = int(max(3, min(18, L / 0.035)))
            for i in range(n):
                t = -L / 2 + (i + 0.5) * L / n
                c = (0, hy * 0.15, t) if ax == "x" else (t, hy * 0.15, 0)
                sz = (x, y * 0.7, L / n * 0.45) if ax == "x" else (L / n * 0.45, y * 0.7, z)
                box(c, sz, m["alu"], bevel=0.003)
    elif name == "shroud":
        box((0, 0, 0), s, m["dark"], bevel=0.02)
        box((0, hy * 0.85, hz + 0.004), (x * 0.95, 0.03, 0.008), m["cyan"], bevel=0)
        box((hx * 0.7, -hy * 0.6, hz + 0.004), (0.3, 0.05, 0.008), m["cyan"], bevel=0)
        for i in range(6):
            box((-hx * 0.9 + i * x * 0.36, hy * 0.6, hz + 0.003), (0.15, 0.01, 0.006), m["alu"], rot=(0, 0.4, 0), bevel=0)
    elif name in ("fan_x", "fan_y", "fan_z"):
        ax = name[-1]
        dims = {"x": (z, y, x), "y": (x, z, y), "z": (x, y, z)}[ax]
        fan((0, 0, 0), min(dims[0], dims[1]), ax, m["plastic"], mat("Blade", "#2c2f36", 0.0, 0.45), m["rgb"], 7, dims[2])
    elif name == "heatpipes":
        for i in range(4):
            cyl((0, -hy * 0.4 + (i % 2) * hy * 0.7, -hz * 0.75 + i * z * 0.5), min(hy, hz) * 0.25, x, m["copper"], "x", 16)
        for i in range(4):
            cyl((-hx * 0.9, 0, -hz * 0.75 + i * z * 0.5), min(hy, hz) * 0.25, y * 0.9, m["copper"], "y", 16)
    elif name == "jacks":
        box((0, 0, 0), s, m["plastic"])
        cols = ["#3cc07a", "#ff7ab8", "#3a8bff", "#ffb84d"]
        for i in range(4):
            cyl((0, -hy * 0.7 + i * y * 0.45, -hz - 0.004), min(hx, hy) * 0.5, 0.012, mat("Jack%d" % i, cols[i], 0.0, 0.4), "z", 20)
            torus((0, -hy * 0.7 + i * y * 0.45, -hz - 0.006), min(hx, hy) * 0.35, 0.006, m["gold"], "z", 16, 6)
    elif name == "antenna":
        for sx in (-1, 1):
            cyl((sx * hx * 0.6, 0.05, 0), min(hx, hz) * 0.25, y * 0.9, m["rubber"], "y", 16)
            cyl((sx * hx * 0.6, -hy + 0.04, 0), min(hx, hz) * 0.35, 0.08, m["gold"], "y", 16)
    elif name == "pillar":
        box((0, 0, 0), s, m["alu"], bevel=0.02)
        box((0, 0, -hz - 0.003), (x * 0.3, y * 0.96, 0.006), m["rgb"], bevel=0)
    elif name == "frame_top":
        for e in ((0, 0, -hz + 0.08), (0, 0, hz - 0.08)):
            box(e, (x, y, 0.16), m["alu"], bevel=0.015)
        for e in ((-hx + 0.08, 0, 0), (hx - 0.08, 0, 0), (-0.75, 0, 0)):
            box(e, (0.16, y, z), m["alu"], bevel=0.015)
    elif name == "glass":
        box((0, 0, 0), s, m["glass"], bevel=0.004)
        box((0, hy - 0.02, 0), (x, 0.04, z * 1.2), m["alu"], bevel=0.004)
        box((0, -hy + 0.02, 0), (x, 0.04, z * 1.2), m["alu"], bevel=0.004)
    elif name in ("rgb_bar", "led_strip"):
        box((0, -hy * 0.3, 0), (x, y * 0.4, z), m["plastic"], bevel=0.004)
        n = 8
        ax = _along(s)
        for i in range(n):
            t = (i + 0.5) / n - 0.5
            hue = mat("LED%d" % i, "#%02x%02x%02x" % tuple(int(v * 255) for v in __import__("colorsys").hsv_to_rgb((0.72 + i * 0.07) % 1, 0.7, 1.0)), 0.0, 0.3,
                      emission="#%02x%02x%02x" % tuple(int(v * 255) for v in __import__("colorsys").hsv_to_rgb((0.72 + i * 0.07) % 1, 0.7, 1.0)), strength=3.0)
            c = (t * x, hy * 0.2, 0) if ax == "x" else (0, hy * 0.2, t * z)
            box(c, (x / n * 0.96, y * 0.6, z * 0.9) if ax == "x" else (x * 0.9, y * 0.6, z / n * 0.96), hue, bevel=0.002)
    elif name == "button":
        cyl((0, 0, 0), min(hx, hz), y, m["nickel"], "y", 40)
        torus((0, hy * 0.6, 0), min(hx, hz) * 0.8, 0.01, m["green_led"], "y", 32, 6)
    elif name == "mon_panel":
        # ince çerçeveli monitör gövdesi; ön yüzde ekran yuvası çukuru
        box((0, 0, -hz * 0.2), (x, y, z * 0.6), m["plastic"], bevel=0.02)
        for sgn in (-1, 1):
            box((0, sgn * (hy - 0.025), hz * 0.3), (x, 0.05, z * 0.4), m["plastic"], bevel=0.008)
            box((sgn * (hx - 0.025), 0, hz * 0.3), (0.05, y, z * 0.4), m["plastic"], bevel=0.008)
        box((0, -hy + 0.05, hz + 0.002), (0.2, 0.03, 0.004), m["white"], bevel=0)
    elif name == "screen":
        # ekran yüzü ayrı "MonitorScreen" yuvası (Godot BIOS SubViewport dokusunu buraya bağlar)
        box((0, 0, -hz * 0.25), (x, y, z * 0.5), m["epoxy"], bevel=0)
        box((0, 0, hz * 0.25), (x, y, z * 0.5), m["screen"], bevel=0)
    elif name == "keys":
        nx, nz = 15, 5
        for a in range(nx):
            for b in range(nz):
                kc = m["white"] if (a + b) % 7 != 0 else mat("AccentKey", "#ff9a3c", 0.0, 0.5)
                box((-hx + (a + 0.5) * x / nx, 0, -hz + (b + 0.5) * z / nz), (x / nx * 0.82, y, z / nz * 0.82), kc, bevel=0.01)
    elif name == "mouse":
        box((0, -hy * 0.3, 0), (x, y * 0.4, z), m["plastic"], bevel=0.02)
        cyl((0, hy * 0.1, 0), min(hx, hz) * 0.98, y * 0.55, m["plastic"], "y", 32)
        box((0, hy * 0.42, -hz * 0.45), (0.03, 0.03, 0.08), m["cyan"], bevel=0.005)
    elif name == "speaker":
        box((0, 0, 0), s, m["plastic"], bevel=0.02)
        for yy, rr in ((hy * 0.45, 0.3), (-hy * 0.25, 0.55)):
            cyl((0, yy, hz + 0.006), min(hx, hy) * rr, 0.012, m["dark"], "z", 32)
            torus((0, yy, hz + 0.008), min(hx, hy) * rr, 0.01, m["alu"], "z", 32, 6)
    elif name == "core":
        r = min(hx, hy, hz)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r * 0.75, location=G(0, 0, 0))
        _finish_obj(bpy.context.active_object, mat("Core", "#62f2ff", 0.2, 0.15, emission="#62f2ff", strength=4.0), 0.0)
        torus((0, 0, 0), r * 0.95, 0.02, m["gold"], "y", 48, 6)
        torus((0, 0, 0), r * 0.82, 0.02, m["rgb"], "x", 48, 6)
    else:
        box((0, 0, 0), s, body)

def build_part(i, row):
    name, sh, xs, ys, zs, col = row
    s = (xs[1] - xs[0], ys[1] - ys[0], zs[1] - zs[0])
    reset()
    global M
    M = pm()
    shape(sh, s, col)
    budget = BUDGET_PART_BIG if sh in BIG_SHAPES else BUDGET_PART
    r = finalize(os.path.join(OUT, "pc_parts", "part_%03d.glb" % (i + 1)), budget)
    r["name"] = name
    r["shape"] = sh
    r["size"] = [round(v, 4) for v in s]
    return r

# ---------------------------------------------------------------------------
def main():
    t0 = time.time()
    report = {"blender": bpy.app.version_string, "items": []}
    if "robot" in ONLY:
        report["items"].append(build_robot())
    if "components" in ONLY:
        for f in (build_smd, build_diode, build_capacitor, build_resistor, build_relay, build_bridge):
            report["items"].append(f())
    if "parts" in ONLY:
        for i, row in enumerate(pc_parts.P):
            report["items"].append(build_part(i, row))
    bad = [it for it in report["items"] if not it["ok"]]
    report["total_tris"] = sum(it["tris"] for it in report["items"])
    report["seconds"] = round(time.time() - t0, 1)
    with open(os.path.join(HERE, "blender_assets_report.json"), "w") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    for it in report["items"]:
        print("%-40s %6d / %6d üçgen %s" % (it["file"], it["tris"], it["budget"], "OK" if it["ok"] else "BÜTÇE AŞILDI"))
    print("toplam: %d model, %d üçgen, %.1f sn, bütçe aşımı: %d" % (len(report["items"]), report["total_tris"], report["seconds"], len(bad)))
    if bad:
        sys.exit(1)

main()
