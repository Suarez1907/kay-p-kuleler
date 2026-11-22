"""Kayıp Kuleler — Blender sinematik animasyon stüdyosu (Blender 5.x, ekransız).

    blender --background --python tools/blender_animation_studio.py -- [--only level,phase,robot,finale]

Çıktılar (godot-program/assets/animations/):
    level_end_rigs.glb           5 montaj arketipi × 240 kare (CameraRig, PartSocketAnchor, RobotHelperAnchor, SparkAnchor,
                                 vida/mandal/ray mekanizmaları). Parça Godot'da PartSocketAnchor altına bağlanır.
    phase_finale_01..09.glb      faz tamamlama sinematikleri × 360 kare (mekanik kilitler + özel kamera)
    robot_cinematic_anims.glb    iskeletli robot + robot_level_victory / robot_inspect_snap / robot_power_jump / robot_finale_wave
    grand_finale_100.glb         900 karelik büyük final: kamera, güç tuşu çapası, fan hızı ve faz uyanış veri kanalları
Kurallar: 30 FPS; tüm anahtar kareler BEZIER (hazırlık → hızlı oturma → mikro sekme ve yerleşme). Ağır geometri
dışa aktarılmaz; yalnızca rig, kamera ve küçük mekanik parçalar. Koordinatlar Godot düzenindedir (G() ile Blender'a).
Veri kanalları: Godot'nun kare-kare okuduğu boş düğümler (ör. FanSpeed.scale.x = 0..1, PhaseWake_NN.scale.x = parlaklık).
Sonunda tools/blender_animation_report.json yazılır (dosya, boyut, kare sayısı, NLA adları).
"""
import os
import sys
import math
import json
import time

os.environ["KK_NO_MAIN"] = "1"
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import mathutils  # noqa: E402
import blender_asset_generator as A  # noqa: E402
import pc_parts  # noqa: E402
from blender_asset_generator import mat, G, box, cyl, torus, sphere, reset  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def _arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(os.path.join(HERE, "..", "godot-program", "assets", "animations"))
ONLY = set(_arg("--only", "level,phase,robot,finale").split(","))
FPS = 30
REPORT = []

# ---------------------------------------------------------------------------
# yardımcılar
def scene_setup(frames):
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 1
    sc.frame_end = frames

def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(e)
    e.location = G(*loc)
    if parent:
        e.parent = parent
    return e

def mesh_obj(name, builder):
    """builder() sahneye mesh nesneleri ekler; tek nesnede birleştirilir, orijin (0,0,0)."""
    before = set(bpy.data.objects)
    builder()
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    bpy.ops.object.convert(target="MESH")
    if len(new) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    return o

def _fc(obj):
    a = obj.animation_data.action if obj.animation_data else None
    return A._fcurves(a) if a else []

def keys(obj, path, frames_vals, interp="BEZIER"):
    """frames_vals: [(kare, değer)] — değer: tuple (konum/dönüş/ölçek) Blender koordinatında."""
    for f, v in frames_vals:
        setattr(obj, path, v)
        obj.keyframe_insert(path, frame=f)
    for fc in _fc(obj):
        if fc.data_path == path:
            for kp in fc.keyframe_points:
                kp.interpolation = interp
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"

def locs(obj, fv):
    keys(obj, "location", [(f, mathutils.Vector(G(*v))) for f, v in fv])

def scales(obj, fv):
    keys(obj, "scale", [(f, (v, v, v) if isinstance(v, (int, float)) else v) for f, v in fv])

def rots(obj, fv):
    """dönüş Godot eksenlerinde (x, y, z) radyan → Blender (x, -z, y)"""
    keys(obj, "rotation_euler", [(f, mathutils.Euler((v[0], -v[2], v[1]))) for f, v in fv])

def look(cam_loc, target):
    d = mathutils.Vector(G(*target)) - mathutils.Vector(G(*cam_loc))
    return d.to_track_quat("-Z", "Y").to_euler()

def cam_path(cam, pts, shake=None):
    """pts: [(kare, kamera_konumu, hedef)] — her noktada konum + bakış; shake=(kare, genlik, süre)"""
    cam.rotation_mode = "XYZ"
    for f, p, tgt in pts:
        cam.location = G(*p)
        cam.keyframe_insert("location", frame=f)
        cam.rotation_euler = look(p, tgt)
        cam.keyframe_insert("rotation_euler", frame=f)
    if shake:
        f0, amp, dur = shake
        base = None
        for f, p, tgt in pts:
            if f <= f0:
                base = (p, tgt)
        if base:
            for k in range(dur + 1):
                fr = f0 + k
                a = amp * (1 - k / dur) * (1 if k % 2 == 0 else -1)
                p = (base[0][0] + a * 0.6, base[0][1] + a, base[0][2])
                cam.location = G(*p)
                cam.keyframe_insert("location", frame=fr)
    for fc in _fc(cam):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = "AUTO_CLAMPED"
            kp.handle_right_type = "AUTO_CLAMPED"
    # euler sarmasını düzelt (kesintisiz dönüş)
    for fc in _fc(cam):
        if fc.data_path == "rotation_euler":
            prev = None
            for kp in fc.keyframe_points:
                if prev is not None:
                    while kp.co[1] - prev > math.pi:
                        kp.co[1] -= 2 * math.pi
                    while kp.co[1] - prev < -math.pi:
                        kp.co[1] += 2 * math.pi
                prev = kp.co[1]

def push_nla(objs, name, frames):
    """Her nesnenin etkin aksiyonunu aynı adlı NLA izine taşır (glTF'te tek animasyon olur)."""
    for o in objs:
        ad = o.animation_data
        if ad is None or ad.action is None:
            continue
        act = ad.action
        act.name = "%s__%s" % (name, o.name)
        act.use_fake_user = True
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 1, act)
        st.action_frame_end = frames
        ad.action = None

