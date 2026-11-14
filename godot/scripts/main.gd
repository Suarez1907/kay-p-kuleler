## Kayıp Kuleler — Godot 4 istemcisi (sahne, kamera, girdi, animasyon, arayüz).
## Bulmaca kuralları scripts/logic.gd içinde (web sürümüyle aynı levels.json).
extends Node3D

const SAVE_PATH := "user://ilerleme.json"
const DIRS := PuzzleLogic.DIRS
const EL := 0.6154797  # atan(1/sqrt(2)) — izometrik yükseklik açısı
const STAIR_ROT := [0.0, -PI / 2, PI, PI / 2]

const PALETTES := [
	{"bg": ["#fde2d0", "#c8b6e8"], "blocks": ["#f7e4c8", "#f2cdb4", "#e8b3a3", "#d99ba0"], "accent": "#ff7f66", "mech": "#7cc6c4", "slide": "#8fb3e8", "bridge": "#a7d8a8", "door": "#e98aa4"},
	{"bg": ["#d6f0ee", "#b5c8ef"], "blocks": ["#eef3e2", "#cfe6d3", "#a9d3c8", "#8cbcc0"], "accent": "#ff9f5a", "mech": "#f2a7c3", "slide": "#f7c96b", "bridge": "#ffd27f", "door": "#d77fa1"},
	{"bg": ["#fff1c9", "#f6b6a5"], "blocks": ["#fff3dc", "#f8d9b7", "#efbc97", "#df9e86"], "accent": "#5aa9e6", "mech": "#8bd0b4", "slide": "#b49de8", "bridge": "#9fd3f0", "door": "#e57a7a"},
	{"bg": ["#e4f5d4", "#9fd4c9"], "blocks": ["#f5f0dc", "#e2e8c4", "#c6d9a8", "#a5c69a"], "accent": "#ff6f91", "mech": "#f6b26b", "slide": "#7eb6e0", "bridge": "#ffd166", "door": "#ef8bb0"},
	{"bg": ["#f3dcf5", "#a8b8f0"], "blocks": ["#f6e8f4", "#e4cdee", "#cbb3e3", "#a99ad6"], "accent": "#ffb347", "mech": "#73d2c2", "slide": "#ff9aa2", "bridge": "#9de3c8", "door": "#f28aa0"},
	{"bg": ["#d9ecfb", "#f7c6d9"], "blocks": ["#edf4fb", "#d3e4f3", "#b6cfe7", "#9ab6d9"], "accent": "#ff8a5c", "mech": "#ffcf70", "slide": "#f497b4", "bridge": "#a6e3b5", "door": "#e8798f"},
	{"bg": ["#ffe9d6", "#d5b4a1"], "blocks": ["#fbeee0", "#f1d6bd", "#e3bb9b", "#cf9f82"], "accent": "#4bb3a8", "mech": "#88b6e8", "slide": "#e59ac0", "bridge": "#9ed9c4", "door": "#d9727f"},
	{"bg": ["#e2f7f1", "#c3a9e6"], "blocks": ["#effaf4", "#d2efe2", "#b2dcd0", "#93c3c3"], "accent": "#ff7b9c", "mech": "#ffc46b", "slide": "#9b8fe3", "bridge": "#ffe08a", "door": "#ee8aa8"},
	{"bg": ["#fff4e0", "#a6d1e6"], "blocks": ["#fff7e8", "#f6e3c2", "#e8cda0", "#d4b07f"], "accent": "#e8637a", "mech": "#6fc2b0", "slide": "#87a8ec", "bridge": "#b6e3a3", "door": "#e07b8c"},
	{"bg": ["#f5e1da", "#8fb8c9"], "blocks": ["#f9ece4", "#ecd1c4", "#d9b2a5", "#bf9690"], "accent": "#ffb84d", "mech": "#74c0b9", "slide": "#ad9ce0", "bridge": "#a3d9b8", "door": "#e3869b"},
	{"bg": ["#1f2a4a", "#5b4b8a"], "blocks": ["#f2e6ff", "#d7c4f2", "#b9a3e3", "#9a86cf"], "accent": "#ffd36e", "mech": "#6fe0d0", "slide": "#ff9bb3", "bridge": "#9af0c8", "door": "#ff8fa3", "dark": true},
	{"bg": ["#ffe0e9", "#ffd6a5"], "blocks": ["#fff1f4", "#fbd9e2", "#f2bccc", "#e19fb4"], "accent": "#4aa3df", "mech": "#7bd3b0", "slide": "#b29bf0", "bridge": "#a8e6cf", "door": "#e06c8a"},
]

var levels: Array = []
var L: PuzzleLogic
var state: Dictionary
var level_idx := 0
var pal: Dictionary
var undo_stack: Array = []
var queue: Array = []
var anim = null
var displayed = null
var path_queue: Array = []
var win_shown := false
var instant := false
var progress := {"unlocked": 1, "best": {}}
var dead_timer := 0.0

var level_root: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var bg_grad: Gradient
var objs := {}
var cam_az := 45.0
var cam_az_cur := 45.0
var cam_drag := 0.0
var cam_zoom := 1.0
var cam_target := Vector3.ZERO
var cam_size := 12.0
var time := 0.0
var ptr = null
var mat_cache := {}

# arayüz
var ui: CanvasLayer
var lbl_title: Label
var lbl_moves: Label
var lbl_hint: Label
var hint_panel: PanelContainer
var lbl_toast: Label
var mech_box: HBoxContainer
var scr_title: Control
var scr_levels: Control
var scr_win: Control
var level_grid: GridContainer
var lbl_win: Label
var lbl_stars: Label
var btn_next: Button
var hud: Control

func _ready() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	levels = JSON.parse_string(f.get_as_text())
	_load_progress()
	_setup_world()
	_setup_ui()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		_autotest.call_deferred(args)
	else:
		_show("title")

