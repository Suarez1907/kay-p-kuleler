"""Kayıp Kuleler — Blender ile ikinci dalga varlıklar (Blender 5.x, ekransız, Cycles CPU).

    blender --background --python tools/blender_scene_generator.py -- [--only puzzle,pcb,workshop,title,phases,themes,icon,cmds,store]

Üretilenler (godot-program/ altında; hepsi isteğe bağlıdır, yoksa oyun prosedürel sürüme döner):
    assets/models/puzzle/{stairs,goal_crystal,crate,lever_base,lever_arm,crank_base,crank_wheel,handle,
                          slider,portal,plate,crumble,phantom}.glb      bulmaca nesneleri
    assets/textures/pbr/pcb_detail/{albedo,normal,mask}.png            PCB zemininin pişirilmiş dokusu (4×4 birim, döşenebilir)
    assets/models/scenes/workshop.glb                                    montaj atölyesi (masa, raflar, havya, alet çantası, softbox)
    assets/models/scenes/title_diorama.glb                               başlık ekranı: devre adasındaki kayıp kule
    assets/ui/phase_01.png … phase_10.png                                faz adası ikonları (seviye haritası)
    assets/models/themes/theme_01.glb … theme_15.glb                     15 bölüm temasının dekor setleri
    launcher/icon_*.png                                                  uygulama ikonu (Blender render)
    assets/ui/cmd_<C>.png                                                komut düğmesi ikonları (F L R J A W 1 2 C)
    ../store/feature_graphic.png                                         Google Play tanıtım görseli (1024×500)
Ortak yardımcılar (malzeme, kutu, silindir, pah, finalize) tools/blender_asset_generator.py'den gelir.
"""
import os
import sys
import math
import json
import random
import time

os.environ["KK_NO_MAIN"] = "1"
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import blender_asset_generator as A  # noqa: E402
from blender_asset_generator import mat, G, box, cyl, cone, torus, sphere, reset, finalize  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def _arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
ROOT = os.path.abspath(os.path.join(HERE, "..", "godot-program"))
MODELS = os.path.join(ROOT, "assets", "models")
ONLY = set(_arg("--only", "puzzle,pcb,workshop,title,phases,themes,backdrops,icon,cmds,store").split(","))
A.OUT = MODELS
SCRATCH = os.path.abspath(_arg("--tmp", os.path.join(HERE, "..", ".blender_tmp")))

BUDGET_PUZZLE = 6000 * A.DETAIL * 2
BUDGET_SCENE = 40000 * A.DETAIL * 2
BUDGET_THEME = 8000 * A.DETAIL * 2

# ---------------------------------------------------------------------------
# ortak malzemeler
def M():
    return {
        "pcb": mat("PCB", "#0b3b2a", 0.0, 0.55), "pcb2": mat("PCBLight", "#14583e", 0.0, 0.5),
        "copper": mat("Copper", "#c87533", 0.95, 0.28), "gold": mat("Gold", "#d4af37", 1.0, 0.25),
        "tin": mat("Pins", "#d9dde3", 0.95, 0.22), "epoxy": mat("Epoxy", "#1a1c20", 0.0, 0.72),
        "alu": mat("Aluminum", "#b8bec7", 0.9, 0.3), "dark": mat("DarkMetal", "#30333b", 0.85, 0.4),
        "silk": mat("Silkscreen", "#eef0ea", 0.0, 0.6), "rubber": mat("Rubber", "#141518", 0.0, 0.85),
        "white": mat("WhitePlastic", "#ecedf0", 0.0, 0.5), "red": mat("RedPlastic", "#d8383a", 0.0, 0.45),
        "glass": mat("Glass", "#bfe4ff", 0.0, 0.04, transmission=0.9, alpha=0.25),
        "amber": mat("AmberCeramic", "#ff9a3c", 0.1, 0.45),
    }

# ---------------------------------------------------------------------------
# 1) Bulmaca nesneleri (taban y=0, x/z ortalı; Godot tarafı hedef kutuya göre ölçekler)
def p_stairs():
    """PCB yığını basamaklar: 3 basamak, +X yönüne yükselir (Godot'daki dönüş ofsetiyle aynı)."""
    reset(); m = M()
    for k in range(3):
        h = (k + 1) / 3.0
        x = -1.0 / 3.0 + k / 3.0
        box((x, h / 2, 0), (1 / 3.0, h, 1.0), m["pcb"], bevel=0.012)
        # basamak burnu: bakır şerit + altın ped dizisi
        box((x - 1 / 6.0 + 0.02, h - 0.004, 0), (0.035, 0.012, 0.96), m["copper"], bevel=0.003)
        for z in (-0.3, -0.1, 0.1, 0.3):
            box((x + 0.04, h + 0.002, z), (0.12, 0.008, 0.07), m["gold"], bevel=0)
        # yan yüzde katman çizgileri (çok katmanlı kart)
        for j in range(int(h * 9)):
            y = 0.06 + j * 0.105
            if y < h - 0.04:
                for sz in (-1, 1):
                    box((x, y, sz * 0.501), (1 / 3.0 - 0.02, 0.012, 0.004), m["copper"], bevel=0)
    # veri yolu rampası: yan yüzde paralel bakır hatlar
    for i in range(5):
        box((0.0, 0.5 + i * 0.05, -0.506), (0.9, 0.012, 0.004), m["gold"], bevel=0)
    return finalize(os.path.join(MODELS, "puzzle", "stairs.glb"), BUDGET_PUZZLE)

def p_goal():
    """Hedef: kuantum işlemci — altın bacaklı kılıf, cam kubbe, ışıyan çekirdek (CrystalCore → tema rengi)."""
    reset(); m = M()
    core = mat("CrystalCore", "#7df9ff", 0.1, 0.1, emission="#7df9ff", strength=4.0)
    box((0, 0.05, 0), (0.46, 0.1, 0.46), m["pcb2"], bevel=0.015)
    box((0, 0.13, 0), (0.36, 0.06, 0.36), m["epoxy"], bevel=0.012)
    for i in range(6):
        t = -0.2 + i * 0.08
        for sgn in (-1, 1):
            box((t, 0.06, sgn * 0.25), (0.035, 0.03, 0.07), m["gold"], bevel=0.004)
            box((sgn * 0.25, 0.06, t), (0.07, 0.03, 0.035), m["gold"], bevel=0.004)
    torus((0, 0.17, 0), 0.15, 0.018, m["gold"], "y", 40, 8)
    # kristal çekirdek: çift koni (sekizyüzlü), üstünde yörünge halkası
    cone((0, 0.32, 0), 0.13, 0.0, 0.26, core, "y", 6)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.13, radius2=0.0, depth=0.14, location=G(0, 0.12, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, core, 0)
    torus((0, 0.3, 0), 0.2, 0.01, m["gold"], "x", 40, 6)
    torus((0, 0.3, 0), 0.2, 0.01, m["gold"], "z", 40, 6)
    return finalize(os.path.join(MODELS, "puzzle", "goal_crystal.glb"), BUDGET_PUZZLE)

def p_crate():
    """İtilebilir kasa: CPU paketi (yeşil alt tabaka, nikel IHS, altın kontak ızgarası)."""
    reset(); m = M()
    s = 0.84
    box((0, 0.09, 0), (s, 0.18, s), m["pcb2"], bevel=0.02)
    box((0, 0.42, 0), (s * 0.86, 0.5, s * 0.86), m["epoxy"], bevel=0.025)
    box((0, 0.76, 0), (s * 0.92, 0.16, s * 0.92), m["alu"], bevel=0.03)
    box((0, 0.84, 0), (s * 0.7, 0.012, s * 0.7), m["tin"], bevel=0.004)
    cyl((-0.3, 0.848, -0.3), 0.03, 0.01, m["gold"], "y", 3)
    for i in range(7):
        for j in range(7):
            if (i + j) % 2 == 0:
                box((-0.33 + i * 0.11, 0.004, -0.33 + j * 0.11), (0.05, 0.01, 0.05), m["gold"], bevel=0)
    for sgn in (-1, 1):
        for i in range(6):
            box((-0.3 + i * 0.12, 0.42, sgn * s * 0.43), (0.06, 0.4, 0.01), m["dark"], bevel=0)
            box((sgn * s * 0.43, 0.42, -0.3 + i * 0.12), (0.01, 0.4, 0.06), m["dark"], bevel=0)
    return finalize(os.path.join(MODELS, "puzzle", "crate.glb"), BUDGET_PUZZLE)