def new_action_all(objs):
    for o in objs:
        if o.animation_data is None:
            o.animation_data_create()
        o.animation_data.action = None

def camera(name="CameraRig", lens=32):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.02
    cd.clip_end = 200
    c = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(c)
    return c

def export(path, frames, anims):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=True, export_cameras=True,
              export_bake_animation=True, export_optimize_animation_size=True, export_animation_mode="NLA_TRACKS",
              export_apply=True, export_materials="EXPORT", export_skins=True, export_frame_range=False,
              export_force_sampling=True, export_nla_strips=True, export_def_bones=False)
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)
    size = os.path.getsize(path)
    REPORT.append({"file": os.path.relpath(path, OUT), "bytes": size, "frames": frames, "fps": FPS, "animations": anims})
    print("  %-34s %7.1f KB  %4d kare  %s" % (os.path.relpath(path, OUT), size / 1024, frames, ", ".join(anims)))

def M():
    return {"steel": mat("Steel", "#b8bec7", 0.9, 0.3), "dark": mat("DarkMetal", "#30333b", 0.85, 0.4),
            "gold": mat("Gold", "#d4af37", 1.0, 0.25), "black": mat("BlackPlastic", "#1d1f26", 0.0, 0.6),
            "white": mat("WhitePlastic", "#ecedf0", 0.0, 0.5), "led": mat("RGB", "#00E5FF", 0.0, 0.3, emission="#00E5FF", strength=3.0),
            "amber": mat("Accent", "#F59E0B", 0.0, 0.3, emission="#F59E0B", strength=2.5), "glass": mat("TemperedGlass", "#bfe4ff", 0.0, 0.04, transmission=0.9, alpha=0.2)}

def bounds(ids):
    xs, ys, zs = [], [], []
    for i in ids:
        r = pc_parts.P[i - 1]
        xs += list(r[2]); ys += list(r[3]); zs += list(r[4])
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))

def center(i):
    r = pc_parts.P[i - 1]
    return tuple((a + b) / 2 for a, b in (r[2], r[3], r[4]))

# ---------------------------------------------------------------------------
# 1) SEVİYE SONU: 5 arketip × 240 kare, birim boyutlu parça için (Godot rig'i parça boyutuna göre ölçekler)
ARCHETYPES = [
    # ad, oturma karesi
    ("anim_drop_snap", 135),
    ("anim_angle_insert", 140),
    ("anim_vertical_slide", 145),
    ("anim_screw_lock", 160),
    ("anim_magnetic_orbit", 225),
]
LEVEL_FRAMES = 240