# ---------------- dünya ----------------
func _setup_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gt := GradientTexture2D.new()
	bg_grad = Gradient.new()
	bg_grad.set_color(0, Color(PALETTES[0]["bg"][0]))
	bg_grad.set_color(1, Color(PALETTES[0]["bg"][1]))
	gt.gradient = bg_grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	tr.texture = gt
	bg_layer.add_child(tr)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e4daf0")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 0.5
	sun.light_color = Color("#fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.35
	sun.shadow_normal_bias = 2.5
	sun.shadow_blur = 1.5
	sun.rotation_degrees = Vector3(-55, 22, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	level_root = Node3D.new()
	add_child(level_root)

func _mat(color: String, alpha := false) -> StandardMaterial3D:
	var key := color + str(alpha)
	if not alpha and mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat_cache[key] = m
	return m

func _box(size: Vector3, color: String, alpha := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, alpha)
	return mi

func _sphere(r: float, color: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	mi.mesh = sm
	mi.material_override = _mat(color)
	return mi

func _pickbody(parent: Node3D, size: Vector3, info: Dictionary, offset := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = offset
	b.set_meta("pick", info)
	parent.add_child(b)
	return b

func _block_color(p: Vector3i) -> String:
	var b: Array = pal["blocks"]
	var c := Color(b[((p.y - L.min_y) % b.size() + b.size()) % b.size()])
	if (p.x + p.z) % 2 == 0:
		c = c.lightened(0.04)
	return "#" + c.to_html(false)

func _make_robot() -> Node3D:
	var g := Node3D.new()
	var body := _box(Vector3(0.46, 0.42, 0.4), "#fffaf2")
	body.position.y = 0.33
	g.add_child(body)
	var face := _box(Vector3(0.36, 0.22, 0.04), "#3b3555")
	face.position = Vector3(0, 0.37, 0.2)
	g.add_child(face)
	for x in [-0.08, 0.08]:
		var e := _sphere(0.035, "#7ff3ff")
		var em := StandardMaterial3D.new()
		em.albedo_color = Color("#7ff3ff")
		em.emission_enabled = true
		em.emission = Color("#7ff3ff")
		e.material_override = em
		e.position = Vector3(x, 0.38, 0.225)
		g.add_child(e)
	var ant := _box(Vector3(0.03, 0.16, 0.03), "#8a8299")
	ant.position.y = 0.62
	g.add_child(ant)
	var bulb := _sphere(0.05, pal["accent"])
	bulb.position.y = 0.72
	g.add_child(bulb)
	for x in [-0.12, 0.12]:
		var ft := _box(Vector3(0.12, 0.1, 0.18), "#8a8299")
		ft.position = Vector3(x, 0.06, 0.02)
		g.add_child(ft)
	for x in [-0.27, 0.27]:
		var arm := _box(Vector3(0.07, 0.2, 0.07), pal["accent"])
		arm.position = Vector3(x, 0.3, 0)
		g.add_child(arm)
	return g

func build_level(i: int) -> void:
	level_idx = i
	L = PuzzleLogic.new()
	L.load_level(levels[i])
	pal = PALETTES[L.palette % PALETTES.size()]
	bg_grad.set_color(0, Color(pal["bg"][0]))
	bg_grad.set_color(1, Color(pal["bg"][1]))
	for c in level_root.get_children():
		c.queue_free()
	state = L.initial_state()
	undo_stack = []
	queue = []
	anim = null
	path_queue = []
	win_shown = false
	dead_timer = 0.0
	objs = {"crates": [], "balls": [], "levers": [], "plates": [], "bridges": [], "bridge_bodies": [], "rotators": [], "sliders": [], "crumbles": [], "links": []}
	var aabb_min := Vector3(1e9, 1e9, 1e9)
	var aabb_max := Vector3(-1e9, -1e9, -1e9)
	var pts: Array = []
	for p in L.statics:
		pts.append(p)
		var v: Dictionary = L.statics[p]
		if v["t"] == "b":
			var m := _box(Vector3.ONE * 0.98, _block_color(p))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = Vector3(p)
			level_root.add_child(m)
			_pickbody(m, Vector3.ONE, {"kind": "block"})
		else:
			var g := Node3D.new()
			g.position = Vector3(p)
			g.rotation.y = STAIR_ROT[v["d"]]
			level_root.add_child(g)
			for k in 3:
				var h := (k + 1) / 3.0
				var st := _box(Vector3(1.0 / 3.0, h, 0.98), _block_color(p + Vector3i(0, 1, 0)))
				st.position = Vector3(-1.0 / 3.0 + k / 3.0, -0.5 + h / 2.0, 0)
				g.add_child(st)
			_pickbody(g, Vector3.ONE, {"kind": "block", "cell": p})
	for bi in L.bridges.size():
		var b: Dictionary = L.bridges[bi]
		var ms := []
		var bodies := []
		for c in b["cells"]:
			pts.append(c)
			var m := _box(Vector3.ONE * 0.98, pal["door"] if b["door"] else pal["bridge"], true)
			m.position = Vector3(c)
			level_root.add_child(m)
			ms.append(m)
			bodies.append(_pickbody(m, Vector3.ONE, {"kind": "block"}))
		objs["bridges"].append(ms)
		objs["bridge_bodies"].append(bodies)
	for ri in L.rotators.size():
		var r: Dictionary = L.rotators[ri]
		var g := Node3D.new()
		g.position = Vector3(r["pivot"].x, 0, r["pivot"].y)
		level_root.add_child(g)
		for b in r["blocks"]:
			for k in 4:
				pts.append(PuzzleLogic.rot_point(r["pivot"], b, k))
			var m := _box(Vector3.ONE * 0.98, pal["mech"])
			m.position = Vector3(b.x - r["pivot"].x, b.y, b.z - r["pivot"].y)
			g.add_child(m)
			_pickbody(m, Vector3.ONE, {"kind": "rot", "i": ri})
		var hy: float = r["handle"].y if r["handle"] != null else r["blocks"][0].y - 1
		var wheel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.68
		tm.outer_radius = 0.8
		wheel.mesh = tm
		wheel.material_override = _mat(pal["accent"])
		wheel.position.y = hy + 0.15
		g.add_child(wheel)
		for k in 2:
			var sp := _box(Vector3(1.5, 0.08, 0.1), pal["accent"])
			sp.position.y = hy + 0.15
			sp.rotation.y = k * PI / 2
			g.add_child(sp)
		var shaft := _box(Vector3(0.18, absf(r["blocks"][0].y - hy), 0.18), "#b8aecb")
		shaft.position.y = (r["blocks"][0].y + hy) / 2.0
		g.add_child(shaft)
		_pickbody(g, Vector3(2.0, 0.3, 2.0), {"kind": "handle", "i": ri}, Vector3(0, hy + 0.15, 0))
		objs["rotators"].append(g)
	for si in L.sliders.size():
		var s: Dictionary = L.sliders[si]
		var g := Node3D.new()
		level_root.add_child(g)
		var manual := L.is_manual(si)
		for b in s["blocks"]:
			pts.append(b + s["axis"] * s["min"])
			pts.append(b + s["axis"] * s["max"])
			var m := _box(Vector3.ONE * 0.98, pal["slide"] if manual else pal["mech"])
			m.position = Vector3(b)
			g.add_child(m)
			var stripe := _box(Vector3(1.0, 0.12, 1.0), "#ffffff")
			stripe.position.y = 0.25
			m.add_child(stripe)
			_pickbody(m, Vector3.ONE, {"kind": "slide", "i": si})
		# ray
		var b0: Vector3 = Vector3(s["blocks"][0])
		var ax := Vector3(s["axis"])
		var length := float(s["max"] - s["min"]) + 1.0
		var rail := _box(Vector3(0.1, 0.1, 0.1) + ax.abs() * length, "#8a7fa3")
		rail.position = b0 + ax * (s["min"] + s["max"]) / 2.0 + (Vector3(0, 0, 0.55) if s["axis"].y != 0 else Vector3(0, -0.55, 0))
		level_root.add_child(rail)
		if manual:
			for sg in [-1, 1]:
				var axs: Vector3 = ax * sg
				var best: Vector3 = b0
				for b in s["blocks"]:
					if Vector3(b).dot(axs) > best.dot(axs):
						best = Vector3(b)
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.22
				cm.height = 0.45
				cone.mesh = cm
				cone.material_override = _mat(pal["accent"])
				var pos := best + axs * 0.85
				if s["axis"].y != 0:
					pos = best + Vector3(0, 0.3 * sg, 0.75)
				cone.position = pos
				if axs.normalized().cross(Vector3.UP).length() > 0.01:
					cone.basis = Basis(Quaternion(Vector3.UP, axs.normalized()))
				elif sg < 0:
					cone.rotation.x = PI
				g.add_child(cone)
				_pickbody(cone, Vector3(0.5, 0.5, 0.5), {"kind": "sarrow", "i": si, "s": sg})
		objs["sliders"].append(g)
	for ci in L.crumbles.size():
		var c: Vector3i = L.crumbles[ci]
		pts.append(c)
		var m := _box(Vector3.ONE * 0.98, "#e9d8bf")
		m.position = Vector3(c)
		level_root.add_child(m)
		for k in 3:
			var crack := _box(Vector3(0.7, 0.02, 0.04), "#8c6f58")
			crack.position = Vector3(0, 0.5, -0.25 + k * 0.25)
			crack.rotation.y = 0.5 - k * 0.45
			m.add_child(crack)
		var body := _pickbody(m, Vector3.ONE, {"kind": "block"})
		objs["crumbles"].append([m, body])
	for pl in L.plates:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.36
		cm.bottom_radius = 0.4
		cm.height = 0.08
		m.mesh = cm
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(pal["mech"])
		pm.emission_enabled = true
		pm.emission = Color(pal["mech"])
		pm.emission_energy_multiplier = 0.0
		m.material_override = pm
		m.position = Vector3(pl["p"]) + Vector3(0, -0.46, 0)
		level_root.add_child(m)
		objs["plates"].append(m)
	for li in L.levers.size():
		var lv: Dictionary = L.levers[li]
		var g := Node3D.new()
		g.position = Vector3(lv["p"]) + Vector3(0, -0.5, 0)
		level_root.add_child(g)
		var base := _box(Vector3(0.6, 0.18, 0.4), "#8a7fa3")
		base.position.y = 0.09
		g.add_child(base)
		var arm := Node3D.new()
		arm.position.y = 0.16
		g.add_child(arm)
		var stick := _box(Vector3(0.07, 0.55, 0.07), "#d8d0e6")
		stick.position.y = 0.27
		arm.add_child(stick)
		var knob := _sphere(0.11, pal["accent"])
		knob.position.y = 0.56
		arm.add_child(knob)
		_pickbody(g, Vector3(0.7, 0.9, 0.7), {"kind": "lever", "i": li}, Vector3(0, 0.45, 0))
		objs["levers"].append(arm)
	for ln in L.links:
		for c in [ln["a"], ln["b"]]:
			var m := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.24
			tm.outer_radius = 0.34
			m.mesh = tm
			m.material_override = _mat(pal["accent"], true)
			m.scale = Vector3(1, 0.15, 1)
			m.position = Vector3(c) + Vector3(0, -0.48, 0)
			level_root.add_child(m)
			objs["links"].append({"m": m, "view": ln["view"]})
	# hedef
	var gg := Node3D.new()
	gg.position = Vector3(L.goal) + Vector3(0, -0.5, 0)
	level_root.add_child(gg)
	var gem := MeshInstance3D.new()
	var pm2 := PrismMesh.new()
	pm2.size = Vector3(0.35, 0.4, 0.35)
	gem.mesh = pm2
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(pal["accent"])
	gmat.emission_enabled = true
	gmat.emission = Color(pal["accent"])
	gmat.emission_energy_multiplier = 0.6
	gem.material_override = gmat
	gem.position.y = 0.55
	gg.add_child(gem)
	_pickbody(gg, Vector3(0.8, 0.8, 0.8), {"kind": "cellof", "cell": L.goal}, Vector3(0, 0.4, 0))
	objs["gem"] = gem
	pts.append(L.goal)
	# varlıklar
	for ci in state["crates"].size():
		var m := _box(Vector3.ONE * 0.84, "#d9a066")
		var band := _box(Vector3(0.86, 0.12, 0.86), "#a8703f")
		m.add_child(band)
		level_root.add_child(m)
		_pickbody(m, Vector3.ONE * 0.84, {"kind": "crate", "i": ci})
		objs["crates"].append(m)
	for bi in state["balls"].size():
		var m := _sphere(0.36, "#f4f1ff")
		var stripe := MeshInstance3D.new()
		var tm2 := TorusMesh.new()
		tm2.inner_radius = 0.33
		tm2.outer_radius = 0.38
		stripe.mesh = tm2
		stripe.material_override = _mat("#ff7f88")
		stripe.rotation.x = PI / 2
		m.add_child(stripe)
		level_root.add_child(m)
		_pickbody(m, Vector3.ONE * 0.7, {"kind": "ball", "i": bi})
		objs["balls"].append(m)
	objs["player"] = _make_robot()
	level_root.add_child(objs["player"])
	pts.append(state["p"])
	for p in pts:
		aabb_min = aabb_min.min(Vector3(p))
		aabb_max = aabb_max.max(Vector3(p))
	cam_target = (aabb_min + aabb_max) / 2.0
	var sz := aabb_max - aabb_min
	cam_size = maxf(9.0, (maxf(sz.x, sz.z) * 0.62 + sz.y * 0.45) * 1.25 + 3.2)
	cam_az = 45.0 + 90.0 * state["view"]
	cam_az_cur = cam_az + 25.0
	cam_drag = 0.0
	cam_zoom = 1.0
	displayed = state
	apply_visual(state, state, 1.0)
	_build_mech_panel()
	_update_hud()
	hint_panel.visible = false

# ---------------- görsel interpolasyon ----------------
static func _rot_delta(a: int, b: int) -> int:
	var d := ((b - a) % 4 + 4) % 4
	return -1 if d == 3 else d

func _entity_pos(pa, pb, t: float, sA: Dictionary, sB: Dictionary):
	if pa == null and pb == null:
		return null
	if pb == null:
		return Vector3(pa) + Vector3(0, -0.5 - t * t * 6.0, 0)
	if pa == null:
		pa = pb
	for i in sA["rots"].size():
		if sA["rots"][i] == sB["rots"][i]:
			continue
		var d := _rot_delta(sA["rots"][i], sB["rots"][i])
		var pv: Vector2i = L.rotators[i]["pivot"]
		if PuzzleLogic.rot_point(pv, pa, d) == pb and not (pa.x == pb.x and pa.z == pb.z):
			var th := d * PI / 2 * t
			var dx: float = pa.x - pv.x
			var dz: float = pa.z - pv.y
			return Vector3(pv.x + dx * cos(th) + dz * sin(th), pa.y - 0.5, pv.y - dx * sin(th) + dz * cos(th))
	return Vector3(pa).lerp(Vector3(pb), t) + Vector3(0, -0.5, 0)

static func _ease(t: float) -> float:
	return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2

func apply_visual(sA: Dictionary, sB: Dictionary, t: float) -> void:
	var te := _ease(t)
	var pl: Node3D = objs["player"]
	var pp = _entity_pos(null if sA["dead"] else sA["p"], null if sB["dead"] else sB["p"], t if sB["dead"] else te, sA, sB)
	pl.visible = pp != null
	if pp != null:
		pl.position = pp
		if sA["p"].y == sB["p"].y and sA["p"] != sB["p"] and sA["rots"] == sB["rots"] and sA["slides"] == sB["slides"]:
			pl.position.y += sin(PI * t) * 0.14
		var dv: Vector3i = DIRS[sB["f"]]
		var target := atan2(dv.x, dv.z)
		pl.rotation.y = lerp_angle(pl.rotation.y, target, minf(1.0, t * 2.0 + 0.25))
	for i in objs["crates"].size():
		var p = _entity_pos(sA["crates"][i], sB["crates"][i], te, sA, sB)
		var m: Node3D = objs["crates"][i]
		m.visible = p != null
		if p != null:
			m.position = p + Vector3(0, 0.42, 0)
	for i in objs["balls"].size():
		var a = sA["balls"][i]["p"] if sA["balls"][i] != null else null
		var b = sB["balls"][i]["p"] if sB["balls"][i] != null else null
		var p = _entity_pos(a, b, t, sA, sB)
		var m: Node3D = objs["balls"][i]
		m.visible = p != null
		if p != null:
			m.position = p + Vector3(0, 0.36, 0)
			if a != null and b != null and (a.x != b.x or a.z != b.z):
				var mv := Vector3(b - a)
				m.rotation = Vector3(mv.z, 0, -mv.x) * (t / 0.36)
	for i in objs["rotators"].size():
		var d := _rot_delta(sA["rots"][i], sB["rots"][i])
		objs["rotators"][i].rotation.y = (sA["rots"][i] + d * te) * PI / 2
	for i in objs["sliders"].size():
		var v := lerpf(sA["slides"][i], sB["slides"][i], te)
		objs["sliders"][i].position = Vector3(L.sliders[i]["axis"]) * v
	for i in objs["bridges"].size():
		var v := lerpf(1.0 if sA["bridges"][i] else 0.0, 1.0 if sB["bridges"][i] else 0.0, te)
		for m in objs["bridges"][i]:
			m.material_override.albedo_color.a = 0.16 + 0.84 * v
			m.scale = Vector3.ONE * (0.86 + 0.14 * v)
		for body in objs["bridge_bodies"][i]:
			body.collision_layer = 1 if sB["bridges"][i] else 0
	for i in objs["crumbles"].size():
		var gone: bool = sB["crumbles"][i] != 0
		objs["crumbles"][i][0].visible = not gone
		objs["crumbles"][i][1].collision_layer = 0 if gone else 1
	for i in objs["levers"].size():
		objs["levers"][i].rotation.z = lerpf(0.6 if sA["levers"][i] else -0.6, 0.6 if sB["levers"][i] else -0.6, te)
	for i in objs["plates"].size():
		var pr := lerpf(1.0 if _plate_down(sA, L.plates[i]["p"]) else 0.0, 1.0 if _plate_down(sB, L.plates[i]["p"]) else 0.0, te)
		objs["plates"][i].position.y = L.plates[i]["p"].y - 0.46 - pr * 0.035
		objs["plates"][i].material_override.emission_energy_multiplier = pr * 0.8
	for o in objs["links"]:
		o["m"].material_override.albedo_color.a = 0.95 if sB["view"] == o["view"] else 0.22

func _plate_down(s: Dictionary, p: Vector3i) -> bool:
	if not s["dead"] and s["p"] == p:
		return true
	for c in s["crates"]:
		if c != null and c == p:
			return true
	for b in s["balls"]:
		if b != null and b["p"] == p:
			return true
	return false

# ---------------- eylem kuyruğu ----------------
func _frame_dur(a: Dictionary, b: Dictionary, first: bool, action: Dictionary) -> float:
	if instant:
		return 0.0
	if first:
		match String(action["t"]):
			"rot": return 0.42
			"slide": return 0.26
			"view": return 0.0
		return 0.19
	if a["slides"] != b["slides"]:
		return 0.24
	if a["bridges"] != b["bridges"]:
		return 0.22
	if a["p"] == b["p"] and a["crates"] == b["crates"]:
		return 0.075
	return 0.1

func do_action(action: Dictionary) -> bool:
	if state.is_empty() or state["dead"]:
		return false
	var res := L.step(state, action)
	if not res["ok"]:
		return false
	state = res["state"]
	var prev = queue[-1]["to"] if queue.size() > 0 else (anim["to"] if anim != null else displayed)
	var frames: Array = res["frames"]
	for k in frames.size():
		queue.append({"from": prev, "to": frames[k], "dur": _frame_dur(prev, frames[k], k == 0, action), "t": 0.0})
		prev = frames[k]
	_update_hud()
	return true

func _snapshot() -> void:
	undo_stack.append(PuzzleLogic.clone(state))
	if undo_stack.size() > 300:
		undo_stack.pop_front()

func _command(action: Dictionary) -> void:
	if state.is_empty() or win_shown or state["dead"] or _busy():
		return
	_snapshot()
	if not do_action(action):
		undo_stack.pop_back()

func _busy() -> bool:
	return anim != null or queue.size() > 0

func _process(dt: float) -> void:
	time += dt
	_update_camera(dt)
	if objs.is_empty():
		return
	_update_queue(dt)
	if objs.has("gem"):
		objs["gem"].rotation.y = time * 1.6
		objs["gem"].position.y = 0.55 + sin(time * 2.4) * 0.07
	if dead_timer > 0.0:
		dead_timer -= dt
		if dead_timer <= 0.0:
			undo()

func _update_queue(dt: float) -> void:
	while true:
		if anim == null:
			if queue.is_empty():
				break
			anim = queue.pop_front()
			_on_frame_start(anim["from"], anim["to"])
		anim["t"] += dt / anim["dur"] if anim["dur"] > 0 else 1.0
		dt = 0.0
		if anim["t"] >= 1.0:
			apply_visual(anim["from"], anim["to"], 1.0)
			displayed = anim["to"]
			anim = null
			if queue.is_empty() or not instant:
				break
		else:
			apply_visual(anim["from"], anim["to"], anim["t"])
			break
	if anim == null and queue.is_empty():
		if path_queue.size() > 0 and not state["dead"] and not win_shown:
			var d: int = path_queue.pop_front()
			if not do_action({"t": "move", "d": d}):
				path_queue = []
			return
		if displayed == state:
			_check_end()

func _on_frame_start(a: Dictionary, b: Dictionary) -> void:
	for i in b["crumbles"].size():
		if b["crumbles"][i] != 0 and a["crumbles"][i] == 0:
			_shatter(Vector3(L.crumbles[i]))

func _check_end() -> void:
	if win_shown:
		return
	if L.is_win(state):
		win_shown = true
		_on_win()
	elif state["dead"] and dead_timer <= 0.0:
		_toast("Robo düştü! Bir adım geri alınıyor...")
		dead_timer = 0.01 if instant else 1.1

func undo() -> void:
	if undo_stack.is_empty():
		return
	path_queue = []
	queue = []
	anim = null
	state = undo_stack.pop_back()
	displayed = state
	apply_visual(state, state, 1.0)
	_sync_view()
	_update_hud()

func restart() -> void:
	if L == null:
		return
	_snapshot()
	path_queue = []
	queue = []
	anim = null
	state = L.initial_state()
	displayed = state
	win_shown = false
	apply_visual(state, state, 1.0)
	_sync_view()
	_update_hud()

func _sync_view() -> void:
	var want: float = 45.0 + 90.0 * state["view"]
	var d := fposmod(want - cam_az + 180.0, 360.0) - 180.0
	cam_az += d

func rotate_view(s: int) -> void:
	if state.is_empty() or state["dead"] or win_shown or _busy():
		return
	do_action({"t": "view", "s": s})
	cam_az += 90.0 * s

# ---------------- fizik süsleri (Godot fizik motoru) ----------------
func _spawn_debris(pos: Vector3, size: float, color: String, vel: Vector3, life: float) -> void:
	var rb := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE * size
	cs.shape = sh
	rb.add_child(cs)
	var m := _box(Vector3.ONE * size, color)
	rb.add_child(m)
	rb.position = pos
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	rb.collision_layer = 2
	rb.collision_mask = 1
	var tm := Timer.new()
	tm.wait_time = life
	tm.one_shot = true
	tm.autostart = true
	tm.timeout.connect(rb.queue_free)
	rb.add_child(tm)
	level_root.add_child(rb)

func _shatter(c: Vector3) -> void:
	for k in 8:
		var off := Vector3(0.25 if k & 1 else -0.25, 0.25 if k & 2 else -0.25, 0.25 if k & 4 else -0.25)
		_spawn_debris(c + off, 0.42, "#d9c2a3", Vector3(randf_range(-1, 1), randf_range(0, 2), randf_range(-1, 1)), 2.5)

func _confetti(c: Vector3) -> void:
	var cols := [pal["accent"], pal["mech"], pal["slide"], pal["bridge"], "#ffffff"]
	for k in 36:
		var a := randf() * TAU
		var sp := randf_range(2, 5)
		_spawn_debris(c + Vector3(0, 0.5, 0), randf_range(0.1, 0.2), cols[k % cols.size()], Vector3(cos(a) * sp, randf_range(6, 11), sin(a) * sp), 3.5)

# ---------------- kamera ----------------
func _update_camera(dt: float) -> void:
	var target := cam_az + cam_drag
	cam_az_cur = lerpf(cam_az_cur, target, minf(1.0, dt * 9.0))
	var a := deg_to_rad(cam_az_cur)
	var off := Vector3(cos(EL) * cos(a), sin(EL), cos(EL) * sin(a)) * 60.0
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)
	var vp := get_viewport().get_visible_rect().size
	var asp := vp.x / maxf(1.0, vp.y)
	var sz := cam_size
	if asp < 1.0:
		sz = sz / asp * 0.9
	cam.size = lerpf(cam.size, sz / cam_zoom, minf(1.0, dt * 8.0)) if cam.size > 0.01 else sz

func _cam_dir(screen: String) -> int:
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var want: Vector3
	match screen:
		"up": want = fwd + right
		"right": want = right - fwd
		"down": want = -(fwd + right)
		_: want = fwd - right
	var best := 0
	var bd := -1e9
	for i in 4:
		var v: float = DIRS[i].x * want.x + DIRS[i].z * want.z
		if v > bd:
			bd = v
			best = i
	return best

# ---------------- girdi ----------------
func _pick(pos: Vector2):
	var from := cam.project_ray_origin(pos)
	var to := from + cam.project_ray_normal(pos) * 500.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var col: Object = hit["collider"]
	if not col.has_meta("pick"):
		return null
	return {"info": col.get_meta("pick"), "pos": hit["position"], "normal": hit["normal"], "body": col}

func _approach(obj_cell: Vector3i, prefer) -> bool:
	var best = null
	for d in 4:
		var c: Vector3i = obj_cell - DIRS[d]
		var path = L.find_path(state, c)
		if path == null:
			continue
		var cost: float = path.size() - (0.5 if prefer != null and d == prefer else 0.0)
		if best == null or cost < best["cost"]:
			best = {"path": path, "d": d, "cost": cost}
	if best == null:
		return false
	path_queue = best["path"] + [best["d"]]
	return true

func _handle_click(pk) -> void:
	if pk == null or state.is_empty() or win_shown or state["dead"]:
		return
	var info: Dictionary = pk["info"]
	var kind: String = info["kind"]
	if kind == "handle":
		_command({"t": "rot", "i": info["i"], "s": 1})
		return
	if kind == "sarrow":
		_command({"t": "slide", "i": info["i"], "s": info["s"]})
		return
	if _busy():
		return
	_snapshot()
	path_queue = []
	var ok := false
	var n: Vector3 = pk["normal"]
	if kind == "lever":
		ok = _approach(L.levers[info["i"]]["p"], null)
	elif kind == "crate" or kind == "ball":
		var c: Vector3i = state["crates"][info["i"]] if kind == "crate" else state["balls"][info["i"]]["p"]
		if kind == "crate" and n.y > 0.6:
			var p = L.find_path(state, c + Vector3i(0, 1, 0))
			if p != null:
				path_queue = p
				ok = true
		else:
			var pref = null
			if absf(n.y) < 0.6:
				var v := Vector3i(-roundi(n.x), 0, -roundi(n.z))
				pref = DIRS.find(v)
				if pref < 0:
					pref = null
			ok = _approach(c, pref)
	else:
		var target: Vector3i
		if kind == "cellof":
			target = info["cell"]
		elif info.has("cell"):
			target = info["cell"] + Vector3i(0, 1, 0)
		else:
			var body: Node3D = pk["body"]
			var gp := body.global_position
			target = Vector3i(roundi(gp.x), roundi(gp.y) + 1, roundi(gp.z))
		var p = L.find_path(state, target)
		if p != null and p.size() > 0:
			path_queue = p
			ok = true
	if not ok:
		undo_stack.pop_back()

func _unhandled_input(event: InputEvent) -> void:
	if not hud.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_zoom = clampf(cam_zoom * 1.1, 0.5, 2.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_zoom = clampf(cam_zoom / 1.1, 0.5, 2.5)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				ptr = {"start": mb.position, "button": mb.button_index, "moved": false, "mode": "", "steps": 0,
					"pk": _pick(mb.position) if mb.button_index == MOUSE_BUTTON_LEFT else null, "did": false}
			elif ptr != null:
				if not ptr["moved"]:
					if ptr["button"] == MOUSE_BUTTON_LEFT:
						_handle_click(ptr["pk"])
				elif ptr["mode"] == "cam":
					var steps := roundi(cam_drag / 90.0)
					cam_az += cam_drag
					cam_drag = 0.0
					cam_az = 45.0 + 90.0 * roundf((cam_az - 45.0) / 90.0)
					for k in absi(steps):
						do_action({"t": "view", "s": signi(steps)})
				elif ptr.get("snap", false) and not ptr["did"]:
					undo_stack.pop_back()
				ptr = null
	elif event is InputEventMouseMotion and ptr != null:
		var mm := event as InputEventMouseMotion
		var dvec: Vector2 = mm.position - ptr["start"]
		if not ptr["moved"] and dvec.length() > 10.0:
			ptr["moved"] = true
			var k := ""
			if ptr["pk"] != null:
				k = ptr["pk"]["info"]["kind"]
			if k == "rot" or k == "handle":
				ptr["mode"] = "rot"
			elif (k == "slide" or k == "sarrow") and L.is_manual(ptr["pk"]["info"]["i"]):
				ptr["mode"] = "slide"
			else:
				ptr["mode"] = "cam"
			if ptr["mode"] != "cam":
				_snapshot()
				ptr["snap"] = true
		if not ptr["moved"]:
			return
		if ptr["mode"] == "cam":
			cam_drag = dvec.x * 0.35
		elif ptr["mode"] == "rot":
			var want := int(dvec.x / 70.0)
			while ptr["steps"] != want and not _busy():
				var s := signi(want - ptr["steps"])
				if do_action({"t": "rot", "i": ptr["pk"]["info"]["i"], "s": s}):
					ptr["steps"] += s
					ptr["did"] = true
				else:
					ptr["steps"] = want
		elif ptr["mode"] == "slide":
			var i: int = ptr["pk"]["info"]["i"]
			var p0: Vector3 = Vector3(L.sliders[i]["blocks"][0]) + objs["sliders"][i].position
			var sa := cam.unproject_position(p0)
			var sb := cam.unproject_position(p0 + Vector3(L.sliders[i]["axis"]))
			var sv := sb - sa
			var ln := maxf(1.0, sv.length())
			var want := roundi(dvec.dot(sv) / ln / ln)
			while ptr["steps"] != want and not _busy():
				var s := signi(want - ptr["steps"])
				if do_action({"t": "slide", "i": i, "s": s}):
					ptr["steps"] += s
					ptr["did"] = true
				else:
					ptr["steps"] = want
					break
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var dirs := {KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down", KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right"}
		if dirs.has(key):
			path_queue = []
			_command({"t": "move", "d": _cam_dir(dirs[key])})
		elif key == KEY_Z:
			undo()
		elif key == KEY_R:
			restart()
		elif key == KEY_Q:
			rotate_view(-1)
		elif key == KEY_E:
			rotate_view(1)
		elif key == KEY_H:
			_toggle_hint()
		elif key == KEY_M:
			_open_levels()

# ---------------- kazanma / ilerleme ----------------
func _on_win() -> void:
	_confetti(Vector3(L.goal))
	var par: int = L.par if L.par > 0 else state["moves"]
	var moves: int = state["moves"]
	var stars := 3 if moves <= par else (2 if moves <= ceili(par * 1.4) else 1)
	var key := str(level_idx)
	var prev = progress["best"].get(key)
	if prev == null or moves < int(prev["moves"]):
		progress["best"][key] = {"moves": moves, "stars": stars}
	progress["unlocked"] = maxi(int(progress["unlocked"]), mini(levels.size(), level_idx + 2))
	_save_progress()
	lbl_stars.text = "%d / 3 yıldız" % stars
	lbl_win.text = "%d hamlede tamamladın (par: %d)." % [moves, par]
	if level_idx == levels.size() - 1:
		lbl_win.text += "\nTüm kuleleri fethettin!"
	btn_next.visible = level_idx < levels.size() - 1
	if instant:
		_show("win")
	else:
		get_tree().create_timer(0.9).timeout.connect(func(): _show("win"))

func _load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			progress["unlocked"] = int(d.get("unlocked", 1))
			progress["best"] = d.get("best", {})

func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))

# ---------------- arayüz ----------------
func _style(color: Color, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _btn(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(Color("#ff8e72") if primary else Color(1, 1, 1, 0.65)))
	b.add_theme_stylebox_override("hover", _style(Color("#ff7a5a") if primary else Color(1, 1, 1, 0.85)))
	b.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.5)))
	b.add_theme_color_override("font_color", Color.WHITE if primary else Color("#4a3f5c"))
	b.add_theme_color_override("font_hover_color", Color.WHITE if primary else Color("#4a3f5c"))
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b