def p_lever():
    """Kol: sigorta yuvası (taban) + sigorta şalteri (kol; pivot tabanda)."""
    reset(); m = M()
    box((0, 0.06, 0), (0.6, 0.12, 0.4), m["epoxy"], bevel=0.02)
    box((0, 0.14, 0), (0.42, 0.05, 0.26), m["dark"], bevel=0.01)
    for sx in (-1, 1):
        box((sx * 0.2, 0.2, 0), (0.06, 0.1, 0.2), m["tin"], bevel=0.008)
        box((sx * 0.25, 0.125, 0.16), (0.06, 0.01, 0.04), m["copper"], bevel=0)
    cyl((0, 0.18, 0), 0.06, 0.32, m["dark"], "x", 20)
    box((-0.22, 0.122, -0.16), (0.08, 0.004, 0.03), m["silk"], bevel=0)
    base = finalize(os.path.join(MODELS, "puzzle", "lever_base.glb"), BUDGET_PUZZLE)
    reset(); m = M()
    cyl((0, 0.03, 0), 0.05, 0.22, m["tin"], "x", 20)
    box((0, 0.27, 0), (0.07, 0.5, 0.07), m["red"], bevel=0.02)
    cyl((0, 0.15, 0), 0.06, 0.12, m["glass"], "y", 20)
    cyl((0, 0.15, 0), 0.012, 0.11, m["copper"], "y", 8)
    sphere((0, 0.56, 0), 0.1, m["red"], 20)
    return [base, finalize(os.path.join(MODELS, "puzzle", "lever_arm.glb"), BUDGET_PUZZLE)]

def p_crank():
    """Çark: soğutucu tabanlı mil + dişli kasnak."""
    reset(); m = M()
    cyl((0, 0.07, 0), 0.36, 0.14, m["dark"], "y", 40)
    for k in range(12):
        a = k * math.pi / 6
        box((math.cos(a) * 0.31, 0.16, math.sin(a) * 0.31), (0.1, 0.05, 0.03), m["alu"], rot=(0, 0, -a), bevel=0.004)
    cyl((0, 0.33, 0), 0.07, 0.42, m["alu"], "y", 20)
    torus((0, 0.15, 0), 0.2, 0.02, m["copper"], "y", 32, 8)
    base = finalize(os.path.join(MODELS, "puzzle", "crank_base.glb"), BUDGET_PUZZLE)
    reset(); m = M()
    torus((0, 0.07, 0), 0.3, 0.05, m["copper"], "y", 40, 10)
    for k in range(18):
        a = k * 2 * math.pi / 18
        box((math.cos(a) * 0.35, 0.07, math.sin(a) * 0.35), (0.05, 0.08, 0.05), m["copper"], rot=(0, 0, -a), bevel=0.006)
    for k in range(3):
        box((0, 0.07, 0), (0.6, 0.05, 0.06), m["alu"], rot=(0, 0, k * math.pi / 3), bevel=0.01)
    cyl((0, 0.07, 0), 0.08, 0.12, m["dark"], "y", 24)
    sphere((0.3, 0.14, 0), 0.07, m["amber"], 16)
    return [base, finalize(os.path.join(MODELS, "puzzle", "crank_wheel.glb"), BUDGET_PUZZLE)]

def p_handle():
    """Döner platform tutamacı: fan çerçevesi gibi halka + 4 kol + 4 ışıklı topuz."""
    reset(); m = M()
    led = mat("HandleLED", "#fff6e8", 0.0, 0.3, emission="#ffd9a8", strength=2.0)
    torus((0, 0.1, 0), 0.95, 0.07, m["dark"], "y", 64, 12)
    for k in range(2):
        box((0, 0.1, 0), (1.9, 0.07, 0.1), m["alu"], rot=(0, 0, k * math.pi / 2), bevel=0.02)
    for k in range(4):
        a = k * math.pi / 2
        sphere((math.cos(a) * 0.95, 0.1, math.sin(a) * 0.95), 0.14, led, 20)
    for k in range(24):
        a = k * 2 * math.pi / 24
        box((math.cos(a) * 0.95, 0.18, math.sin(a) * 0.95), (0.03, 0.02, 0.12), m["copper"], rot=(0, 0, -a), bevel=0)
    cyl((0, 0.1, 0), 0.18, 0.2, m["dark"], "y", 32)
    return finalize(os.path.join(MODELS, "puzzle", "handle.glb"), BUDGET_PUZZLE)

def p_slider():
    """Kayar blok: ray üzerinde taşıyıcı (lineer kızak)."""
    reset(); m = M()
    box((0, 0.5, 0), (0.98, 0.98, 0.98), m["pcb"], bevel=0.04)
    box((0, 0.76, 0), (1.0, 0.12, 1.0), m["white"], bevel=0.02)
    for sz in (-1, 1):
        box((0, 0.2, sz * 0.4), (1.0, 0.08, 0.1), m["alu"], bevel=0.015)
        for x in (-0.3, 0.0, 0.3):
            cyl((x, 0.2, sz * 0.47), 0.05, 0.04, m["dark"], "z", 16)
    for x in (-0.36, -0.12, 0.12, 0.36):
        box((x, 0.985, 0), (0.12, 0.01, 0.8), m["gold"], bevel=0)
    return finalize(os.path.join(MODELS, "puzzle", "slider.glb"), BUDGET_PUZZLE)

def p_portal():
    """Işınlayıcı: fiber optik halka (PortalGlow → Godot'da portal rengi)."""
    reset(); m = M()
    glow = mat("PortalGlow", "#5ef0ff", 0.0, 0.2, emission="#5ef0ff", strength=3.0)
    torus((0, 0.05, 0), 0.32, 0.05, m["dark"], "y", 48, 10)
    torus((0, 0.08, 0), 0.32, 0.025, glow, "y", 48, 8)
    for k in range(16):
        a = k * 2 * math.pi / 16
        cyl((math.cos(a) * 0.32, 0.1, math.sin(a) * 0.32), 0.012, 0.03, glow, "y", 8)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        box((math.cos(a) * 0.4, 0.04, math.sin(a) * 0.4), (0.08, 0.06, 0.05), m["alu"], rot=(0, 0, -a), bevel=0.01)
    return finalize(os.path.join(MODELS, "puzzle", "portal.glb"), BUDGET_PUZZLE)

def p_plate():
    """Basınç plakası: membran tuş (PlateLED basılınca yanar)."""
    reset(); m = M()
    led = mat("PlateLED", "#ffb84d", 0.0, 0.3, emission="#ffb84d", strength=0.0)
    cyl((0, 0.025, 0), 0.4, 0.05, m["dark"], "y", 48)
    cyl((0, 0.06, 0), 0.33, 0.04, m["rubber"], "y", 48)
    torus((0, 0.052, 0), 0.36, 0.014, led, "y", 48, 6)
    for k in range(3):
        torus((0, 0.081, 0), 0.08 + k * 0.08, 0.006, m["copper"], "y", 40, 4)
    return finalize(os.path.join(MODELS, "puzzle", "plate.glb"), BUDGET_PUZZLE)

def p_crumble():
    """Çöken blok: çatlamış, yanık izli eski kart parçası."""
    reset(); m = M()
    burnt = mat("Burnt", "#2a1d14", 0.0, 0.9)
    rnd = random.Random(7)
    n = 3
    for i in range(n):
        for j in range(n):
            for k in range(n):
                s = 1.0 / n
                c = (-0.5 + (i + 0.5) * s, (k + 0.5) * s, -0.5 + (j + 0.5) * s)
                jit = 0.94 - rnd.random() * 0.05
                box(c, (s * jit, s * jit, s * jit), burnt if rnd.random() < 0.25 else m["pcb"], bevel=0.01)
    for z in (-0.3, 0.05, 0.32):
        box((0, 1.0, z), (0.9, 0.012, 0.04), m["copper"], bevel=0)
    return finalize(os.path.join(MODELS, "puzzle", "crumble.glb"), BUDGET_PUZZLE)

def p_phantom():
    """Hayalet blok çerçevesi: köşe ve kenar ışık çubukları (PhantomFrame → Godot'da bakış rengi)."""
    reset()
    f = mat("PhantomFrame", "#ffffff", 0.0, 0.3, emission="#ffffff", strength=2.0)
    h = 0.52
    t = 0.04
    for a in (-h, h):
        for b in (-h, h):
            box((a, h, b), (t, 2 * h, t), f, bevel=0.008)
            box((0, h + a, b), (2 * h, t, t), f, bevel=0.008)
            box((a, h + b, 0), (t, t, 2 * h), f, bevel=0.008)
    return finalize(os.path.join(MODELS, "puzzle", "phantom.glb"), BUDGET_PUZZLE)