def level_end_rigs():
    reset()
    scene_setup(LEVEL_FRAMES)
    m = M()
    root = empty("LevelEndRig")
    sock = empty("PartSocketAnchor", parent=root)
    helper = empty("RobotHelperAnchor", (-1.1, 0.0, 0.7), parent=root)
    spark = empty("SparkAnchor", (0, 0.5, 0), parent=root)
    cam = camera()
    cam.parent = root
    # mekanizmalar: 4 köşe vidası, arka kilit pimi, iki ray, manyetik halka
    screws = []
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        s = mesh_obj("Screw_%d" % (k + 1), lambda: (cyl((0, 0.05, 0), 0.06, 0.1, m["steel"], "y", 16, 0.01),
                                                   box((0, 0.105, 0), (0.09, 0.012, 0.018), m["dark"], bevel=0)))
        s.parent = root
        s.location = G(sx * 0.42, 0.72, sz * 0.42)
        screws.append(s)
    pin = mesh_obj("LockPin", lambda: (cyl((0, 0, 0), 0.03, 0.22, m["steel"], "x", 16, 0.005), box((0.12, 0, 0.04), (0.04, 0.04, 0.1), m["gold"], bevel=0.005)))
    pin.parent = root
    pin.location = G(0.55, 0.12, -0.45)
    rails = mesh_obj("SlideRails", lambda: [box((sx * 0.56, 0.6, 0), (0.06, 1.2, 0.12), m["dark"], bevel=0.01) for sx in (-1, 1)])
    rails.parent = root
    ring = mesh_obj("MagnetRing", lambda: torus((0, 0, 0), 0.62, 0.02, m["led"], "y", 48, 6))
    ring.parent = root
    ring.location = G(0, 0.02, 0)
    mechs = screws + [pin, rails, ring]
    animated = [sock, helper, spark, cam] + mechs
    anims = []
    for name, snap in ARCHETYPES:
        new_action_all(animated)
        # mekanizmaların görünürlüğü (kullanılmayanlar ölçek 0)
        for o in mechs:
            use = (o in screws and name == "anim_screw_lock") or (o is pin and name == "anim_angle_insert") or \
                  (o is rails and name == "anim_vertical_slide") or (o is ring and name == "anim_magnetic_orbit")
            scales(o, [(1, 1.0 if use else 0.0), (LEVEL_FRAMES, 1.0 if use else 0.0)])
        if name == "anim_drop_snap":
            locs(sock, [(1, (0.3, 3.0, -0.4)), (60, (0.1, 1.2, -0.1)), (100, (0, 0.35, 0)), (122, (0, 0.33, 0)),
                        (snap - 4, (0, 0.18, 0)), (snap, (0, 0.0, 0)), (snap + 2, (0, 0.03, 0)), (snap + 5, (0, 0.0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
            rots(sock, [(1, (0.25, 0.6, 0.15)), (100, (0.02, 0.05, 0.0)), (snap, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
        elif name == "anim_angle_insert":
            locs(sock, [(1, (-1.5, 1.6, 0.6)), (70, (-0.35, 0.45, 0.1)), (110, (-0.08, 0.2, 0.0)), (snap - 3, (0, 0.06, 0)),
                        (snap, (0, 0, 0)), (snap + 2, (0, 0.02, 0)), (snap + 5, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
            rots(sock, [(1, (0, 0, math.radians(30))), (110, (0, 0, math.radians(30))), (snap - 3, (0, 0, math.radians(4))),
                        (snap, (0, 0, 0)), (snap + 2, (0, 0, math.radians(-1))), (snap + 5, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
            rots(pin, [(1, (0, 0, 0)), (snap + 6, (0, 0, 0)), (snap + 18, (math.pi / 2, 0, 0)), (snap + 21, (math.pi / 2 - 0.08, 0, 0)), (snap + 25, (math.pi / 2, 0, 0)), (LEVEL_FRAMES, (math.pi / 2, 0, 0))])
        elif name == "anim_vertical_slide":
            locs(sock, [(1, (0, 3.2, 0)), (50, (0, 1.6, 0)), (118, (0, 0.18, 0)), (snap - 6, (0, 0.06, 0)), (snap - 2, (0, 0.04, 0)),
                        (snap, (0, 0, 0)), (snap + 2, (0, 0.015, 0)), (snap + 5, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
        elif name == "anim_screw_lock":
            locs(sock, [(1, (0, 1.8, 0)), (60, (0, 0.4, 0)), (96, (0, 0.04, 0)), (104, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
            for k, s in enumerate(screws):
                f0 = 110 + k * 12
                bx, by, bz = (s.location.x, s.location.z, -s.location.y)
                locs(s, [(1, (bx, 0.72, bz)), (f0, (bx, 0.72, bz)), (f0 + 10, (bx, 0.5, bz)), (f0 + 12, (bx, 0.505, bz)), (LEVEL_FRAMES, (bx, 0.505, bz))])
                rots(s, [(1, (0, 0, 0)), (f0, (0, 0, 0)), (f0 + 10, (0, -4 * math.pi, 0)), (f0 + 12, (0, -4 * math.pi - 0.15, 0)), (LEVEL_FRAMES, (0, -4 * math.pi - 0.15, 0))])
        else:  # manyetik yörünge: kısa yay, son 15 karede hızlanıp yapışma
            pts = []
            for k in range(0, 11):
                f = 1 + k * 20
                if f > snap - 15:
                    break
                a = math.pi * 1.2 * (1 - k / 10)
                r = 1.6 * (1 - k / 12)
                pts.append((f, (math.cos(a) * r, 0.5 + 0.6 * (1 - k / 10), math.sin(a) * r)))
            pts += [(snap - 15, (0.25, 0.18, 0.1)), (snap - 3, (0.02, 0.02, 0.0)), (snap, (0, 0, 0)), (snap + 2, (0, 0.012, 0)), (snap + 5, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))]
            locs(sock, pts)
            scales(ring, [(1, 0.0), (snap - 20, 0.0), (snap - 8, 1.0), (snap, 0.6), (snap + 20, 0.0), (LEVEL_FRAMES, 0.0)])
            rots(sock, [(1, (0, 2.4, 0)), (snap, (0, 0, 0)), (LEVEL_FRAMES, (0, 0, 0))])
        # kıvılcım noktası: oturma anında parçanın üst yüzü
        locs(spark, [(1, (0, 0.5, 0)), (LEVEL_FRAMES, (0, 0.5, 0))])
        # robot yardımcısı: parçayı izler, oturunca yakına gelir
        locs(helper, [(1, (-1.6, 0, 1.0)), (snap - 20, (-1.1, 0, 0.7)), (snap + 30, (-0.9, 0, 0.6)), (LEVEL_FRAMES, (-0.9, 0, 0.6))])
        rots(helper, [(1, (0, 0.6, 0)), (snap, (0, 0.9, 0)), (LEVEL_FRAMES, (0, 0.9, 0))])
        # kamera: dolly-in (0–60) → makro + 4 karelik darbe (60–155) → kahraman açısı + yörünge kayması (155–240)
        cam_path(cam, [(1, (6.0, 4.5, 7.5), (0, 0.6, 0)), (60, (2.2, 1.6, 2.6), (0, 0.4, 0)), (snap - 25, (1.45, 0.9, 1.7), (0, 0.2, 0)),
                       (snap + 10, (1.35, 0.8, 1.6), (0, 0.15, 0)), (160, (1.6, 1.1, 1.9), (0, 0.2, 0)),
                       (205, (2.6, 1.9, 2.4), (0, 0.3, 0)), (LEVEL_FRAMES, (3.2, 2.2, 1.6), (0, 0.3, 0))], shake=(snap, 0.03, 4))
        push_nla(animated, name, LEVEL_FRAMES)
        anims.append(name)
    export(os.path.join(OUT, "level_end_rigs.glb"), LEVEL_FRAMES, anims)

# ---------------------------------------------------------------------------
# 2) FAZ SONU: 9 sinematik × 360 kare (mutlak PC koordinatlarında)
PHASE_FRAMES = 360

def phase_finale(ph):
    """ph: 1..9 — fazın 10. parçası (ph*10) PartSocketAnchor'a bağlanır."""
    reset()
    scene_setup(PHASE_FRAMES)
    m = M()
    part_id = ph * 10
    ids = list(range((ph - 1) * 10 + 1, ph * 10 + 1))
    (x0, x1), (y0, y1), (z0, z1) = bounds(ids)
    c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    ext = max(x1 - x0, y1 - y0, z1 - z0, 0.8)
    root = empty("PhaseFinaleRig")
    pc = center(part_id)
    sock = empty("PartSocketAnchor", pc, parent=root)
    spark = empty("SparkAnchor", (pc[0], pc[1] + 0.1, pc[2]), parent=root)
    helper = empty("RobotHelperAnchor", (c[0] - ext * 0.7, 0.0, c[2] + ext * 0.6), parent=root)
    cam = camera(lens=30)
    cam.parent = root
    mechs = []
    snap = 150
    lock_frames = []

    def mk(name, builder, at):
        o = mesh_obj(name, builder)
        o.parent = root
        o.location = G(*at)
        mechs.append(o)
        return o

    new_action_all([sock, spark, helper, cam])
    # parça inişi (her fazda): yukarıdan süzülüp oturur
    locs(sock, [(1, (pc[0], pc[1] + 2.0, pc[2])), (70, (pc[0], pc[1] + 0.5, pc[2])), (snap - 6, (pc[0], pc[1] + 0.06, pc[2])),
                (snap, pc), (snap + 2, (pc[0], pc[1] + 0.02, pc[2])), (snap + 5, pc), (PHASE_FRAMES, pc)])
    if ph == 1:   # anakart yükseltici ayakları dönerek kilitlenir; alçak PCB flyover
        for k, (sx, sz) in enumerate(((-1.45, 1.35), (1.45, 1.35), (-1.45, -1.35), (1.45, -1.35))):
            s = mk("StandoffScrew_%d" % k, lambda: (cyl((0, 0.03, 0), 0.07, 0.06, m["gold"], "y", 6, 0.005), cyl((0, 0.07, 0), 0.04, 0.03, m["steel"], "y", 16, 0.004)), (sx, 0.5, sz))
            f0 = 170 + k * 18
            locs(s, [(1, (sx, 0.5, sz)), (f0, (sx, 0.5, sz)), (f0 + 14, (sx, 0.36, sz)), (f0 + 16, (sx, 0.365, sz)), (PHASE_FRAMES, (sx, 0.365, sz))])
            rots(s, [(1, (0, 0, 0)), (f0, (0, 0, 0)), (f0 + 14, (0, -6 * math.pi, 0)), (PHASE_FRAMES, (0, -6 * math.pi, 0))])
            lock_frames.append(f0 + 14)
        cpts = [(1, (-2.6, 0.55, 2.2), (0, 0.4, 0)), (90, (-1.8, 0.5, 1.6), (0.4, 0.38, 0.6)), (snap, (0.2, 0.75, 2.0), pc),
                (240, (1.6, 0.45, 1.8), (-0.6, 0.38, -0.4)), (300, (2.2, 0.6, -0.4), (-0.4, 0.38, 0.2)), (PHASE_FRAMES, (3.4, 2.2, 3.0), (0, 0.4, 0))]
    elif ph == 2:  # modüler soketler sırayla takılır, güç anahtarı 0 → I
        for k in range(4):
            z = -0.4 + k * 0.18
            plug = mk("ModularPlug_%d" % k, lambda: (box((0, 0, 0), (0.12, 0.1, 0.12), m["black"], bevel=0.01), box((-0.08, 0, 0), (0.06, 0.04, 0.04), m["dark"], bevel=0)), (-1.4, 0.55, z))
            f0 = 170 + k * 16
            locs(plug, [(1, (-1.25, 0.55, z)), (f0, (-1.25, 0.55, z)), (f0 + 10, (-1.6, 0.55, z)), (f0 + 12, (-1.59, 0.55, z)), (PHASE_FRAMES, (-1.59, 0.55, z))])
            lock_frames.append(f0 + 10)
        sw = mk("PowerRocker", lambda: (box((0, 0, 0), (0.05, 0.14, 0.09), m["black"], bevel=0.008), box((-0.03, 0.03, 0), (0.012, 0.04, 0.05), m["white"], bevel=0)), (-3.14, 0.65, -1.35))
        rots(sw, [(1, (0, 0, -0.25)), (260, (0, 0, -0.25)), (266, (0, 0, 0.28)), (269, (0, 0, 0.22)), (PHASE_FRAMES, (0, 0, 0.25))])
        lock_frames.append(266)
        cpts = [(1, (0.5, 2.6, 3.4), (-2.0, 0.5, -0.4)), (snap, (1.6, 1.4, 1.2), pc), (220, (-0.6, 1.1, 1.4), (-1.6, 0.5, -0.1)),
                (262, (-4.2, 0.9, -0.6), (-3.1, 0.65, -1.35)), (PHASE_FRAMES, (-4.6, 1.6, 1.2), (-2.4, 0.5, -0.6))]
    elif ph == 3:  # CPU soket mandalı aşağı inip çentiğe takılır
        arm = mk("RetentionArm", lambda: (cyl((0, 0, 0.35), 0.018, 0.7, m["steel"], "z", 12, 0.004), box((0, 0, 0.72), (0.05, 0.02, 0.06), m["steel"], bevel=0.005)), (-0.9, 0.44, -0.8))
        frame_ = mk("LoadPlate", lambda: (box((0, 0, 0), (0.72, 0.015, 0.72), m["steel"], bevel=0.004)), (-0.5, 0.56, -0.45))
        rots(frame_, [(1, (-1.2, 0, 0)), (170, (-1.2, 0, 0)), (200, (0.0, 0, 0)), (203, (0.04, 0, 0)), (206, (0, 0, 0)), (PHASE_FRAMES, (0, 0, 0))])
        locs(frame_, [(1, (-0.5, 0.85, -0.85)), (170, (-0.5, 0.85, -0.85)), (200, (-0.5, 0.545, -0.45)), (PHASE_FRAMES, (-0.5, 0.545, -0.45))])
        rots(arm, [(1, (1.3, 0, 0)), (215, (1.3, 0, 0)), (245, (0.0, 0, 0)), (248, (-0.06, 0, 0)), (252, (0.0, 0, 0)), (PHASE_FRAMES, (0, 0, 0))])
        lock_frames += [200, 245]
        cpts = [(1, (1.6, 2.4, 2.0), (-0.5, 0.45, -0.45)), (snap, (0.6, 1.2, 0.9), pc), (195, (0.2, 1.0, 0.5), (-0.5, 0.5, -0.45)),
                (240, (-1.9, 0.75, -0.2), (-0.9, 0.48, -0.5)), (300, (-1.6, 1.0, 0.6), (-0.6, 0.5, -0.45)), (PHASE_FRAMES, (1.8, 2.2, 2.4), (-0.4, 0.5, -0.4))]
    elif ph == 4:  # RAM: iki yandaki çift kilit mandalı aynı anda kapanır
        for k, z in enumerate((-1.2, 0.0)):
            l = mk("RamLatch_%d" % k, lambda: (box((0, 0.06, 0), (0.08, 0.12, 0.04), m["white"], bevel=0.008),), (0.41, 0.4, z - 0.02))
            rots(l, [(1, (0, 0, 0.0)), (snap - 2, (0, 0, 0.0)), (snap + 6, (0.7, 0, 0)), (snap + 8, (0.62, 0, 0)), (PHASE_FRAMES, (0.65, 0, 0))])
        lock_frames.append(snap + 6)
        cpts = [(1, (2.6, 2.2, 1.4), (0.4, 0.8, -0.6)), (snap, (1.4, 1.0, 0.6), (0.4, 0.6, -0.6)), (230, (1.0, 1.4, -1.8), (0.4, 0.7, -0.5)), (PHASE_FRAMES, (2.8, 2.6, 2.2), (0.2, 0.7, -0.4))]
    elif ph == 5:  # M.2 soğutucu kapanır, tek vida sıkılır
        hs = mk("M2Heatsink", lambda: [box((0, 0.02, 0), (0.9, 0.04, 0.24), m["dark"], bevel=0.008)] + [box((-0.4 + i * 0.1, 0.05, 0), (0.03, 0.03, 0.22), m["steel"], bevel=0) for i in range(9)], (-0.95, 0.5, 0.9))
        rots(hs, [(1, (0, 0, -1.0)), (175, (0, 0, -1.0)), (205, (0, 0, 0)), (208, (0, 0, 0.05)), (211, (0, 0, 0)), (PHASE_FRAMES, (0, 0, 0))])
        sc = mk("M2Screw", lambda: (cyl((0, 0.02, 0), 0.035, 0.04, m["steel"], "y", 12, 0.004),), (-1.46, 0.5, 0.9))
        locs(sc, [(1, (-1.46, 0.52, 0.9)), (220, (-1.46, 0.52, 0.9)), (232, (-1.46, 0.41, 0.9)), (PHASE_FRAMES, (-1.46, 0.41, 0.9))])
        rots(sc, [(1, (0, 0, 0)), (220, (0, 0, 0)), (232, (0, -5 * math.pi, 0)), (PHASE_FRAMES, (0, -5 * math.pi, 0))])
        lock_frames += [205, 232]
        cpts = [(1, (0.4, 1.8, 2.6), (-1.0, 0.45, 0.9)), (snap, (-0.2, 1.0, 1.7), pc), (215, (-1.9, 0.9, 1.6), (-1.3, 0.45, 0.9)), (PHASE_FRAMES, (1.0, 2.0, 3.0), (-0.8, 0.5, 0.6))]
    elif ph == 6:  # GPU: PCIe mandalı + 2 sn fan test dönüşü
        latch = mk("PcieLatch", lambda: (box((0, 0.04, 0), (0.06, 0.08, 0.12), m["black"], bevel=0.008),), (1.25, 0.42, 0.25))
        rots(latch, [(1, (0, 0, 0.6)), (snap - 2, (0, 0, 0.6)), (snap + 5, (0, 0, 0)), (snap + 7, (0, 0, -0.06)), (PHASE_FRAMES, (0, 0, 0))])
        for k, x in enumerate((-0.6, 0.6)):
            f = mk("GpuFan_%d" % k, lambda: [box((0, 0, 0), (0.42, 0.012, 0.08), m["dark"], rot=(0, a, 0), bevel=0) for a in (0, 0.9, 1.8, 2.7, 3.6)], (x - 0.0, 0.95, 0.35))
            rots(f, [(1, (0, 0, 0)), (210, (0, 0, 0)), (230, (0, 6 * math.pi, 0)), (255, (0, 22 * math.pi, 0)), (270, (0, 26 * math.pi, 0)), (PHASE_FRAMES, (0, 27 * math.pi, 0))])
        lock_frames.append(snap + 5)
        cpts = [(1, (2.8, 2.2, 3.0), (0, 0.9, 0.3)), (snap, (1.9, 1.2, 1.4), (1.0, 0.7, 0.3)), (215, (0.4, 2.2, 2.4), (0, 0.95, 0.35)), (PHASE_FRAMES, (3.0, 2.8, 3.2), (0, 0.9, 0.2))]
    elif ph == 7:  # soğutma: kule soğutucu + kasa fanları senkron test turu
        for k, (x, y, z) in enumerate(((-0.5, 1.3, -0.45), (-3.0, 2.6, 0.0), (1.6, 3.4, 0.0), (-0.7, 4.0, 0.0))):
            f = mk("CoolFan_%d" % k, lambda: [box((0, 0, 0), (0.6, 0.012, 0.1), m["led"], rot=(0, a, 0), bevel=0) for a in (0, 1.0, 2.1, 3.1, 4.2)], (x, y, z))
            rots(f, [(1, (0, 0, 0)), (200, (0, 0, 0)), (230, (0, 8 * math.pi, 0)), (290, (0, 40 * math.pi, 0)), (PHASE_FRAMES, (0, 46 * math.pi, 0))])
        lock_frames.append(200)
        cpts = [(1, (3.0, 3.4, 4.6), (-0.6, 1.8, 0)), (snap, (2.4, 1.2, 1.6), pc), (240, (-0.4, 2.4, 5.4), (-0.7, 2.0, 0)), (PHASE_FRAMES, (4.0, 3.6, 5.0), (-0.6, 2.0, 0))]
    elif ph == 8:  # I/O: portlar ve altın ses jakları oturur, LED halkası sırayla yanar
        for k in range(6):
            y = 0.5 + k * 0.22
            j = mk("IoPort_%d" % k, lambda: (box((0, 0, 0), (0.06, 0.12, 0.2), m["gold"] if k >= 3 else m["steel"], bevel=0.005),), (-3.1, y, -1.6))
            f0 = 165 + k * 12
            locs(j, [(1, (-2.7, y, -1.6)), (f0, (-2.7, y, -1.6)), (f0 + 8, (-3.12, y, -1.6)), (f0 + 10, (-3.11, y, -1.6)), (PHASE_FRAMES, (-3.11, y, -1.6))])
            lock_frames.append(f0 + 8)
        for k in range(10):
            a = k * 2 * math.pi / 10
            led = mk("DiagLed_%02d" % k, lambda: (sphere((0, 0, 0), 0.03, m["amber"], 8),), (0.5 + math.cos(a) * 0.18, 0.4, -1.0 + math.sin(a) * 0.18))
            scales(led, [(1, 0.0), (250 + k * 6, 0.0), (254 + k * 6, 1.4), (258 + k * 6, 1.0), (PHASE_FRAMES, 1.0)])
        cpts = [(1, (-5.0, 2.2, -3.6), (-3.1, 1.0, -1.6)), (snap, (-4.2, 1.2, -2.8), (-3.1, 0.9, -1.6)), (245, (1.4, 1.4, -0.2), (0.5, 0.4, -1.0)), (PHASE_FRAMES, (-4.6, 2.6, 2.6), (-1.6, 1.2, -0.8))]
    else:  # ph 9: temperli cam panel raydan kayar, 4 parmak vidası sıkılır
        glass = mk("GlassPanel", lambda: (box((0, 0, 0), (4.6, 3.6, 0.03), m["glass"], bevel=0.01),), (-0.7, 2.1, 1.9))
        locs(glass, [(1, (-0.7, 2.1, 3.2)), (160, (-0.7, 2.1, 3.2)), (200, (-0.7, 2.1, 1.95)), (203, (-0.7, 2.1, 1.92)), (206, (-0.7, 2.1, 1.93)), (PHASE_FRAMES, (-0.7, 2.1, 1.93))])
        for k, (x, y) in enumerate(((-2.8, 3.7), (1.4, 3.7), (-2.8, 0.5), (1.4, 0.5))):
            t = mk("ThumbScrew_%d" % k, lambda: (cyl((0, 0, 0.03), 0.07, 0.05, m["steel"], "z", 16, 0.006),), (x, y, 2.2))
            f0 = 215 + k * 14
            locs(t, [(1, (x, y, 2.3)), (f0, (x, y, 2.3)), (f0 + 10, (x, y, 1.97)), (PHASE_FRAMES, (x, y, 1.97))])
            rots(t, [(1, (0, 0, 0)), (f0, (0, 0, 0)), (f0 + 10, (0, 0, 6 * math.pi)), (PHASE_FRAMES, (0, 0, 6 * math.pi))])
            lock_frames.append(f0 + 10)
        lock_frames.append(200)
        cpts = [(1, (4.0, 3.0, 7.5), (-0.7, 2.0, 1.9)), (snap, (2.2, 4.6, 3.0), pc), (195, (3.4, 2.4, 6.0), (-0.7, 2.1, 1.9)), (260, (2.0, 3.8, 3.2), (1.4, 3.7, 1.9)), (PHASE_FRAMES, (5.0, 3.6, 8.0), (-0.7, 2.0, 0.5))]
    locs(spark, [(1, (pc[0], pc[1] + 0.1, pc[2])), (PHASE_FRAMES, (pc[0], pc[1] + 0.1, pc[2]))])
    locs(helper, [(1, (c[0] - ext * 0.8, 0, c[2] + ext * 0.7)), (snap, (c[0] - ext * 0.6, 0, c[2] + ext * 0.55)), (PHASE_FRAMES, (c[0] - ext * 0.6, 0, c[2] + ext * 0.55))])
    cam_path(cam, cpts, shake=(snap, 0.03, 4))
    # oturma/kilit kareleri: Godot ses/haptik için veri kanalı (LockMarkers.scale.x = 1 o karelerde)
    marker = empty("LockMarkers", parent=root)
    new_action_all([marker])
    fv = [(1, 0.001)]
    for f in sorted(set([snap] + lock_frames)):
        fv += [(f - 1, 0.001), (f, 1.0), (f + 1, 0.001)]
    fv.append((PHASE_FRAMES, 0.001))
    keys(marker, "scale", [(f, (v, 1, 1)) for f, v in fv], interp="CONSTANT")
    animated = [sock, spark, helper, cam, marker] + mechs
    name = "phase_finale_%02d" % ph
    push_nla(animated, name, PHASE_FRAMES)
    REPORT_EXTRA[name] = {"snap": snap, "locks": sorted(set(lock_frames))}
    export(os.path.join(OUT, "%s.glb" % name), PHASE_FRAMES, [name])

REPORT_EXTRA = {}

# ---------------------------------------------------------------------------
# 3) ROBOT SİNEMATİK PAKETİ
def robot_actions(arm):
    pbs = arm.pose.bones
    for pb in pbs:
        pb.rotation_mode = "XYZ"
    K = A._key
    def act(name, frames, fn):
        a = bpy.data.actions.new(name)
        arm.animation_data_create()
        arm.animation_data.action = a
        for pb in pbs:
            pb.location = (0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
        fn()
        for fc in A._fcurves(a):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
        a.use_fake_user = True
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 1, a)
        arm.animation_data.action = None
    def victory():
        for f, y in ((1, 0), (6, -0.04), (14, 0.28), (20, 0.0), (23, -0.03), (28, 0.12), (34, 0.0), (45, 0.0)):
            K(pbs["root"], f, loc=(0, y, 0))
        for f, r in ((1, 0), (8, 0.35), (14, -0.35), (20, 0.35), (26, -0.35), (32, 0.2), (45, 0)):
            K(pbs["antenna"], f, rot=(r, 0, r * 0.6))
        for f, up in ((1, 0.0), (12, 2.6), (24, 2.2), (34, 2.6), (45, 0.0)):
            K(pbs["arm.L"], f, rot=(0, 0, -up))
            K(pbs["arm.R"], f, rot=(0, 0, up))
    def inspect():
        for f, r, y in ((1, 0, 0), (18, 0.45, -0.03), (40, 0.5, -0.04), (52, 0.2, -0.02), (58, 0.45, -0.03), (64, 0.15, -0.01), (80, 0, 0)):
            K(pbs["head"], f, rot=(r, 0, 0))
            K(pbs["body"], f, loc=(0, y, 0), rot=(r * 0.3, 0, 0))
        for f, r in ((1, 0), (20, 0.4), (60, 0.4), (80, 0)):
            K(pbs["arm.R"], f, rot=(-r, 0, 0.3 * r))
    def power_jump():
        for f, y, rx in ((1, 0, 0), (10, -0.08, 0.15), (16, -0.1, 0.2), (24, 0.55, -0.15), (32, 0.62, 0.0), (40, 0.05, 0.1), (43, -0.06, 0.12), (50, 0.0, 0.0), (60, 0.0, 0.0)):
            K(pbs["root"], f, loc=(0, y, 0), rot=(rx, 0, 0))
        for f, up in ((1, 0.3), (16, -0.4), (24, 2.4), (40, 1.0), (60, 0.3)):
            K(pbs["arm.L"], f, rot=(0, 0, -up))
            K(pbs["arm.R"], f, rot=(0, 0, up))
    def finale_wave():
        for f, a in ((1, 0), (20, math.pi), (30, math.pi * 2), (90, math.pi * 2)):
            K(pbs["root"], f, rot=(0, a, 0))
        for f, r in ((30, 2.2), (38, 2.9), (46, 2.2), (54, 2.9), (62, 2.2), (70, 2.9), (90, 0.2)):
            K(pbs["arm.R"], f, rot=(0, 0, r))
        for f, y in ((1, 0), (10, 0.15), (20, 0), (30, 0.1), (36, 0), (90, 0)):
            K(pbs["body"], f, loc=(0, y, 0))
        for f, r in ((30, 0.0), (45, 0.25), (60, -0.1), (90, 0.0)):
            K(pbs["head"], f, rot=(r, 0.2, 0))
    act("robot_level_victory", 45, victory)
    act("robot_inspect_snap", 80, inspect)
    act("robot_power_jump", 60, power_jump)
    act("robot_finale_wave", 90, finale_wave)

def robot_pack():
    reset()
    bpy.context.scene.render.fps = FPS
    parts = A._robot_parts()
    for bone, o in parts:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target="MESH")
        vg = o.vertex_groups.new(name=bone)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    objs = [o for _, o in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = "RobotMesh"
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    tri = mesh.modifiers.new("Triangulate", "TRIANGULATE")
    tri.keep_custom_normals = True
    bpy.ops.object.convert(target="MESH")
    ad = bpy.data.armatures.new("RobotRig")
    arm = bpy.data.objects.new("RobotRig", ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in A.BONES.items():
        eb = ad.edit_bones.new(name)
        eb.head = G(*h)
        eb.tail = G(*t)
    for name, (h, t, parent) in A.BONES.items():
        if parent:
            ad.edit_bones[name].parent = ad.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.parent = arm
    am = mesh.modifiers.new("Armature", "ARMATURE")
    am.object = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    robot_actions(arm)
    bpy.ops.object.mode_set(mode="OBJECT")
    path = os.path.join(OUT, "robot_cinematic_anims.glb")
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = dict(filepath=path, export_format="GLB", export_yup=True, export_apply=False, export_animations=True,
              export_animation_mode="NLA_TRACKS", export_skins=True, export_def_bones=False, export_optimize_animation_size=True,
              export_materials="EXPORT")
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props or k == "filepath"})
    REPORT.append({"file": "robot_cinematic_anims.glb", "bytes": os.path.getsize(path), "frames": 90, "fps": FPS,
                   "animations": ["robot_level_victory", "robot_inspect_snap", "robot_power_jump", "robot_finale_wave"]})
    print("  %-34s %7.1f KB" % ("robot_cinematic_anims.glb", os.path.getsize(path) / 1024))

# ---------------------------------------------------------------------------
# 4) BÜYÜK FİNAL: 900 kare (30 sn) — kamera + güç tuşu + fan hızı + faz uyanış kanalları
FINALE_FRAMES = 900
FINALE_EVENTS = {"power": 130, "fans": 185, "bios": 450, "desktop": 670}

def grand_finale():
    reset()
    scene_setup(FINALE_FRAMES)
    root = empty("GrandFinaleRig")
    cam = camera(lens=30)
    cam.parent = root
    pw = center(90)
    scr = center(94)
    kb = center(95)
    btn = empty("PowerButtonAnchor", parent=root)        # Godot: güç tuşu parçasına yerel ofset (y)
    fan = empty("FanSpeed", parent=root)                  # scale.x = 0..1 (1 = 1800 RPM)
    led = empty("PowerLed", parent=root)                  # scale.x = LED parlaklığı
    kbw = empty("KeyboardWave", parent=root)              # scale.x = 0..1 klavye ışık dalgası ilerlemesi
    wakes = [empty("PhaseWake_%02d" % (k + 1), parent=root) for k in range(10)]
    robot = empty("RobotFinaleAnchor", parent=root)       # robotun konumu (Godot robotu buraya taşır)
    new_action_all([cam, btn, fan, led, kbw, robot] + wakes)
    top = (pw[0], pw[1] + 0.03, pw[2])
    # kamera koreografisi
    cam_path(cam, [
        (1, (5.5, 6.0, 7.5), (0.0, 2.0, 0.0)),
        (70, (2.6, 5.0, 3.2), top),
        (125, (2.1, 4.6, 2.5), top),
        (150, (2.15, 4.62, 2.55), top),
        (200, (2.4, 4.4, 4.2), (-0.5, 2.6, 0.5)),
        (300, (-0.6, 2.4, 5.4), (-0.7, 2.0, 0.0)),          # vinç inişi: cam panelin önü
        (420, (-0.5, 2.0, 3.6), (-0.6, 1.6, 0.0)),
        (520, (2.2, 2.2, 3.4), scr),
        (600, (scr[0], scr[1] + 0.05, scr[2] + 2.55), scr),  # monitör kadrajın %80'i
        (665, (scr[0], scr[1] + 0.05, scr[2] + 2.5), scr),
        (760, (2.6, 2.6, 6.2), (2.0, 1.6, -0.2)),
        (FINALE_FRAMES, (1.8, 3.0, 8.2), (1.4, 1.6, -0.2)),
    ], shake=(FINALE_EVENTS["power"], 0.02, 4))
    # güç tuşu: 4 mm (0.04 birim) içeri göçüp yaylanır
    keys(btn, "location", [(1, G(0, 0, 0)), (FINALE_EVENTS["power"] - 1, G(0, 0, 0)), (FINALE_EVENTS["power"] + 2, G(0, -0.04, 0)),
                           (FINALE_EVENTS["power"] + 8, G(0, 0.006, 0)), (FINALE_EVENTS["power"] + 12, G(0, 0, 0)), (FINALE_FRAMES, G(0, 0, 0))])
    keys(led, "scale", [(1, (0.001, 1, 1)), (FINALE_EVENTS["power"], (0.001, 1, 1)), (FINALE_EVENTS["power"] + 6, (1.0, 1, 1)), (FINALE_FRAMES, (1.0, 1, 1))])
    # fanlar: üstel hızlanma 0 → 1 (1800 RPM)
    fv = [(1, 0.001), (FINALE_EVENTS["fans"], 0.001)]
    for k in range(1, 9):
        f = FINALE_EVENTS["fans"] + k * 25
        fv.append((f, 1 - math.exp(-k / 2.2)))
    fv.append((FINALE_FRAMES, 1.0))
    keys(fan, "scale", [(f, (v, 1, 1)) for f, v in fv])
    # faz uyanış dalgası: 1'den 10'a sırayla
    for k, w in enumerate(wakes):
        f0 = 200 + k * 20
        keys(w, "scale", [(1, (0.001, 1, 1)), (f0, (0.001, 1, 1)), (f0 + 6, (1.3, 1, 1)), (f0 + 18, (0.001, 1, 1)), (FINALE_FRAMES, (0.001, 1, 1))])
    keys(kbw, "scale", [(1, (0.001, 1, 1)), (470, (0.001, 1, 1)), (560, (1.0, 1, 1)), (FINALE_FRAMES, (1.0, 1, 1))])
    # robot: güç tuşuna zıplar (power_jump ~kare 100–130), sonra monitörün yanına (wave ~kare 760)
    from_p = (pw[0] - 0.9, pw[1] + 0.03, pw[2] - 0.2)
    side = (scr[0] + 1.75, 0.0, scr[2] + 0.8)
    locs(robot, [(1, from_p), (100, from_p), (118, (pw[0] - 0.4, pw[1] + 0.6, pw[2] - 0.1)), (FINALE_EVENTS["power"], top),
                 (680, top), (720, (side[0] - 0.8, 2.2, side[2])), (745, side), (FINALE_FRAMES, side)])
    animated = [cam, btn, fan, led, kbw, robot] + wakes
    push_nla(animated, "grand_finale_100", FINALE_FRAMES)
    export(os.path.join(OUT, "grand_finale_100.glb"), FINALE_FRAMES, ["grand_finale_100"])

# ---------------------------------------------------------------------------
def main():
    t0 = time.time()
    if "level" in ONLY:
        level_end_rigs()
    if "phase" in ONLY:
        for ph in range(1, 10):
            phase_finale(ph)
    if "robot" in ONLY:
        robot_pack()
    if "finale" in ONLY:
        grand_finale()
    rep = {"fps": FPS, "items": REPORT, "level_snaps": dict(ARCHETYPES), "phase_events": REPORT_EXTRA, "finale_events": FINALE_EVENTS,
           "total_kb": round(sum(r["bytes"] for r in REPORT) / 1024, 1), "seconds": round(time.time() - t0, 1)}
    with open(os.path.join(HERE, "blender_animation_report.json"), "w") as f:
        json.dump(rep, f, ensure_ascii=False, indent=1)
    bad = [r for r in REPORT if r["bytes"] == 0 or not r["animations"]]
    print("toplam %d dosya, %.1f KB, %.1f sn, sorunlu %d" % (len(REPORT), rep["total_kb"], rep["seconds"], len(bad)))
    if bad:
        sys.exit(1)

if __name__ == "__main__":
    main()