func _label(text: String, size := 18, color := Color("#4a3f5c")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _overlay() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.25)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(c)
	return c

func _card(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var pc := PanelContainer.new()
	var sb := _style(Color(1, 1, 1, 0.95), 28)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	return v

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.add_theme_constant_override("separation", 12)
	hud.add_child(top)
	top.add_child(_btn("Seviyeler", _open_levels))
	lbl_title = _label("", 22)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lbl_title)
	lbl_moves = _label("", 18)
	top.add_child(lbl_moves)
	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -170
	side.offset_right = -12
	side.offset_top = 70
	side.add_theme_constant_override("separation", 8)
	hud.add_child(side)
	side.add_child(_btn("Geri Al (Z)", undo))
	side.add_child(_btn("Yeniden (R)", restart))
	side.add_child(_btn("Kamera Sol (Q)", func(): rotate_view(-1)))
	side.add_child(_btn("Kamera Sağ (E)", func(): rotate_view(1)))
	side.add_child(_btn("İpucu (H)", _toggle_hint))
	mech_box = HBoxContainer.new()
	mech_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mech_box.offset_top = -64
	mech_box.offset_bottom = -14
	mech_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mech_box.add_theme_constant_override("separation", 10)
	hud.add_child(mech_box)
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.92), 16))
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_panel.offset_top = 70
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_hint = _label("", 17)
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_hint.custom_minimum_size = Vector2(520, 0)
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(lbl_hint)
	hud.add_child(hint_panel)
	var help := _label("Tıkla: yürü · Kutu/top: it · Kol: çevir · Platformu sürükle: döndür/kaydır · Sağ tık sürükle: kamera · Oklar/WASD: adım", 13)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 12
	help.offset_top = -90
	hud.add_child(help)
	lbl_toast = _label("", 20, Color.WHITE)
	lbl_toast.set_anchors_preset(Control.PRESET_CENTER)
	lbl_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_toast.add_theme_stylebox_override("normal", _style(Color(0.29, 0.25, 0.36, 0.85), 16))
	lbl_toast.visible = false
	hud.add_child(lbl_toast)
	# başlık
	scr_title = _overlay()
	var v := _card(scr_title)
	var logo := _label("Kayıp Kuleler", 56, Color("#ff7f66"))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)
	var sub := _label("Robo'yu imkânsız kulelerin tepesine ulaştır.\nDöndür, kaydır, it, yuvarla — ve düşün!", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_btn("Oyna", _open_levels, true))
	# seviyeler
	scr_levels = _overlay()
	var v2 := _card(scr_levels)
	var h2 := _label("Seviyeler", 30)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(h2)
	level_grid = GridContainer.new()
	level_grid.columns = 5
	level_grid.add_theme_constant_override("h_separation", 10)
	level_grid.add_theme_constant_override("v_separation", 10)
	v2.add_child(level_grid)
	v2.add_child(_btn("Geri", func(): _show("title")))
	# kazanma
	scr_win = _overlay()
	var v3 := _card(scr_win)
	var h3 := _label("Seviye Tamamlandı!", 30)
	h3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v3.add_child(h3)
	lbl_stars = _label("", 34, Color("#ffb400"))
	lbl_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v3.add_child(lbl_stars)
	lbl_win = _label("", 18)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v3.add_child(lbl_win)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v3.add_child(row)
	row.add_child(_btn("Seviyeler", _open_levels))
	row.add_child(_btn("Tekrar", func(): _start_level(level_idx)))
	btn_next = _btn("Sonraki >", func(): _start_level(mini(levels.size() - 1, level_idx + 1)), true)
	row.add_child(btn_next)