# ---------------------------------------------------------------------------
# 2) PCB dokusu: 4×4 birimlik döşenebilir kart geometrisi Cycles ile tepeden "pişirilir" (renk + yükseklik +
#    maske), yükseklikten normal haritası çıkarılır.
def _ortho_cam(cx, cy, size, z=10.0):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size
    cam.location = (cx, cy, z)
    cam.rotation_euler = (0, 0, 0)
    bpy.context.scene.camera = cam
    return cam

def _emit(name, rgb, strength=1.0):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*rgb, 1.0)
    e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m

def _cycles(res_x, res_y, samples=8, transparent=False):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = samples
    try:
        s.cycles.use_denoising = samples >= 24
    except Exception:
        pass
    s.render.resolution_x = res_x
    s.render.resolution_y = res_y
    s.render.resolution_percentage = 100
    s.render.film_transparent = transparent
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA" if transparent else "RGB"

def _render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

def build_pcb_texture():
    T = 4.0          # döşeme boyu (dünya birimi)
    RES = 1024
    rnd = random.Random(42)
    items = []       # (x, y, sx, sy, kind)  kind: trace, pad, via, ic, silk
    def wrap_add(x, y, sx, sy, kind):
        for dx in (-T, 0, T):
            for dy in (-T, 0, T):
                xx, yy = x + dx, y + dy
                if xx + sx / 2 > -0.01 and xx - sx / 2 < T + 0.01 and yy + sy / 2 > -0.01 and yy - sy / 2 < T + 0.01:
                    items.append((xx, yy, sx, sy, kind))
    # yatay/dikey yol demetleri (döşeme sınırını aşanlar sarar)
    for i in range(10):
        y = rnd.uniform(0, T)
        x0 = rnd.uniform(0, T)
        ln = rnd.uniform(1.0, 3.2)
        n = rnd.choice((1, 1, 2, 4))
        for k in range(n):
            wrap_add(x0 + ln / 2, y + k * 0.07, ln, 0.035, "trace")
        wrap_add(x0, y, 0.09, 0.09, "via")
        wrap_add(x0 + ln, y + (n - 1) * 0.07, 0.09, 0.09, "via")
    for i in range(10):
        x = rnd.uniform(0, T)
        y0 = rnd.uniform(0, T)
        ln = rnd.uniform(1.0, 3.2)
        n = rnd.choice((1, 2, 3))
        for k in range(n):
            wrap_add(x + k * 0.07, y0 + ln / 2, 0.035, ln, "trace")
    # entegre ayak izleri (QFP) + silkscreen çerçeve
    for i in range(5):
        cx, cy = rnd.uniform(0, T), rnd.uniform(0, T)
        w = rnd.uniform(0.35, 0.6)
        wrap_add(cx, cy + w / 2 + 0.06, w + 0.12, 0.012, "silk")
        wrap_add(cx, cy - w / 2 - 0.06, w + 0.12, 0.012, "silk")
        wrap_add(cx - w / 2 - 0.06, cy, 0.012, w + 0.12, "silk"); wrap_add(cx + w / 2 + 0.06, cy, 0.012, w + 0.12, "silk")
        k = int(w / 0.06)
        for j in range(k):
            t = -w / 2 + (j + 0.5) * w / k
            for sgn in (-1, 1):
                wrap_add(cx + t, cy + sgn * (w / 2 + 0.02), 0.025, 0.06, "pad")
                wrap_add(cx + sgn * (w / 2 + 0.02), cy + t, 0.06, 0.025, "pad")
    # serbest SMD ped çiftleri ve vialar
    for i in range(40):
        x, y = rnd.uniform(0, T), rnd.uniform(0, T)
        if rnd.random() < 0.5:
            wrap_add(x, y, 0.05, 0.06, "pad"); wrap_add(x + 0.1, y, 0.05, 0.06, "pad")
        else:
            wrap_add(x, y, 0.07, 0.07, "via")
    H = {"trace": 0.35, "pad": 0.6, "via": 0.55, "silk": 0.25}
    COL = {"trace": (0.06, 0.33, 0.2), "pad": (0.86, 0.66, 0.28), "via": (0.86, 0.66, 0.28), "silk": (0.92, 0.94, 0.9)}
    MASK = {"trace": (1, 0, 0), "pad": (1, 1, 0), "via": (1, 1, 0), "silk": (0, 0, 1)}
    def lin(c):
        return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)
    COL = {k: lin(v) for k, v in COL.items()}
    def scene(pass_name):
        reset()
        _cycles(RES, RES, samples=4)
        bg = {"color": lin((0.03, 0.24, 0.16)), "height": (0.0, 0.0, 0.0), "mask": (0.0, 0.0, 0.0)}[pass_name]
        world = bpy.data.worlds.new("W")
        bpy.context.scene.world = world
        world.color = (0, 0, 0)
        bpy.ops.mesh.primitive_plane_add(size=T * 3, location=(T / 2, T / 2, 0))
        bpy.context.active_object.data.materials.append(_emit("bg", bg))
        mats = {}
        for kind in H:
            v = {"color": COL[kind], "height": (H[kind],) * 3, "mask": MASK[kind]}[pass_name]
            mats[kind] = _emit("m_" + kind, v)
        for (x, y, sx, sy, kind) in items:
            z = {"trace": 0.01, "silk": 0.02, "pad": 0.03, "via": 0.04}[kind]
            if kind == "via":
                bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=sx / 2, depth=0.01, location=(x, y, z))
            else:
                bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
                bpy.context.active_object.scale = (sx, sy, 0.01)
            bpy.context.active_object.data.materials.append(mats[kind])
            if kind == "via":
                bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=sx / 5, depth=0.01, location=(x, y, z + 0.01))
                bpy.context.active_object.data.materials.append(_emit("hole", (0.02, 0.02, 0.02) if pass_name == "color" else (0.0, 0.0, 0.0)))
        _ortho_cam(T / 2, T / 2, T)
        p = os.path.join(SCRATCH, "pcb_%s.png" % pass_name)
        _render(p)
        return p
    paths = {k: scene(k) for k in ("color", "height", "mask")}
    out = os.path.join(ROOT, "assets", "textures", "pbr", "pcb_detail")
    os.makedirs(out, exist_ok=True)
    import numpy as np
    def load(p):
        img = bpy.data.images.load(p)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        return a[::-1, :, :3]
    def save(p, arr):
        h, w = arr.shape[:2]
        img = bpy.data.images.new(os.path.basename(p), w, h, alpha=False)
        rgba = np.ones((h, w, 4), dtype=np.float32)
        rgba[:, :, :3] = arr
        img.pixels = rgba[::-1].ravel()
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
    col = load(paths["color"])
    hgt = load(paths["height"])[:, :, 0]
    msk = load(paths["mask"])
    # yükseklik → normal (döşenebilir: kenarda sarmalı türev)
    k = 6.0
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * k
    dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * k
    n = np.dstack([-dx, dy, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    save(os.path.join(out, "albedo.png"), col)
    save(os.path.join(out, "normal.png"), n * 0.5 + 0.5)
    save(os.path.join(out, "mask.png"), msk)
    return {"file": "textures/pbr/pcb_detail", "tris": 0, "budget": 0, "ok": True, "items": len(items)}

# ---------------------------------------------------------------------------
# 3) Montaj atölyesi: masa üstü y=0; PC'nin kapladığı alan (x[-3.2,6], z[-1.95,1.8], y≤5.1) boş bırakılır.
def build_workshop():
    reset(); m = M()
    wood = mat("DeskWood", "#2a2420", 0.0, 0.45)
    esd = mat("ESDMat", "#121c22", 0.0, 0.75)
    wall = mat("WallPaint", "#2b2f3d", 0.0, 0.95)
    peg = mat("Pegboard", "#7d6648", 0.0, 0.75)
    soft = mat("SoftboxLight", "#fff2e0", 0.0, 0.5, emission="#fff2e0", strength=3.0)
    lamp = mat("LampLED", "#ffd9a8", 0.0, 0.4, emission="#ffd9a8", strength=4.0)
    disp = mat("StationDisplay", "#ff5a2a", 0.0, 0.3, emission="#ff5a2a", strength=3.0)
    # masa ve ESD altlık
    box((1.4, -0.1, 0), (16, 0.2, 10), wood, bevel=0.03)
    box((1.4, 0.004, -0.1), (11.5, 0.008, 5.0), esd, bevel=0)
    # arka duvar + delikli pano + raflar
    box((1.4, 6, -6.05), (40, 18, 0.1), wall, bevel=0)
    box((1.4, 4.2, -5.95), (12, 4.6, 0.06), peg, bevel=0.01)
    for i in range(30):
        for j in range(11):
            box((-4.3 + i * 0.4, 2.2 + j * 0.4, -5.92), (0.06, 0.06, 0.02), wall, bevel=0)
    for sy in (2.6, 4.5):
        box((-6.2, sy, -5.5), (3.2, 0.08, 0.9), wood, bevel=0.015)
        box((9.0, sy, -5.5), (3.2, 0.08, 0.9), wood, bevel=0.015)
    # raflarda parça çekmeceleri
    for k in range(6):
        for side in (-6.2, 9.0):
            box((side - 1.25 + k * 0.5, 2.88, -5.5), (0.42, 0.48, 0.7), m["white"] if k % 2 else m["red"], bevel=0.02)
            box((side - 1.25 + k * 0.5, 2.8, -5.14), (0.2, 0.05, 0.02), m["dark"], bevel=0)
    # asılı aletler (tornavida, pense siluetleri)
    for k in range(7):
        x = -3.5 + k * 0.9
        box((x, 4.6, -5.88), (0.06, 1.0, 0.06), m["alu"], bevel=0.01)
        box((x, 5.05, -5.86), (0.16, 0.45, 0.1), m["red"] if k % 2 else m["amber"], bevel=0.03)
    # havya istasyonu (sol ön)
    bx, bz = -5.0, 2.9
    box((bx, 0.35, bz), (1.3, 0.7, 0.9), m["dark"], bevel=0.05)
    box((bx - 0.2, 0.45, bz + 0.46), (0.6, 0.3, 0.02), disp, bevel=0)
    cyl((bx + 0.4, 0.4, bz + 0.47), 0.1, 0.08, m["alu"], "z", 24)
    cyl((bx + 1.2, 0.08, bz), 0.28, 0.16, m["dark"], "y", 32)
    for k in range(8):
        torus((bx + 1.2, 0.3 + k * 0.08, bz), 0.12, 0.02, m["alu"], "y", 24, 6)
    cyl((bx + 1.2, 0.75, bz), 0.025, 0.55, m["dark"], "y", 12)
    box((bx + 1.45, 0.06, bz + 0.35), (0.3, 0.12, 0.3), mat("BrassWool", "#c8a248", 0.8, 0.6), bevel=0.03)
    # alet çantası (sağ ön)
    tx, tz = 8.3, 3.0
    box((tx, 0.35, tz), (1.8, 0.7, 1.0), m["red"], bevel=0.06)
    box((tx, 0.72, tz), (1.82, 0.06, 1.02), m["dark"], bevel=0.02)
    box((tx, 0.85, tz), (0.9, 0.08, 0.1), m["dark"], bevel=0.03)
    for sx in (-1, 1):
        box((tx + sx * 0.55, 0.78, tz), (0.08, 0.14, 0.1), m["dark"], bevel=0.02)
        box((tx + sx * 0.8, 0.5, tz + 0.51), (0.12, 0.14, 0.03), m["alu"], bevel=0.01)
    # büyüteçli lamba (sağ arka)
    lx, lz = 7.6, -3.0
    cyl((lx, 0.05, lz), 0.4, 0.1, m["dark"], "y", 32)
    box((lx, 1.2, lz), (0.06, 2.3, 0.06), m["alu"], bevel=0.01)
    box((lx - 0.6, 2.35, lz + 0.2), (1.3, 0.06, 0.06), m["alu"], rot=(0.3, 0, 0), bevel=0.01)
    torus((lx - 1.2, 2.25, lz + 0.4), 0.32, 0.05, m["dark"], "y", 40, 8)
    cyl((lx - 1.2, 2.25, lz + 0.4), 0.3, 0.02, m["glass"], "y", 40)
    torus((lx - 1.2, 2.21, lz + 0.4), 0.27, 0.015, lamp, "y", 40, 6)
    # softbox ışıklar (sol ve sağ arka köşe, sehpalı)
    for sx, sz2 in ((-6.0, -3.6), (9.6, -4.4)):
        for k in range(3):
            a = k * 2 * math.pi / 3
            box((sx + math.cos(a) * 0.4, 0.6, sz2 + math.sin(a) * 0.4), (0.04, 1.3, 0.04), m["dark"], rot=(math.sin(a) * 0.3, math.cos(a) * 0.3, 0), bevel=0)
        box((sx, 2.4, sz2), (0.05, 3.6, 0.05), m["dark"], bevel=0)
        box((sx, 4.4, sz2), (1.6, 1.6, 0.45), m["dark"], rot=(0.25, 0, 0), bevel=0.05)
        box((sx, 4.4, sz2 + 0.24), (1.45, 1.45, 0.02), soft, rot=(0.25, 0, 0), bevel=0)
    # masa üstü ayrıntılar: kablo makarası, vida kutusu, multimetre
    cyl((-5.2, 0.15, -2.6), 0.4, 0.3, m["dark"], "z", 32)
    cyl((-5.2, 0.15, -2.6), 0.34, 0.26, m["copper"], "z", 32)
    box((-4.8, 0.06, 1.0), (0.8, 0.12, 0.5), m["glass"], bevel=0.02)
    for i in range(4):
        box((-5.1 + i * 0.2, 0.03, 1.0), (0.17, 0.06, 0.46), m["dark"], bevel=0.005)
    box((7.4, 0.12, 0.8), (0.55, 0.24, 0.95), mat("MeterYellow", "#f2c12e", 0.0, 0.5), bevel=0.05)
    box((7.4, 0.245, 0.62), (0.4, 0.01, 0.3), mat("MeterLCD", "#a7c79a", 0.0, 0.3, emission="#7fa070", strength=0.6), bevel=0)
    cyl((7.4, 0.25, 0.95), 0.1, 0.03, m["dark"], "y", 24)
    for sx in (-0.12, 0.12):
        cyl((7.4 + sx, 0.25, 1.15), 0.025, 0.03, m["red"] if sx > 0 else m["dark"], "y", 12)
    return finalize(os.path.join(MODELS, "scenes", "workshop.glb"), BUDGET_SCENE, recenter=False)

# ---------------------------------------------------------------------------
# 4) Başlık dioraması: yüzen devre adası üstünde kayıp kule. Orijin adanın üst yüzü (y=0), ~8×8 birim.
def build_title():
    reset(); m = M()
    rock = mat("IslandRock", "#3b3550", 0.0, 0.85)
    rock2 = mat("IslandRockDark", "#272236", 0.0, 0.9)
    core = mat("CrystalCore", "#7df9ff", 0.1, 0.1, emission="#7df9ff", strength=5.0)
    led = mat("TowerLED", "#ffb84d", 0.0, 0.3, emission="#ffb84d", strength=3.0)
    cyan = mat("TraceGlow", "#62f2c8", 0.0, 0.3, emission="#62f2c8", strength=2.5)
    rnd = random.Random(5)
    # ada: üstte PCB disk, altında ters koni kaya parçaları
    cyl((0, -0.15, 0), 4.0, 0.3, m["pcb"], "y", 64)
    torus((0, -0.02, 0), 3.95, 0.04, m["gold"], "y", 96, 6)
    for k in range(16):
        a = k * 2 * math.pi / 16 + rnd.random() * 0.2
        r = 2.6 + rnd.random() * 1.1
        cone((math.cos(a) * r * 0.55, -1.1 - rnd.random() * 0.4, math.sin(a) * r * 0.55), 0.9 + rnd.random() * 0.5, 0.05, 1.8 + rnd.random() * 1.2, rock if k % 2 else rock2, "y", 7)
    bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=3.6, radius2=0.2, depth=3.6, location=G(0, -2.1, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, rock2, 0)
    # ışıyan bakır yollar (adanın yüzeyinde)
    for k in range(10):
        a = k * 2 * math.pi / 10
        L = 1.6 + rnd.random() * 1.6
        box((math.cos(a) * (1.4 + L / 2), 0.006, math.sin(a) * (1.4 + L / 2)), (L, 0.012, 0.06), cyan, rot=(0, 0, -a), bevel=0)
        cyl((math.cos(a) * (1.4 + L), 0.01, math.sin(a) * (1.4 + L)), 0.08, 0.02, m["gold"], "y", 16)
    # kule: devre elemanlarından basamaklı kule (SMD blokları, kondansatör, direnç, röle)
    tower = [((0, 0, 0), 2.2, 1.0), ((0.2, 1, 0.1), 1.7, 1.0), ((-0.1, 2, -0.1), 1.3, 1.0), ((0.1, 3, 0.0), 1.0, 0.9)]
    for (x, y, z), w, h in tower:
        box((x, y + h / 2, z), (w, h, w), m["epoxy"], bevel=0.05)
        for sgn in (-1, 1):
            for i in range(int(w / 0.25)):
                t = -w / 2 + 0.15 + i * 0.25
                box((x + t, y + 0.25, z + sgn * (w / 2 + 0.03)), (0.08, 0.3, 0.06), m["tin"], bevel=0.01)
        box((x, y + h - 0.01, z), (w * 0.8, 0.02, w * 0.8), m["dark"], bevel=0)
        cyl((x - w * 0.3, y + h, z - w * 0.3), 0.06, 0.02, m["silk"], "y", 12)
        box((x, y + h * 0.5, z + w / 2 + 0.005), (w * 0.4, 0.06, 0.01), led, bevel=0)
    # kulenin tepesinde hedef çip + kristal
    box((0.1, 3.95, 0), (0.6, 0.1, 0.6), m["gold"], bevel=0.02)
    cone((0.1, 4.35, 0), 0.25, 0.0, 0.6, core, "y", 6)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.25, radius2=0.0, depth=0.3, location=G(0.1, 3.95 + 0.0, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, core, 0)
    torus((0.1, 4.25, 0), 0.4, 0.02, m["gold"], "x", 48, 6)
    # merdiven (PCB basamakları) ve kondansatör kuleleri
    for k in range(3):
        h = (k + 1) * 0.33
        box((1.55 + k * 0.33, h / 2, 0.0), (0.33, h, 0.8), m["pcb2"], bevel=0.015)
    for (x, z, h) in ((-2.3, 1.2, 1.3), (-2.0, -1.6, 0.9), (2.4, -1.5, 1.6), (-1.0, 2.5, 0.7)):
        cyl((x, h / 2, z), 0.35, h, mat("Sleeve", "#1c2a5a", 0.1, 0.45), "y", 32)
        cyl((x, h + 0.03, z), 0.34, 0.06, m["alu"], "y", 32)
        torus((x, h + 0.065, z), 0.26, 0.012, cyan, "y", 32, 6)
    # devre ağaçları: ince bakır gövde, katmanlı yeşil PCB yapraklar
    for (x, z, s) in ((2.6, 1.6, 1.0), (-3.0, -0.3, 0.8), (1.0, -2.9, 0.9), (-1.8, 2.9, 0.7), (3.1, -0.3, 0.6)):
        cyl((x, 0.5 * s, z), 0.05 * s, 1.0 * s, m["copper"], "y", 10)
        for k in range(3):
            r = (0.55 - k * 0.15) * s
            cyl((x, (0.9 + k * 0.28) * s, z), r, 0.06, m["pcb2"], "y", 8)
            torus((x, (0.9 + k * 0.28) * s, z), r, 0.012, cyan, "y", 16, 4)
    # yüzen küçük adacık parçaları
    for (x, y, z, r) in ((-4.6, 0.8, -1.5, 0.5), (4.4, 1.4, 1.2, 0.35), (3.8, -0.4, -3.4, 0.45)):
        cyl((x, y, z), r, 0.12, m["pcb"], "y", 16)
        cone((x, y - 0.4, z), r * 0.9, 0.02, 0.7, rock, "y", 6)
    # robotun duracağı nokta
    e = bpy.data.objects.new("RobotSpot", None)
    bpy.context.scene.collection.objects.link(e)
    e.location = G(1.55 + 0.66 + 0.5, 0.0, 0.05)
    return finalize(os.path.join(MODELS, "scenes", "title_diorama.glb"), BUDGET_SCENE, recenter=False)

# ---------------------------------------------------------------------------
# 5) Faz adası ikonları: her donanım fazı için küçük bir ada, şeffaf arka planla 256×256 render.
def _studio(target=(0, 0, 0.6), dist=6.0, elev=0.62, az=0.78, ortho=None, lens=50):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    tx, ty, tz = target
    cam.location = (tx + dist * math.cos(elev) * math.sin(az), ty - dist * math.cos(elev) * math.cos(az), tz + dist * math.sin(elev))
    d = (tx - cam.location[0], ty - cam.location[1], tz - cam.location[2])
    import mathutils
    cam.rotation_euler = mathutils.Vector(d).to_track_quat("-Z", "Y").to_euler()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.lens = lens
    bpy.context.scene.camera = cam
    def light(kind, loc, energy, color, size=None):
        l = bpy.data.objects.new(kind, bpy.data.lights.new(kind, kind))
        bpy.context.scene.collection.objects.link(l)
        l.location = loc
        l.data.energy = energy
        l.data.color = color
        if size and kind == "AREA":
            l.data.size = size
        v = mathutils.Vector((tx, ty, tz)) - mathutils.Vector(loc)
        l.rotation_euler = v.to_track_quat("-Z", "Y").to_euler()
    light("AREA", (tx + 4, ty - 5, tz + 6), 900, (1.0, 0.93, 0.85), 4)
    light("AREA", (tx - 6, ty + 3, tz + 3), 300, (0.55, 0.7, 1.0), 4)
    light("SUN", (tx, ty, tz + 10), 1.5, (1, 1, 1))
    w = bpy.data.worlds.new("W")
    bpy.context.scene.world = w
    w.color = (0.05, 0.05, 0.08)
    return cam

def _island_base(m, r=1.6):
    rock = mat("IslandRock", "#3b3550", 0.0, 0.85)
    cyl((0, -0.1, 0), r, 0.2, m["pcb"], "y", 48)
    torus((0, -0.0, 0), r - 0.02, 0.03, m["gold"], "y", 64, 6)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r * 0.95, radius2=0.1, depth=1.6, location=G(0, -1.0, 0), rotation=(math.pi, 0, 0))
    A._finish_obj(bpy.context.active_object, rock, 0)

def _phase_scene(i, m):
    cyan = mat("TraceGlow", "#62f2c8", 0.0, 0.3, emission="#62f2c8", strength=2.5)
    glow = mat("PhaseGlow", "#ffb84d", 0.0, 0.3, emission="#ffb84d", strength=3.0)
    if i == 0:      # anakart: bakır yollar + soket
        for k in range(6):
            box((-0.9 + k * 0.36, 0.01, 0), (0.06, 0.02, 2.2), m["copper"], bevel=0)
        box((0, 0.15, 0), (0.9, 0.3, 0.9), m["dark"], bevel=0.04)
        box((0, 0.31, 0), (0.6, 0.02, 0.6), cyan, bevel=0)
    elif i == 1:    # PSU: kutu + fan + kablo
        box((0, 0.45, 0), (1.6, 0.9, 1.1), m["dark"], bevel=0.05)
        torus((0, 0.91, 0), 0.4, 0.04, m["alu"], "y", 40, 8)
        for k in range(5):
            box((0, 0.92, 0), (0.7, 0.02, 0.08), m["alu"], rot=(0, 0, k * math.pi / 5), bevel=0)
        box((0.82, 0.3, 0.3), (0.05, 0.12, 0.12), glow, bevel=0)
    elif i == 2:    # CPU
        box((0, 0.08, 0), (1.3, 0.16, 1.3), mat("PCBLight", "#14583e", 0.0, 0.5), bevel=0.03)
        box((0, 0.25, 0), (0.95, 0.18, 0.95), m["alu"], bevel=0.05)
        cone((0, 0.6, 0), 0.25, 0.0, 0.5, mat("CrystalCore", "#7df9ff", 0.1, 0.1, emission="#7df9ff", strength=5.0), "y", 6)
    elif i == 3:    # RAM: dikey modüller
        for k in range(4):
            box((-0.6 + k * 0.4, 0.55, 0), (0.12, 1.1, 1.4), mat("PCBLight", "#14583e", 0.0, 0.5), bevel=0.02)
            box((-0.6 + k * 0.4, 1.12, 0), (0.14, 0.06, 1.3), glow if k % 2 else cyan, bevel=0.01)
            for j in range(4):
                box((-0.6 + k * 0.4 + 0.07, 0.6, -0.5 + j * 0.33), (0.02, 0.35, 0.25), m["epoxy"], bevel=0.005)
    elif i == 4:    # NVMe
        box((0, 0.1, 0), (2.2, 0.08, 0.6), mat("PCBLight", "#14583e", 0.0, 0.5), bevel=0.02)
        for k in range(3):
            box((-0.6 + k * 0.6, 0.18, 0), (0.45, 0.08, 0.45), m["epoxy"], bevel=0.01)
        box((1.0, 0.16, 0), (0.15, 0.02, 0.5), m["gold"], bevel=0)
    elif i == 5:    # GPU
        box((0, 0.35, 0), (2.4, 0.6, 1.1), m["dark"], bevel=0.06)
        for x in (-0.6, 0.6):
            torus((x, 0.66, 0), 0.36, 0.04, m["alu"], "y", 40, 8)
            cyl((x, 0.66, 0), 0.1, 0.04, glow, "y", 24)
        box((0, 0.36, 0.56), (2.2, 0.06, 0.02), cyan, bevel=0)
    elif i == 6:    # soğutma: kule soğutucu
        for k in range(10):
            box((0, 0.3 + k * 0.12, 0), (1.2, 0.03, 1.0), m["alu"], bevel=0)
        for x in (-0.3, 0, 0.3):
            cyl((x, 0.8, 0), 0.05, 1.3, m["copper"], "y", 12)
        box((0, 0.85, 0.55), (1.2, 1.2, 0.12), m["dark"], bevel=0.04)
        torus((0, 0.85, 0.62), 0.45, 0.03, cyan, "z", 40, 6)
    elif i == 7:    # I/O
        box((0, 0.4, 0), (1.8, 0.8, 0.3), m["alu"], bevel=0.03)
        for k in range(4):
            box((-0.6 + k * 0.4, 0.55, 0.16), (0.25, 0.12, 0.04), m["dark"], bevel=0.01)
            cyl((-0.6 + k * 0.4, 0.25, 0.16), 0.06, 0.04, [glow, cyan, m["red"], m["gold"]][k], "z", 16)
    elif i == 8:    # kasa
        box((0, 0.8, 0), (1.1, 1.6, 1.5), m["dark"], bevel=0.05)
        box((0.56, 0.8, 0), (0.02, 1.4, 1.3), m["glass"], bevel=0)
        for k in range(3):
            torus((0.4, 0.4 + k * 0.45, 0.55), 0.17, 0.025, glow if k % 2 else cyan, "x", 32, 6)
    else:           # monitör + klavye + çekirdek
        box((0, 0.95, -0.2), (1.9, 1.15, 0.1), m["dark"], bevel=0.04)
        box((0, 0.95, -0.14), (1.75, 1.0, 0.02), mat("MonitorScreen", "#0e2a4a", 0.0, 0.2, emission="#2b7fd0", strength=2.0), bevel=0)
        box((0, 0.2, -0.25), (0.1, 0.4, 0.1), m["alu"], bevel=0.02)
        box((0, 0.05, 0.55), (1.4, 0.08, 0.45), m["dark"], bevel=0.02)
        for k in range(10):
            for j in range(3):
                box((-0.6 + k * 0.135, 0.11, 0.42 + j * 0.13), (0.1, 0.04, 0.1), m["white"], bevel=0.01)

def build_phases():
    out = []
    for i in range(10):
        reset(); m = M()
        _island_base(m)
        _phase_scene(i, m)
        _cycles(256, 256, samples=32, transparent=True)
        _studio(target=(0, 0, 0.25), dist=7.0, elev=0.55, az=0.7, ortho=4.4)
        _render(os.path.join(ROOT, "assets", "ui", "phase_%02d.png" % (i + 1)))
        out.append({"file": "ui/phase_%02d.png" % (i + 1), "tris": 0, "budget": 0, "ok": True})
    return out

# ---------------------------------------------------------------------------
# 6) Tema dekor setleri: tabanı y=0, kulenin yanındaki ~1.3 × 2.4 alana sığar (en fazla 2.6 yükseklik).
THEMES = {
    1: ("#3b2f2a", "#d4af37", "#c9b8a0"), 2: ("#b08d57", "#e2c48a", "#5a3e22"), 3: ("#1b1035", "#ff4fd8", "#3cf0ff"),
    4: ("#a38cff", "#7df9ff", "#e8e4ff"), 5: ("#f08a74", "#a8c3a0", "#fff4e6"), 6: ("#4a4d55", "#d8383a", "#e9e2d0"),
    7: ("#8f9399", "#e6e9ee", "#3a3d44"), 8: ("#b8733a", "#9fd8c8", "#5dbb63"), 9: ("#0e2233", "#3cf0ff", "#ff9a3c"),
    10: ("#e2c48a", "#a67c3d", "#fff2d6"), 11: ("#2c3350", "#c8a248", "#d8e2ff"), 12: ("#c9ced6", "#f2c12e", "#30333b"),
    13: ("#1d4e89", "#eef4ff", "#7fb4ff"), 14: ("#d9d2c3", "#c0392b", "#4e6b3a"), 15: ("#f4f6fb", "#2f6fe0", "#d4af37"),
}

def _theme_set(i):
    c0, c1, c2 = THEMES[i]
    a = mat("T%dBase" % i, c0, 0.2, 0.55)
    b = mat("T%dAccent" % i, c1, 0.6, 0.3, emission=c1 if i in (3, 4, 9, 13) else None, strength=2.0)
    c = mat("T%dDetail" % i, c2, 0.1, 0.5)
    cyl((0, 0.04, 0), 0.62, 0.08, a, "y", 40)              # ortak kaide
    if i == 1:   # Kintsugi: altın çatlaklı kase + çay fincanı
        cyl((0, 0.35, 0), 0.5, 0.5, a, "y", 40)
        torus((0, 0.6, 0), 0.5, 0.04, b, "y", 48, 8)
        for k in range(5):
            box((math.cos(k) * 0.4, 0.35, math.sin(k) * 0.4), (0.02, 0.45, 0.02), b, rot=(0.2 * k, 0, k), bevel=0)
        cyl((0, 0.1, 0.9), 0.2, 0.18, c, "y", 24)
    elif i == 2:  # Saatçi: iç içe dişliler
        for k, (x, y, r) in enumerate(((0, 0.9, 0.55), (0.2, 1.7, 0.35), (-0.25, 0.5, 0.3))):
            torus((x, y, 0), r, 0.06, b, "z", 40, 8)
            for t in range(14):
                aa = t * 2 * math.pi / 14
                box((x + math.cos(aa) * (r + 0.07), y + math.sin(aa) * (r + 0.07), 0), (0.07, 0.07, 0.09), b, bevel=0.01)
            cyl((x, y, 0), 0.07, 0.14, c, "z", 16)
        box((0, 0.6, -0.1), (0.08, 1.2, 0.08), c, bevel=0.01)
    elif i == 3:  # Retro synth: neon ızgara kulesi + kaset
        for k in range(5):
            box((0, 0.3 + k * 0.35, 0), (0.9 - k * 0.12, 0.04, 0.9 - k * 0.12), b, bevel=0)
        box((0, 0.9, 0), (0.06, 1.6, 0.06), c, bevel=0)
        box((0.0, 0.15, 0.9), (0.7, 0.1, 0.45), a, bevel=0.02)
        for x in (-0.15, 0.15):
            cyl((x, 0.21, 0.9), 0.07, 0.02, c, "y", 16)
    elif i == 4:  # Optik prizma: kristal kümeleri
        for k in range(7):
            aa = k * 0.9
            h = 0.6 + (k % 3) * 0.45
            cone((math.cos(aa) * 0.3, h / 2, math.sin(aa) * 0.3 + (0.5 if k > 4 else 0)), 0.14 + 0.03 * (k % 2), 0.0, h, b if k % 2 else c, "y", 6)
    elif i == 5:  # Origami: katlanmış kağıt turna ve piramitler
        cone((0, 0.5, 0), 0.5, 0.0, 0.9, c, "y", 4)
        cone((0.1, 0.25, 0.85), 0.35, 0.0, 0.5, a, "y", 3)
        box((0, 1.05, 0), (0.8, 0.02, 0.2), b, rot=(0, 0.4, 0.3), bevel=0)
        box((0, 1.1, 0), (0.15, 0.25, 0.04), b, rot=(0, 0, 0.6), bevel=0)
    elif i == 6:  # Antik baskı: dizgi blokları
        for k in range(6):
            box((-0.3 + (k % 3) * 0.3, 0.2 + (k // 3) * 0.32, 0), (0.26, 0.3, 0.26), a, bevel=0.02)
            box((-0.3 + (k % 3) * 0.3, 0.37 + (k // 3) * 0.32, 0), (0.18, 0.04, 0.18), b if k % 2 else c, bevel=0.005)
        cyl((0, 0.2, 0.9), 0.25, 0.4, c, "x", 24)
    elif i == 7:  # Brütalist ayna: beton dikilitaşlar + ayna panel
        for k, (x, h) in enumerate(((-0.3, 1.8), (0.15, 1.2), (0.4, 2.3))):
            box((x, h / 2, 0), (0.3, h, 0.3), a if k != 1 else c, bevel=0.02)
        box((0, 0.7, 0.7), (0.9, 1.3, 0.04), mat("Mirror", "#e6e9ee", 1.0, 0.03), bevel=0.01)
    elif i == 8:  # Simya teraryumu: cam fanus içinde bitki
        cyl((0, 0.7, 0), 0.5, 1.2, mat("TerraGlass", "#d8f6ff", 0.0, 0.03, transmission=0.9, alpha=0.2), "y", 40)
        sphere((0, 1.3, 0), 0.5, mat("TerraGlass", "#d8f6ff", 0.0, 0.03, transmission=0.9, alpha=0.2), 24)
        cyl((0, 0.2, 0), 0.45, 0.2, mat("Soil", "#4a3424", 0.0, 0.95), "y", 32)
        for k in range(5):
            cone((math.cos(k * 1.3) * 0.15, 0.55, math.sin(k * 1.3) * 0.15), 0.08, 0.0, 0.6, c, "y", 6)
        torus((0, 0.12, 0), 0.52, 0.04, a, "y", 40, 8)
    elif i == 9:  # Siber dokuma: fiber çile ve tezgah
        for k in range(9):
            box((0, 0.2 + k * 0.17, 0), (1.0, 0.025, 0.025), b, rot=(0, 0.1 * (k % 3), 0), bevel=0)
        for x in (-0.5, 0.5):
            box((x, 0.85, 0), (0.08, 1.7, 0.08), a, bevel=0.01)
        cyl((0, 0.25, 0.9), 0.25, 0.4, c, "x", 24)
    elif i == 10:  # Kum ve güneş saati
        cyl((0, 0.5, 0), 0.4, 0.9, a, "y", 32)
        box((0, 1.15, 0), (0.05, 0.4, 0.5), b, rot=(0.6, 0, 0), bevel=0.01)
        for y in (0.1, 1.0):
            cyl((0, y, 0.9), 0.3, 0.06, b, "y", 24)
        cone((0, 0.32, 0.9), 0.25, 0.02, 0.4, mat("HourGlass", "#fff6d8", 0.0, 0.05, transmission=0.9, alpha=0.3), "y", 24)
        cone((0, 0.78, 0.9), 0.02, 0.25, 0.4, mat("HourGlass", "#fff6d8", 0.0, 0.05, transmission=0.9, alpha=0.3), "y", 24)
    elif i == 11:  # Gözlemevi: teleskop
        for k in range(3):
            aa = k * 2 * math.pi / 3
            box((math.cos(aa) * 0.25, 0.4, math.sin(aa) * 0.25), (0.04, 0.85, 0.04), c, rot=(math.sin(aa) * 0.3, math.cos(aa) * 0.3, 0), bevel=0)
        cyl((0, 1.1, 0), 0.14, 1.3, b, "z", 24)
        cyl((0, 1.1, 0.68), 0.17, 0.08, a, "z", 24)
        sphere((0.0, 2.0, -0.4), 0.12, c, 16)
    elif i == 12:  # Kinetik heykel: dengeli kollar
        box((0, 1.0, 0), (0.05, 2.0, 0.05), a, bevel=0)
        for k, (y, L) in enumerate(((2.0, 1.2), (1.5, 0.9), (1.05, 0.7))):
            box((0, y, 0), (L, 0.03, 0.03), a, rot=(0, 0, 0.1 * (k - 1)), bevel=0)
            sphere((L / 2, y - 0.12, 0), 0.1, b, 16)
            box((-L / 2, y - 0.12, 0), (0.18, 0.18, 0.02), b, bevel=0.01)
    elif i == 13:  # Röntgen / plan: ışıklı ölçek ızgarası + T cetveli
        for k in range(5):
            box((-0.4 + k * 0.2, 0.6, 0), (0.015, 1.2, 0.015), b, bevel=0)
            box((0, 0.1 + k * 0.25, 0), (0.85, 0.015, 0.015), b, bevel=0)
        box((0, 0.1, 0.8), (1.0, 0.03, 0.1), c, bevel=0.005)
        box((-0.48, 0.1, 0.6), (0.06, 0.03, 0.5), c, bevel=0.005)
    elif i == 14:  # Zen bahçesi: tırmıklı çakıl, taşlar, akçaağaç
        cyl((0, 0.1, 0), 0.6, 0.04, c, "y", 40)
        for k in range(4):
            torus((0, 0.12, 0), 0.15 + k * 0.12, 0.01, a, "y", 40, 4)
        sphere((0.2, 0.2, -0.1), 0.17, mat("Stone", "#6b6a66", 0.0, 0.8), 12)
        cyl((-0.25, 0.6, 0.3), 0.04, 1.1, mat("Bark", "#4a3424", 0.0, 0.9), "y", 8)
        for k in range(5):
            sphere((-0.25 + math.cos(k) * 0.2, 1.2 + (k % 2) * 0.12, 0.3 + math.sin(k) * 0.2), 0.22, b, 12)
    else:          # Kozmik porselen: mavi desenli vazo + gezegen halkası
        cyl((0, 0.4, 0), 0.32, 0.6, a, "y", 40)
        sphere((0, 0.85, 0), 0.34, a, 32)
        cyl((0, 1.25, 0), 0.12, 0.3, a, "y", 32)
        for k in range(3):
            torus((0, 0.3 + k * 0.25, 0), 0.33 + (0.02 if k == 1 else 0), 0.015, b, "y", 40, 4)
        torus((0, 1.7, 0), 0.4, 0.015, c, "x", 48, 6)
        sphere((0, 1.7, 0), 0.12, b, 16)
    return finalize(os.path.join(MODELS, "themes", "theme_%02d.glb" % i), BUDGET_THEME)

def build_themes():
    return [(_reset_and(lambda i=i: _theme_set(i))) for i in range(1, 16)]

def _reset_and(fn):
    reset()
    return fn()

# ---------------------------------------------------------------------------
# 7) Faz uzak manzaraları: uçan PCB adasının altında/çevresinde uzanan dev donanım dünyası (ortografik kamera için
#    aşağıda; Godot renkleri gökyüzü rengine doğru karıştırır = atmosferik derinlik). Orijin manzaranın tepe merkezi.
def _bd_mats():
    return {"base": mat("BdBase", "#1b2436", 0.4, 0.6), "metal": mat("BdMetal", "#3a4256", 0.8, 0.35),
            "pcb": mat("BdPCB", "#0e3a2c", 0.1, 0.6), "glow": mat("BdGlow", "#00E5FF", 0.0, 0.3, emission="#00E5FF", strength=4.0),
            "amber": mat("BdAmber", "#F59E0B", 0.0, 0.3, emission="#F59E0B", strength=3.5), "gold": mat("BdGold", "#b8902e", 1.0, 0.3),
            "glass": mat("BdGlass", "#9fd8ff", 0.0, 0.05, transmission=0.6, alpha=0.35)}

def _ring(n, r0, r1, rnd):
    for k in range(n):
        a = k * 2 * math.pi / n + rnd.uniform(-0.12, 0.12)
        r = rnd.uniform(r0, r1)
        yield k, math.cos(a) * r, math.sin(a) * r, a

def _backdrop(ph):
    reset(); m = _bd_mats()
    rnd = random.Random(100 + ph)
    # taban: manzaranın altında koyu PCB zemini (yapılar üstünde yükselir)
    cyl((0, -14.3, 0), 40, 0.4, m["pcb"], "y", 64)
    if ph == 1:      # anakart şehri: çip gökdelenler + bakır yollar
        for k, x, z, a in _ring(26, 12, 36, rnd):
            h = rnd.uniform(4, 18)
            w = rnd.uniform(1.5, 4)
            box((x, -14 + h / 2, z), (w, h, w), m["base"], bevel=0.12)
            box((x, -14 + h * 0.7, z + w / 2 + 0.02), (w * 0.7, 0.15, 0.05), m["glow"] if k % 3 else m["amber"], bevel=0)
            for j in range(int(h / 2)):
                box((x + w / 2 + 0.05, -14 + 1 + j * 2, z), (0.12, 0.3, w * 0.8), m["metal"], bevel=0)
    elif ph == 2:    # PSU: dev bobinler ve transformatörler
        for k, x, z, a in _ring(14, 14, 34, rnd):
            r = rnd.uniform(1.2, 3)
            for j in range(rnd.randint(4, 9)):
                torus((x, -12 + j * 0.9, z), r, 0.4, m["gold"] if j % 2 else m["metal"], "y", 24, 8)
            cyl((x, -12 + 4, z), r * 0.5, 9, m["base"], "y", 16)
    elif ph == 3:    # CPU: pin ormanı + soket kraterleri
        for k in range(160):
            x, z = rnd.uniform(-34, 34), rnd.uniform(-34, 34)
            if abs(x) < 10 and abs(z) < 10:
                continue
            h = rnd.uniform(2, 10)
            cyl((x, -14 + h / 2, z), 0.22, h, m["gold"], "y", 6, 0)
        for k, x, z, a in _ring(6, 18, 30, rnd):
            box((x, -13.5, z), (8, 0.6, 8), m["base"], bevel=0.2)
            box((x, -13.0, z), (5, 0.3, 5), m["glow"], bevel=0)
    elif ph == 4:    # RAM: dev bellek modülü sıraları
        for k in range(10):
            z = -30 + k * 6.5
            if abs(z) < 8:
                continue
            for x in (-24, -12, 12, 24):
                box((x + rnd.uniform(-2, 2), -10, z), (9, 8, 0.6), m["pcb"], bevel=0.1)
                box((x, -6.2, z), (9, 0.4, 0.7), m["glow"] if k % 2 else m["amber"], bevel=0)
    elif ph == 5:    # NVMe: uzun veri yolları
        for k in range(12):
            a = k * math.pi / 6
            for j in range(4):
                r = 14 + j * 6
                box((math.cos(a) * r, -12, math.sin(a) * r), (5, 0.4, 1.6), m["base"], rot=(0, 0, a), bevel=0.1)
                box((math.cos(a) * r, -11.7, math.sin(a) * r), (1.2, 0.3, 1.2), m["glow"], rot=(0, 0, a), bevel=0)
    elif ph == 6:    # GPU: dev fan halkaları
        for k, x, z, a in _ring(8, 16, 30, rnd):
            R = rnd.uniform(3, 6)
            torus((x, -9, z), R, 0.35, m["metal"], "z" if k % 2 else "x", 40, 8)
            for b in range(7):
                ang = b * 2 * math.pi / 7
                box((x + math.cos(ang) * R * 0.5, -9 + math.sin(ang) * R * 0.5, z), (R * 0.8, 0.12, 0.4), m["base"], rot=(0, ang, 0) if k % 2 else (ang, 0, 0), bevel=0)
            torus((x, -9, z), R * 0.25, 0.15, m["glow"], "z" if k % 2 else "x", 24, 6)
    elif ph == 7:    # soğutma: soğutucu kanyonları
        for k in range(46):
            x = -34 + k * 1.5
            if abs(x) < 9:
                continue
            for zc in (-22, 22):
                h = 8 + 4 * math.sin(k * 0.4)
                box((x, -14 + h / 2, zc + rnd.uniform(-2, 2)), (0.25, h, 14), m["metal"], bevel=0)
        for k, x, z, a in _ring(10, 12, 30, rnd):
            cyl((x, -10, z), 0.3, 10, m["glow"], "y", 8)
    elif ph == 8:    # I/O: port kuleleri + anten direkleri
        for k, x, z, a in _ring(18, 12, 34, rnd):
            h = rnd.uniform(5, 14)
            box((x, -14 + h / 2, z), (2, h, 2), m["metal"], bevel=0.08)
            for j in range(int(h / 1.4)):
                box((x, -13.5 + j * 1.4, z + 1.02), (1.2, 0.5, 0.05), m["base"] if j % 3 else m["amber"], bevel=0)
            if k % 3 == 0:
                cyl((x, -14 + h + 3, z), 0.08, 6, m["metal"], "y", 6)
                sphere((x, -14 + h + 6, z), 0.3, m["amber"], 8)
    elif ph == 9:    # kasa: dev cam paneller ve çerçeveler
        for k, x, z, a in _ring(8, 16, 30, rnd):
            box((x, -8, z), (12, 14, 0.2), m["glass"], rot=(0, 0, a + math.pi / 2), bevel=0.05)
            box((x, -1, z), (12.4, 0.4, 0.4), m["metal"], rot=(0, 0, a + math.pi / 2), bevel=0.05)
            box((x, -15, z), (12.4, 0.4, 0.4), m["glow"], rot=(0, 0, a + math.pi / 2), bevel=0)
    else:            # çekirdek: kristal kuleler + yörünge halkaları
        for k, x, z, a in _ring(16, 12, 32, rnd):
            h = rnd.uniform(6, 18)
            cone((x, -14 + h / 2, z), rnd.uniform(0.8, 2), 0.0, h, m["glow"] if k % 2 else m["glass"], "y", 6)
        for r in (20, 28, 36):
            torus((0, -10 + r * 0.1, 0), r, 0.25, m["amber"], "y", 96, 6)
    return finalize(os.path.join(MODELS, "backdrops", "backdrop_%02d.glb" % ph), 60000, recenter=False)

def build_backdrops():
    # uzak manzara her zaman düşük ayrıntıyla (ekranda küçük; üçgen bütçesi oyun alanına kalsın)
    keep = A.DETAIL
    A.DETAIL = 1
    try:
        return [_backdrop(ph) for ph in range(1, 11)]
    finally:
        A.DETAIL = keep

# ---------------------------------------------------------------------------
def main():
    t0 = time.time()
    os.makedirs(SCRATCH, exist_ok=True)
    items = []
    if "puzzle" in ONLY:
        for f in (p_stairs, p_goal, p_crate, p_lever, p_crank, p_handle, p_slider, p_portal, p_plate, p_crumble, p_phantom):
            r = f()
            items.extend(r if isinstance(r, list) else [r])
    if "pcb" in ONLY:
        items.append(build_pcb_texture())
    if "workshop" in ONLY:
        items.append(build_workshop())
    if "title" in ONLY:
        items.append(build_title())
    if "phases" in ONLY:
        items.extend(build_phases())
    if "themes" in ONLY:
        items.extend(build_themes())
    if "backdrops" in ONLY:
        items.extend(build_backdrops())
    if ONLY & {"icon", "cmds", "store"}:
        import blender_2d_generator as B2  # noqa: E402  (ikon, komut ikonları, mağaza görseli)
    for key, fn in (("icon", "build_icon"), ("cmds", "build_cmds"), ("store", "build_store")):
        if key in ONLY:
            r = getattr(B2, fn)()
            items.extend(r if isinstance(r, list) else [r])
    rep_path = os.path.join(HERE, "blender_scene_report.json")
    rep = {"blender": bpy.app.version_string, "items": items, "seconds": round(time.time() - t0, 1)}
    if os.path.exists(rep_path) and ONLY != {"puzzle", "pcb", "workshop", "title", "phases", "themes", "icon", "cmds", "store"}:
        try:
            old = json.load(open(rep_path))
            keep = {it["file"]: it for it in old.get("items", [])}
            for it in items:
                keep[it["file"]] = it
            rep["items"] = list(keep.values())
        except Exception:
            pass
    with open(rep_path, "w") as f:
        json.dump(rep, f, ensure_ascii=False, indent=1)
    bad = [it for it in items if not it["ok"]]
    for it in items:
        print("%-40s %6d / %6d üçgen %s" % (it["file"], it["tris"], it["budget"], "OK" if it["ok"] else "BÜTÇE AŞILDI"))
    print("toplam: %d öğe, %.1f sn, bütçe aşımı: %d" % (len(items), time.time() - t0, len(bad)))
    if bad:
        sys.exit(1)

if __name__ == "__main__":
    main()