func _show(which: String) -> void:
	scr_title.visible = which == "title"
	scr_levels.visible = which == "levels"
	scr_win.visible = which == "win"
	hud.visible = which == ""

func _open_levels() -> void:
	for c in level_grid.get_children():
		c.queue_free()
	for i in levels.size():
		var locked: bool = i >= int(progress["unlocked"])
		var best = progress["best"].get(str(i))
		var stars := ""
		if best != null:
			stars = "%d/3 yıldız" % int(best["stars"])
		var txt := "%d\n%s\n%s" % [i + 1, levels[i]["name"], "Kilitli" if locked else stars]
		var b := _btn(txt, func(): _start_level(i))
		b.custom_minimum_size = Vector2(130, 96)
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = locked
		level_grid.add_child(b)
	_show("levels")

func _start_level(i: int) -> void:
	build_level(i)
	_show("")

func _build_mech_panel() -> void:
	for c in mech_box.get_children():
		c.queue_free()
	for i in L.rotators.size():
		var idx := i
		mech_box.add_child(_label("Döner %d" % (i + 1), 15))
		mech_box.add_child(_btn("Sol", func(): _command({"t": "rot", "i": idx, "s": -1})))
		mech_box.add_child(_btn("Sağ", func(): _command({"t": "rot", "i": idx, "s": 1})))
	for i in L.sliders.size():
		if not L.is_manual(i):
			continue
		var idx := i
		var vert: bool = L.sliders[i]["axis"].y != 0
		mech_box.add_child(_label(("Asansör %d" if vert else "Kaydırıcı %d") % (i + 1), 15))
		mech_box.add_child(_btn("Aşağı" if vert else "Geri", func(): _command({"t": "slide", "i": idx, "s": -1})))
		mech_box.add_child(_btn("Yukarı" if vert else "İleri", func(): _command({"t": "slide", "i": idx, "s": 1})))

func _update_hud() -> void:
	if L == null:
		return
	var dark: bool = pal.get("dark", false)
	lbl_title.text = "Seviye %d · %s" % [level_idx + 1, L.name]
	lbl_title.add_theme_color_override("font_color", Color("#f4ecff") if dark else Color("#4a3f5c"))
	lbl_moves.text = "Hamle %d / par %d" % [state["moves"], L.par]
	lbl_moves.add_theme_color_override("font_color", Color("#f4ecff") if dark else Color("#4a3f5c"))

func _toggle_hint() -> void:
	lbl_hint.text = L.hint if L != null else ""
	hint_panel.visible = not hint_panel.visible

func _toast(msg: String) -> void:
	lbl_toast.text = "  " + msg + "  "
	lbl_toast.visible = true
	get_tree().create_timer(1.6).timeout.connect(func(): lbl_toast.visible = false)

# ---------------- otomatik test ----------------
## godot --path godot -- --autotest [--shots=/yol]
func _autotest(args: PackedStringArray) -> void:
	var shots := ""
	for a in args:
		if a.begins_with("--shots="):
			shots = a.substr(8)
	var fails := 0
	for i in levels.size():
		instant = true
		_start_level(i)
		var sol: Array = L.solution
		var ok := true
		for k in sol.size():
			if not do_action(sol[k]):
				ok = false
				break
			while _busy() or path_queue.size() > 0:
				await get_tree().process_frame
			if shots != "" and k == sol.size() / 2 and i in [0, 4, 8, 10, 14]:
				instant = false
				for f in 40:
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("%s/godot-seviye%02d.png" % [shots, i + 1])
				instant = true
		for f in 3:
			await get_tree().process_frame
		var won := ok and win_shown and L.is_win(state)
		if not won:
			fails += 1
		print("[autotest] Seviye %d (%s): %s" % [i + 1, L.name, "TAMAMLANDI" if won else "BAŞARISIZ"])
	# tıkla-yürü: ilk seviyede hedefe yol bulma
	instant = true
	_start_level(0)
	var path = L.find_path(state, L.goal)
	print("[autotest] Seviye 1 yol bulma (tıkla-yürü): ", "OK" if path != null else "YOK")
	if path == null:
		fails += 1
	else:
		path_queue = path
		while _busy() or path_queue.size() > 0:
			await get_tree().process_frame
		if not L.is_win(state):
			fails += 1
	if shots != "":
		_open_levels()
		for f in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shots + "/godot-seviye-secimi.png")
	print("[autotest] SONUÇ: ", "GEÇTİ" if fails == 0 else "%d HATA" % fails)
	get_tree().quit(0 if fails == 0 else 1)
