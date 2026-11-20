## Kayıp Kuleler — Godot 4 istemcisi (programlama bulmacası, prototip).
## Kurallar: scripts/logic.gd (ızgara fizik motoru) + scripts/program.gd (yorumlayıcı).
## Seviyeler: data/levels.json (tools/build.mjs üretir, web sürümüyle aynı).
extends Node3D

const SAVE_PATH := "user://ilerleme.json"
const DIRS := PuzzleLogic.DIRS
const EL := 0.6154797
const ROWS := ["main", "p1", "p2"]
const ROW_LABEL := {"main": "Ana", "p1": "F1", "p2": "F2"}
const SPEEDS := [1.0, 2.0, 4.0]
const PANEL_W := 400.0
const CMD_COLOR := {"F": "#5b8def", "L": "#9b7be8", "R": "#9b7be8", "J": "#2fb39f", "A": "#ff9248", "W": "#e8648a", "1": "#efa92b", "2": "#3fb0dd"}
const ROW_COLOR := {"main": "#6a5b96", "p1": "#e9a225", "p2": "#3aa7d6"}
const COND_COLOR := {"o": "#2fc37a", "x": "#ff7a45"}
const COND_NAME := {"": "Her zaman", "o": "Önü açıksa", "x": "Önü kapalıysa"}

const PALETTES := [
	{ "bg": ["#fde2d0", "#c8b6e8"], "blocks": ["#f7e4c8", "#f2cdb4", "#e8b3a3", "#d99ba0"], "accent": "#ff7f66", "mech": "#7cc6c4", "slide": "#8fb3e8", "bridge": "#a7d8a8", "door": "#e98aa4" },
	{ "bg": ["#d6f0ee", "#b5c8ef"], "blocks": ["#eef3e2", "#cfe6d3", "#a9d3c8", "#8cbcc0"], "accent": "#ff9f5a", "mech": "#f2a7c3", "slide": "#f7c96b", "bridge": "#ffd27f", "door": "#d77fa1" },
	{ "bg": ["#fff1c9", "#f6b6a5"], "blocks": ["#fff3dc", "#f8d9b7", "#efbc97", "#df9e86"], "accent": "#5aa9e6", "mech": "#8bd0b4", "slide": "#b49de8", "bridge": "#9fd3f0", "door": "#e57a7a" },
	{ "bg": ["#e4f5d4", "#9fd4c9"], "blocks": ["#f5f0dc", "#e2e8c4", "#c6d9a8", "#a5c69a"], "accent": "#ff6f91", "mech": "#f6b26b", "slide": "#7eb6e0", "bridge": "#ffd166", "door": "#ef8bb0" },
	{ "bg": ["#f3dcf5", "#a8b8f0"], "blocks": ["#f6e8f4", "#e4cdee", "#cbb3e3", "#a99ad6"], "accent": "#ffb347", "mech": "#73d2c2", "slide": "#ff9aa2", "bridge": "#9de3c8", "door": "#f28aa0" },
	{ "bg": ["#d9ecfb", "#f7c6d9"], "blocks": ["#edf4fb", "#d3e4f3", "#b6cfe7", "#9ab6d9"], "accent": "#ff8a5c", "mech": "#ffcf70", "slide": "#f497b4", "bridge": "#a6e3b5", "door": "#e8798f" },
	{ "bg": ["#ffe9d6", "#d5b4a1"], "blocks": ["#fbeee0", "#f1d6bd", "#e3bb9b", "#cf9f82"], "accent": "#4bb3a8", "mech": "#88b6e8", "slide": "#e59ac0", "bridge": "#9ed9c4", "door": "#d9727f" },
	{ "bg": ["#e2f7f1", "#c3a9e6"], "blocks": ["#effaf4", "#d2efe2", "#b2dcd0", "#93c3c3"], "accent": "#ff7b9c", "mech": "#ffc46b", "slide": "#9b8fe3", "bridge": "#ffe08a", "door": "#ee8aa8" },
	{ "bg": ["#fff4e0", "#a6d1e6"], "blocks": ["#fff7e8", "#f6e3c2", "#e8cda0", "#d4b07f"], "accent": "#e8637a", "mech": "#6fc2b0", "slide": "#87a8ec", "bridge": "#b6e3a3", "door": "#e07b8c" },
	{ "bg": ["#f5e1da", "#8fb8c9"], "blocks": ["#f9ece4", "#ecd1c4", "#d9b2a5", "#bf9690"], "accent": "#ffb84d", "mech": "#74c0b9", "slide": "#ad9ce0", "bridge": "#a3d9b8", "door": "#e3869b" },
	{ "dark": true, "bg": ["#1f2a4a", "#5b4b8a"], "blocks": ["#f2e6ff", "#d7c4f2", "#b9a3e3", "#9a86cf"], "accent": "#ffd36e", "mech": "#6fe0d0", "slide": "#ff9bb3", "bridge": "#9af0c8", "door": "#ff8fa3" },
	{ "bg": ["#ffe0e9", "#ffd6a5"], "blocks": ["#fff1f4", "#fbd9e2", "#f2bccc", "#e19fb4"], "accent": "#4aa3df", "mech": "#7bd3b0", "slide": "#b29bf0", "bridge": "#a8e6cf", "door": "#e06c8a" },
	{ "bg": ["#ffdcc8", "#f5b8c9"], "blocks": ["#fff2e6", "#f7d5bf", "#eab7a3", "#d4968c"], "accent": "#4a9ee8", "mech": "#6bcbb8", "slide": "#9e8ee8", "bridge": "#a6dfa0", "door": "#e56f89" },
	{ "dark": true, "bg": ["#13243b", "#2b5876"], "blocks": ["#e6f8ff", "#bfe8f2", "#90d0df", "#6bb3c9"], "accent": "#62f2c8", "mech": "#ff96c5", "slide": "#ffd26f", "bridge": "#86f0a8", "door": "#ff7d95" },
	{ "bg": ["#ebe0ff", "#ffc8d6"], "blocks": ["#f8f2ff", "#e4d4f7", "#cbb4eb", "#b096d9"], "accent": "#ff7c6e", "mech": "#62cbb8", "slide": "#ffb85c", "bridge": "#9ae0b4", "door": "#e66c96" },
	{ "dark": true, "bg": ["#1b1834", "#463168"], "blocks": ["#fff3d6", "#ebd4a7", "#d4b37f", "#b89262"], "accent": "#ffb84d", "mech": "#6be0d6", "slide": "#ff8fb1", "bridge": "#9ae6a8", "door": "#ff708d" },
]

# ---------- durum ----------
var levels: Array = []
var L: PuzzleLogic
var state: Dictionary
var setup_state = null
var level_idx := 0
var pal: Dictionary
var mode := "edit"          # edit | running | paused | ended | won
var runner = null
var step_once = false
var speed_idx := 0
var end_reason := ""
var prog := {"main": [], "p1": [], "p2": []}
var active_row := "main"
var sel = null              # {row, idx}
var queue: Array = []
var anim = null
var displayed = null
var instant := false
var preview := false
var win_shown := false
var progress := {"unlocked": 1, "best": {}, "progs": {}, "seen": {}}
var time := 0.0

# ---------- sahne ----------
var world: Node3D
var level_root: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var bg_tex: GradientTexture2D
var objs := {}
var mat_cache := {}
var rbox_mesh: ArrayMesh
var crate_mesh: ArrayMesh
var cam_az := 45.0
var cam_az_cur := 45.0
var cam_zoom := 1.0
var cam_target := Vector3.ZERO
var cam_size := 12.0
var cam_spin := false
var ptr = null

# ---------- arayüz ----------
var ui: CanvasLayer
var hud: Control
var panel: PanelContainer
var palette_box: HFlowContainer
var rows_box: VBoxContainer
var sel_bar: HBoxContainer
var btn_cond: Button
var btn_run: Button
var btn_step: Button
var btn_stop: Button
var btn_speed: Button
var lbl_chap: Label
var lbl_name: Label
var lbl_blocks: Label
var lbl_status: Label
var lbl_toast: Label
var hint_panel: PanelContainer
var lbl_hint: Label
var scr_title: Control
var scr_levels: Control
var scr_win: Control
var scr_intro: Control
var scr_backup: Control
var levels_list: VBoxContainer
var lbl_win: Label
var lbl_stars: Label
var btn_next: Button
var lbl_intro_title: Label
var lbl_intro_text: RichTextLabel
var backup_edit: TextEdit
var toast_t := 0.0


# =====================================================================
func _ready() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	levels = JSON.parse_string(f.get_as_text())
	_load_progress()
	rbox_mesh = _rounded_box(Vector3.ONE, 0.08, 4)
	crate_mesh = _rounded_box(Vector3(0.84, 0.84, 0.84), 0.08, 3)
	_setup_world()
	_setup_ui()
	get_viewport().size_changed.connect(_on_resize)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		_autotest.call_deferred()
		return
	for a in args:
		if a.begins_with("--shot="):
			_shot.call_deferred(a.substr(7))
			return
	_show_title()


# ---------- kayıt ----------
func _load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
		if d is Dictionary:
			for k in d:
				progress[k] = d[k]
	progress["unlocked"] = int(progress.get("unlocked", 1))

func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))

func _export_code() -> String:
	return "KK1:" + Marshalls.utf8_to_base64(JSON.stringify(progress))

## Web sürümüyle aynı KK1 kodu; mevcut ilerlemeyle birleştirir, hiçbir şey kaybolmaz.
func _import_code(code: String) -> bool:
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	if not code.begins_with("KK1:"):
		return false
	var data = JSON.parse_string(Marshalls.base64_to_utf8(code.substr(4)))
	if not (data is Dictionary) or not data.has("unlocked"):
		return false
	progress["unlocked"] = mini(levels.size(), maxi(int(progress["unlocked"]), int(data["unlocked"])))
	var best: Dictionary = data.get("best", {})
	for k in best:
		var b = best[k]
		var cur = progress["best"].get(k)
		if b is Dictionary and b.has("blocks") and (cur == null or int(b["blocks"]) < int(cur["blocks"])):
			progress["best"][k] = {"blocks": int(b["blocks"]), "stars": clampi(int(b.get("stars", 1)), 1, 3)}
	var progs: Dictionary = data.get("progs", {})
	for k in progs:
		if not progress["progs"].has(k):
			progress["progs"][k] = progs[k]
	var seen: Dictionary = data.get("seen", {})
	for k in seen:
		progress["seen"][k] = 1
	_save_progress()
	return true


# =====================================================================
# Dünya: ışık, ortam, kamera
func _setup_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex = GradientTexture2D.new()
	bg_tex.gradient = Gradient.new()
	bg_tex.fill_from = Vector2(0, 0)
	bg_tex.fill_to = Vector2(0, 1)
	bg_tex.width = 8
	bg_tex.height = 256
	bg.texture = bg_tex
	bg_layer.add_child(bg)

	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4ecff")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.tonemap_white = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 2.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_energy = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 0.78
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-58, 32, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#c9d6ff")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -140, 0)
	add_child(fill)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 300.0
	add_child(cam)
	world = Node3D.new()
	add_child(world)


# ---------- geometri / malzeme ----------
## Yuvarlatılmış kutu: alt bölümlü bir kutunun köşelerini küreye yaklaştırır.
func _rounded_box(size: Vector3, r: float, seg: int) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = seg
	bm.subdivide_height = seg
	bm.subdivide_depth = seg
	var arr := bm.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var inner := size * 0.5 - Vector3(r, r, r)
	for i in verts.size():
		var p := verts[i]
		var c := p.clamp(-inner, inner)
		var d := p - c
		if d.length() > 0.00001:
			var n := d.normalized()
			verts[i] = c + n * r
			norms[i] = n
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _mat(color, opts := {}) -> StandardMaterial3D:
	var key := str(color) + str(opts)
	if mat_cache.has(key) and not opts.get("unique", false):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = opts.get("rough", 0.82)
	if opts.has("emit"):
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = opts["emit"]
	if opts.get("alpha", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if not opts.get("unique", false):
		mat_cache[key] = m
	return m

func _mesh(mesh: Mesh, material: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	(parent if parent else level_root).add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c

func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t

## Dokunulabilir alan (ışın testi için)
func _pick(parent: Node3D, size: Vector3, info: Dictionary, offset := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.position = offset
	body.set_meta("pick", info)
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sh.shape = bs
	body.add_child(sh)
	parent.add_child(body)

func _block_color(p: Vector3i) -> Color:
	var b: Array = pal["blocks"]
	var c := Color(b[((p.y - L.min_y) % b.size() + b.size()) % b.size()])
	if (p.x + p.z) % 2 == 0:
		c = c.lightened(0.04)
	return c


# =====================================================================
# Seviye kurulumu
func build_level(i: int, as_preview := false) -> void:
	level_idx = i
	preview = as_preview
	var def: Dictionary = levels[i]
	pal = PALETTES[int(def.get("palette", i)) % PALETTES.size()]
	var g := Gradient.new()
	g.set_color(0, Color(pal["bg"][0]))
	g.set_color(1, Color(pal["bg"][1]))
	bg_tex.gradient = g
	env.fog_light_color = Color(pal["bg"][1])
	env.ambient_light_color = Color("#3d3a66") if pal.get("dark", false) else Color("#f4ecff")
	if level_root:
		level_root.queue_free()
	level_root = Node3D.new()
	world.add_child(level_root)
	L = PuzzleLogic.new()
	L.load_level(def)
	state = L.initial_state()
	setup_state = null
	queue = []
	anim = null
	win_shown = false
	mode = "edit"
	runner = null
	objs = {"crates": [], "balls": [], "levers": [], "plates": [], "bridges": [], "rotators": [], "sliders": [],
		"crumbles": [], "links": [], "cranks": [], "portals": [], "trail": Node3D.new()}
	level_root.add_child(objs["trail"])
	# Not: GDScript lambdaları yerel değişkenleri kopyalar; sınır kutusu bir sözlükte tutulur.
	var bb := {"box": AABB(Vector3(L.start), Vector3.ZERO)}
	var grow := func(p: Vector3i): bb["box"] = bb["box"].expand(Vector3(p))
	# statik bloklar ve merdivenler
	for p in L.statics:
		var v: Dictionary = L.statics[p]
		grow.call(p)
		if v["t"] == "b":
			_mesh(rbox_mesh, _mat(_block_color(p)), Vector3(p))
			_add_window(p)
		else:
			var sg := Node3D.new()
			sg.position = Vector3(p)
			sg.rotation.y = [0.0, -PI / 2, PI, PI / 2][int(v["d"])]
			level_root.add_child(sg)
			var col := _block_color(p + Vector3i.UP)
			for k in 3:
				var h := (k + 1) / 3.0
				_mesh(_box(Vector3(1.0 / 3.0, h, 1.0)), _mat(col), Vector3(-1.0 / 3.0 + k / 3.0, -0.5 + h / 2.0, 0), sg)
	# köprüler / kapılar
	for bi in L.bridges.size():
		var b: Dictionary = L.bridges[bi]
		var ms := []
		for c in b["cells"]:
			grow.call(c)
			var m := _mesh(rbox_mesh, _mat(pal["door"] if b["door"] else pal["bridge"], {"alpha": true, "unique": true, "rough": 0.5}), Vector3(c))
			ms.append(m)
		objs["bridges"].append(ms)
	# döner platformlar
	for ri in L.rotators.size():
		var r: Dictionary = L.rotators[ri]
		var rg := Node3D.new()
		rg.position = Vector3(r["pivot"].x, 0, r["pivot"].y)
		level_root.add_child(rg)
		for b in r["blocks"]:
			grow.call(b)
			var local := Vector3(b.x - r["pivot"].x, b.y, b.z - r["pivot"].y)
			_mesh(rbox_mesh, _mat(pal["mech"]), local, rg)
			_mesh(_cyl(0.13, 0.13, 0.02), _mat("#ffffff", {"unshaded": true}), local + Vector3(0, 0.51, 0), rg)
			_pick(rg, Vector3.ONE, {"kind": "rot", "i": ri}, local)
			grow.call(Vector3i(r["pivot"].x + (b.z - r["pivot"].y), b.y, r["pivot"].y + (b.x - r["pivot"].x)))
			grow.call(Vector3i(r["pivot"].x - (b.z - r["pivot"].y), b.y, r["pivot"].y - (b.x - r["pivot"].x)))
		if not r["fixed"]:
			var hy: float = r["handle"].y if r["handle"] != null else r["blocks"][0].y - 1
			var hg := Node3D.new()
			hg.position = Vector3(0, hy + 0.15, 0)
			rg.add_child(hg)
			_mesh(_torus(0.86, 1.04), _mat(pal["accent"]), Vector3.ZERO, hg)
			for k in 2:
				var sp := _mesh(_box(Vector3(1.9, 0.08, 0.1)), _mat(pal["accent"]), Vector3.ZERO, hg)
				sp.rotation.y = k * PI / 2
			for k in 4:
				_mesh(_sphere(0.14), _mat("#fff6e8"), Vector3(cos(k * PI / 2) * 0.95, 0, sin(k * PI / 2) * 0.95), hg)
			_mesh(_cyl(0.1, 0.1, absf(r["blocks"][0].y - hy) + 0.2), _mat("#b8aecb"), Vector3(0, (r["blocks"][0].y - hy) / 2.0 - 0.15, 0), hg)
			_pick(hg, Vector3(2.2, 0.4, 2.2), {"kind": "handle", "i": ri})
		objs["rotators"].append(rg)
	# çarklar
	for ci in L.cranks.size():
		var ck: Dictionary = L.cranks[ci]
		var cg := Node3D.new()
		cg.position = Vector3(ck["p"]) + Vector3(0, -0.5, 0)
		level_root.add_child(cg)
		_mesh(_cyl(0.3, 0.36, 0.14), _mat("#8a7fa3"), Vector3(0, 0.07, 0), cg)
		_mesh(_cyl(0.07, 0.07, 0.42), _mat("#d8d0e6"), Vector3(0, 0.33, 0), cg)
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.56, 0)
		cg.add_child(wheel)
		_mesh(_torus(0.25, 0.35), _mat(pal["mech"]), Vector3.ZERO, wheel)
		for k in 3:
			var sp := _mesh(_box(Vector3(0.6, 0.05, 0.06)), _mat(pal["mech"]), Vector3.ZERO, wheel)
			sp.rotation.y = k * PI / 3
		_mesh(_sphere(0.08), _mat(pal["accent"]), Vector3(0.3, 0.07, 0), wheel)
		objs["cranks"].append(wheel)
	# kaydırıcılar
	for si in L.sliders.size():
		var s: Dictionary = L.sliders[si]
		var sg := Node3D.new()
		level_root.add_child(sg)
		var col = pal["slide"] if L.is_manual(si) else pal["mech"]
		for b in s["blocks"]:
			grow.call(b)
			grow.call(b + s["axis"] * s["max"])
			grow.call(b + s["axis"] * s["min"])
			_mesh(rbox_mesh, _mat(col), Vector3(b), sg)
			_mesh(_box(Vector3(1.01, 0.12, 1.01)), _mat("#ffffff", {"rough": 0.5}), Vector3(b) + Vector3(0, 0.25, 0), sg)
			_pick(sg, Vector3.ONE, {"kind": "slide", "i": si}, Vector3(b))
		if L.is_manual(si):
			for sgn in [-1, 1]:
				var ax: Vector3 = Vector3(s["axis"]) * sgn
				var best: Vector3i = s["blocks"][0]
				for b in s["blocks"]:
					if Vector3(b).dot(ax) > Vector3(best).dot(ax):
						best = b
				var pos: Vector3 = Vector3(best) + ax * 0.85
				if s["axis"].y != 0:
					pos = Vector3(best) + Vector3(0, 0, 0.75) + ax * 0.0
				var cone := _mesh(_cyl(0.0, 0.22, 0.45), _mat(pal["accent"]), pos, sg)
				cone.quaternion = Quaternion(Vector3.UP, ax.normalized())
				_pick(sg, Vector3(0.6, 0.6, 0.6), {"kind": "sarrow", "i": si, "s": sgn}, pos)
		objs["sliders"].append(sg)
	# çöken taşlar
	for c in L.crumbles:
		grow.call(c)
		objs["crumbles"].append(_mesh(rbox_mesh, _mat("#e2cfb2", {"rough": 0.95}), Vector3(c)))
	# plakalar
	for pl in L.plates:
		var m := _mesh(_cyl(0.36, 0.4, 0.08), _mat(pal["mech"], {"emit": 0.0, "unique": true, "rough": 0.4}), Vector3(pl["p"]) + Vector3(0, -0.46, 0))
		objs["plates"].append(m)
	# kollar
	for lv in L.levers:
		var lg := Node3D.new()
		lg.position = Vector3(lv["p"]) + Vector3(0, -0.5, 0)
		level_root.add_child(lg)
		_mesh(_box(Vector3(0.6, 0.18, 0.4)), _mat("#8a7fa3"), Vector3(0, 0.09, 0), lg)
		var arm := Node3D.new()
		arm.position = Vector3(0, 0.16, 0)
		lg.add_child(arm)
		_mesh(_cyl(0.04, 0.04, 0.55), _mat("#d8d0e6"), Vector3(0, 0.27, 0), arm)
		_mesh(_sphere(0.11), _mat(pal["accent"]), Vector3(0, 0.56, 0), arm)
		objs["levers"].append(arm)
	# göz yanılması halkaları
	for ln in L.links:
		for c in [ln["a"], ln["b"]]:
			var m := _mesh(_torus(0.22, 0.34), _mat(pal["accent"], {"alpha": true, "unique": true, "unshaded": true}), Vector3(c) + Vector3(0, -0.47, 0))
			m.scale = Vector3(1, 0.15, 1)
			objs["links"].append({"m": m, "view": ln["view"]})
	# ışınlayıcılar
	var pcols := ["#5ef0ff", "#c58bff", "#7dffb0", "#ffd36e"]
	for pi in L.portals.size():
		var pt: Dictionary = L.portals[pi]
		for c in [pt["a"], pt["b"]]:
			var col: String = pcols[pi % pcols.size()]
			var m := _mesh(_torus(0.26, 0.38), _mat(col, {"emit": 2.2, "unshaded": true}), Vector3(c) + Vector3(0, -0.46, 0))
			m.scale = Vector3(1, 0.2, 1)
			var beam := _mesh(_cyl(0.3, 0.34, 1.2), _mat(col, {"alpha": true, "unique": true, "unshaded": true}), Vector3(c) + Vector3(0, 0.12, 0))
			beam.material_override.albedo_color.a = 0.18
			objs["portals"].append({"ring": m, "beam": beam})
	# hedef kristal
	var gp := Vector3(L.goal)
	grow.call(L.goal)
	var gem := _mesh(_gem_mesh(), _mat(pal["accent"], {"emit": 5.0, "rough": 0.2}), gp + Vector3(0, 0.1, 0))
	gem.scale = Vector3(1, 1.35, 1)
	var ring := _mesh(_torus(0.28, 0.42), _mat("#ffffff", {"alpha": true, "unique": true, "unshaded": true}), gp + Vector3(0, -0.47, 0))
	ring.scale = Vector3(1, 0.1, 1)
	ring.material_override.albedo_color.a = 0.8
	var beam := _mesh(_cyl(0.12, 0.26, 3.2), _mat(pal["accent"], {"alpha": true, "unique": true, "unshaded": true}), gp + Vector3(0, 1.1, 0))
	beam.material_override.albedo_color.a = 0.22
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objs["gem"] = gem
	objs["goal_ring"] = ring
	# varlıklar
	for c in state["crates"]:
		var m := _mesh(crate_mesh, _mat("#d9a066", {"alpha": true, "unique": true}))
		_mesh(_box(Vector3(0.7, 0.08, 0.86)), _mat("#a8703f"), Vector3(0, 0.25, 0), m)
		_mesh(_box(Vector3(0.7, 0.08, 0.86)), _mat("#a8703f"), Vector3(0, -0.25, 0), m)
		objs["crates"].append(m)
	for b in state["balls"]:
		var m := _mesh(_sphere(0.36), _mat("#f4f1ff", {"alpha": true, "unique": true, "rough": 0.35}))
		_mesh(_torus(0.33, 0.37), _mat("#ff7f88"), Vector3.ZERO, m)
		objs["balls"].append(m)
	objs["player"] = _make_robot()
	level_root.add_child(objs["player"])
	var aabb: AABB = bb["box"]
	_build_clouds(aabb)
	# kamera
	cam_target = aabb.get_center()
	var sz := aabb.size
	cam_size = maxf(9.0, (maxf(sz.x, sz.z) * 0.62 + sz.y * 0.45) * 1.2 + 3.2)
	cam_az = 45.0 + 90.0 * state["view"]
	cam_az_cur = cam_az + 30.0
	cam_zoom = 1.0
	displayed = state
	_apply_visual(state, state, 1.0)
	_on_resize()

func _gem_mesh() -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	s.radial_segments = 4
	s.rings = 1
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s.surface_get_arrays(0))
	return m

## Kule duvarlarına Monument Valley tarzı kemerli pencereler
func _add_window(p: Vector3i) -> void:
	if not L.statics.has(p + Vector3i.UP):
		return
	for di in 4:
		var d: Vector3i = DIRS[di]
		if L.statics.has(p + d):
			continue
		var h := absi((p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791) ^ (di * 2654435761)) % 97
		if h % 3 != 0:
			continue
		var w := Node3D.new()
		w.position = Vector3(p) + Vector3(d) * 0.505
		w.rotation.y = atan2(d.x, d.z)
		level_root.add_child(w)
		var dark := _mat("#5a4a86", {"alpha": true})
		dark.albedo_color.a = 0.45
		_mesh(_box(Vector3(0.26, 0.34, 0.01)), dark, Vector3(0, -0.12, 0), w)
		var top := _mesh(_cyl(0.13, 0.13, 0.01), dark, Vector3(0, 0.05, 0), w)
		top.rotation.x = PI / 2

func _build_clouds(aabb: AABB) -> void:
	var c := aabb.get_center()
	var radius := maxf(aabb.size.x, aabb.size.z) * 0.8 + 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cm := _mat("#ffffff", {"alpha": true, "rough": 1.0})
	cm.albedo_color = Color("#8f88c4") if pal.get("dark", false) else Color("#ffffff")
	cm.albedo_color.a = 0.4 if pal.get("dark", false) else 0.6
	for i in 12:
		var g := Node3D.new()
		var a := i / 12.0 * TAU + rng.randf() * 0.3
		var r := radius * (0.9 + rng.randf() * 0.8)
		g.position = Vector3(c.x + cos(a) * r, L.min_y - 6.0 - rng.randf() * 3.0, c.z + sin(a) * r)
		level_root.add_child(g)
		for k in 3 + rng.randi() % 3:
			var m := _mesh(_sphere(1.0), cm, Vector3((k - 2) * 1.3 + rng.randf(), rng.randf() * 0.6, rng.randf() * 1.2), g)
			var scl := 0.6 + rng.randf() * 0.8
			m.scale = Vector3(scl * 1.4, scl * 0.8, scl)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_robot() -> Node3D:
	var g := Node3D.new()
	var body := _mesh(_rounded_box(Vector3(0.46, 0.42, 0.4), 0.1, 3), _mat("#fffaf2"), Vector3(0, 0.33, 0), g)
	_mesh(_box(Vector3(0.36, 0.22, 0.04)), _mat("#3b3555", {"rough": 0.4}), Vector3(0, 0.04, 0.2), body)
	var eyes := Node3D.new()
	eyes.position = Vector3(0, 0.05, 0.225)
	body.add_child(eyes)
	for x in [-0.08, 0.08]:
		_mesh(_sphere(0.035), _mat("#7ff3ff", {"emit": 3.0, "unshaded": true}), Vector3(x, 0, 0), eyes)
	_mesh(_cyl(0.015, 0.015, 0.16), _mat("#8a8299"), Vector3(0, 0.62, 0), g)
	var bulb_mat := _mat(pal["accent"], {"emit": 3.0, "unique": true})
	_mesh(_sphere(0.05), bulb_mat, Vector3(0, 0.72, 0), g)
	for x in [-0.12, 0.12]:
		_mesh(_box(Vector3(0.12, 0.1, 0.18)), _mat("#8a8299"), Vector3(x, 0.06, 0.02), g)
	for x in [-0.27, 0.27]:
		var cap := CapsuleMesh.new()
		cap.radius = 0.04
		cap.height = 0.22
		_mesh(cap, _mat(pal["accent"]), Vector3(x, 0.3, 0), g)
	# yön oku ve halka
	var arrow := _mesh(_cyl(0.0, 0.16, 0.02), _mat("#ffffff", {"unshaded": true, "alpha": true, "unique": true}), Vector3(0, 0.03, 0.5), g)
	arrow.rotation.x = PI / 2
	arrow.scale = Vector3(1, 1, 0.12)
	var ring := _mesh(_torus(0.34, 0.4), _mat("#ffffff", {"unshaded": true, "alpha": true, "unique": true}), Vector3(0, 0.02, 0), g)
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override.albedo_color.a = 0.55
	g.set_meta("body", body)
	g.set_meta("eyes", eyes)
	g.set_meta("bulb", bulb_mat)
	g.set_meta("arrow", arrow)
	g.set_meta("ring", ring)
	return g


# =====================================================================
# Görsel interpolasyon
static func _ease(t: float) -> float:
	return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2

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

func _jumpy(a, b, sA: Dictionary, sB: Dictionary) -> bool:
	return a != null and b != null and absi(a.x - b.x) + absi(a.z - b.z) + absi(a.y - b.y) > 1 and sA["rots"] == sB["rots"] and sA["slides"] == sB["slides"]

func _apply_visual(sA: Dictionary, sB: Dictionary, t: float, bump := false) -> void:
	var te := _ease(t)
	var pl: Node3D = objs["player"]
	var pa = null if sA["dead"] else sA["p"]
	var pb = null if sB["dead"] else sB["p"]
	if _jumpy(pa, pb, sA, sB):
		# ışınlanma / göz yanılması: küçülüp öbür uçta belirir
		var pp: Vector3i = pa if t < 0.5 else pb
		pl.visible = true
		pl.position = Vector3(pp) + Vector3(0, -0.5, 0)
		pl.scale = Vector3.ONE * maxf(0.05, absf(1 - 2 * t))
	else:
		pl.scale = Vector3.ONE
		var p = _entity_pos(pa, pb, t if sB["dead"] else te, sA, sB)
		pl.visible = p != null
		if p != null:
			pl.position = p
			var carried: bool = sA["rots"] != sB["rots"] or sA["slides"] != sB["slides"]
			if pa != null and pb != null and pa != pb and not carried:
				pl.position.y += sin(PI * t) * (0.3 if pa.y != pb.y else 0.14)
	if bump:
		var dv := Vector3(DIRS[sB["f"]])
		pl.position += dv * sin(PI * t) * 0.17
	var fa := Vector3(DIRS[sA["f"]])
	var fb := Vector3(DIRS[sB["f"]])
	var from := atan2(fa.x, fa.z)
	var diff := wrapf(atan2(fb.x, fb.z) - from, -PI, PI)
	pl.rotation.y = from + diff * te
	for i in objs["crates"].size():
		var m: MeshInstance3D = objs["crates"][i]
		var a = sA["crates"][i]
		var b = sB["crates"][i]
		if _jumpy(a, b, sA, sB):
			m.position = Vector3(a if t < 0.5 else b) + Vector3(0, -0.08, 0)
			m.scale = Vector3.ONE * maxf(0.05, absf(1 - 2 * t))
			continue
		m.scale = Vector3.ONE
		var p = _entity_pos(a, b, te, sA, sB)
		m.visible = p != null
		if p != null:
			m.position = p + Vector3(0, 0.42, 0)
		m.material_override.albedo_color.a = 1.0 if b != null else 1.0 - t
	for i in objs["balls"].size():
		var m: MeshInstance3D = objs["balls"][i]
		var a = sA["balls"][i]["p"] if sA["balls"][i] != null else null
		var b = sB["balls"][i]["p"] if sB["balls"][i] != null else null
		var p = _entity_pos(a, b, t, sA, sB)
		m.visible = p != null
		if p != null:
			m.position = p + Vector3(0, 0.36, 0)
			if a != null and b != null and a != b:
				m.rotate(Vector3(b.z - a.z, 0, -(b.x - a.x)).normalized(), 0.15)
	for i in objs["rotators"].size():
		var d := _rot_delta(sA["rots"][i], sB["rots"][i])
		objs["rotators"][i].rotation.y = (sA["rots"][i] + d * te) * PI / 2
	for i in objs["cranks"].size():
		var r: int = L.cranks[i]["rot"]
		var d := _rot_delta(sA["rots"][r], sB["rots"][r])
		objs["cranks"][i].rotation.y = (sA["rots"][r] + d * te) * PI
	for i in objs["sliders"].size():
		var v := lerpf(sA["slides"][i], sB["slides"][i], te)
		objs["sliders"][i].position = Vector3(L.sliders[i]["axis"]) * v
	for i in objs["bridges"].size():
		var v := lerpf(1.0 if sA["bridges"][i] else 0.0, 1.0 if sB["bridges"][i] else 0.0, te)
		for m in objs["bridges"][i]:
			m.material_override.albedo_color.a = 0.16 + 0.84 * v
			m.scale = Vector3.ONE * (0.86 + 0.14 * v)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if v > 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in objs["crumbles"].size():
		objs["crumbles"][i].visible = sB["crumbles"][i] == 0
	for i in objs["levers"].size():
		objs["levers"][i].rotation.z = lerpf(0.6 if sA["levers"][i] else -0.6, 0.6 if sB["levers"][i] else -0.6, te)
	for i in objs["plates"].size():
		var down := _plate_down(sB, L.plates[i]["p"])
		objs["plates"][i].material_override.emission_energy_multiplier = 1.6 if down else 0.0
		objs["plates"][i].material_override.emission_enabled = down
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


# =====================================================================
# Animasyon kuyruğu ve yorumlayıcı sürücüsü
func _speed() -> float:
	return SPEEDS[speed_idx] if mode == "running" or mode == "paused" else 1.0

func _frame_dur(a: Dictionary, b: Dictionary, first: bool, kind: String) -> float:
	if instant:
		return 0.0
	var d := 0.1
	if first:
		d = {"F": 0.34, "J": 0.4, "L": 0.22, "R": 0.22, "A": 0.3, "rot": 0.42, "slide": 0.26, "view": 0.0, "bump": 0.26}.get(kind, 0.3)
		if kind == "A" and a["rots"] != b["rots"]:
			d = 0.5
	elif _jumpy(a["p"], b["p"], a, b):
		d = 0.5
	elif a["slides"] != b["slides"]:
		d = 0.24
	elif a["bridges"] != b["bridges"]:
		d = 0.22
	return d / _speed()

func _enqueue(frames: Array, kind: String, bump := false) -> void:
	var prev = queue[queue.size() - 1]["to"] if queue.size() > 0 else (anim["to"] if anim != null else displayed)
	for k in frames.size():
		var f: Dictionary = frames[k]
		queue.append({"from": prev, "to": f, "dur": _frame_dur(prev, f, k == 0, kind), "t": 0.0, "bump": bump and k == 0})
		prev = f

func _update_queue(dt: float) -> void:
	for guard in 4000:
		if anim == null:
			if queue.is_empty():
				if mode == "running" and displayed == state:
					if not _tick():
						return
					continue
				return
			anim = queue.pop_front()
		anim["t"] += dt / anim["dur"] if anim["dur"] > 0 else 1.0
		dt = 0.0
		if anim["t"] >= 1.0:
			_apply_visual(anim["from"], anim["to"], 1.0)
			displayed = anim["to"]
			anim = null
			if not instant and queue.size() > 0:
				return
		else:
			_apply_visual(anim["from"], anim["to"], anim["t"], anim["bump"])
			return

func _tick() -> bool:
	if L.is_win(state):
		_on_win()
		return false
	if state["dead"]:
		_end_run("dead")
		return false
	if str(step_once) == "done":
		step_once = false
		_set_mode("paused", true)
		return false
	var n = runner.next(L, state)
	_mark_exec(n, runner.skipped)
	if n == null:
		_end_run(runner.error if runner.error != "" else "end")
		return false
	var r := Program.cmd_step(L, state, n["ins"]["c"])
	if str(step_once) == "true":
		step_once = "done"
	if r["pause"]:
		step_once = false
		_set_mode("paused")
		return false
	if r["bump"]:
		_enqueue([state], "bump", true)
		return true
	if n["ins"]["c"] in ["F", "J"] and not instant:
		var dot := _mesh(_cyl(0.11, 0.11, 0.01), _mat(pal["accent"], {"unshaded": true}), Vector3(state["p"]) + Vector3(0, -0.47, 0), objs["trail"])
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	state = r["state"]
	_enqueue(r["frames"], n["ins"]["c"])
	return true

func _start_run(step := false) -> void:
	if Program.block_count(prog) == 0:
		_toast("Önce programa blok ekle")
		return
	if mode == "ended":
		_reset_to_setup()
	sel = null
	setup_state = PuzzleLogic.clone(state)
	runner = Program.Runner.new(Program.parse_program(Program.program_to_src(prog)))
	for c in objs["trail"].get_children():
		c.queue_free()
	step_once = "true" if step else false
	hint_panel.visible = false
	_set_mode("running")
	_render_rows()

func _run_toggle() -> void:
	if win_shown:
		return
	if mode == "edit" or mode == "ended":
		_start_run(false)
	elif mode == "running":
		step_once = false
		_set_mode("paused", true)
	elif mode == "paused":
		step_once = false
		_set_mode("running")

func _step_btn() -> void:
	if win_shown:
		return
	if mode == "edit" or mode == "ended":
		_start_run(true)
	elif mode == "paused":
		step_once = "true"
		_set_mode("running")
	elif mode == "running":
		step_once = "done"

func _reset_to_setup() -> void:
	if setup_state == null:
		return
	queue = []
	anim = null
	state = setup_state
	setup_state = null
	displayed = state
	runner = null
	_apply_visual(state, state, 1.0)
	_sync_view()
	for c in objs["trail"].get_children():
		c.queue_free()
	_set_mode("edit")

func _end_run(reason: String) -> void:
	end_reason = reason
	_set_mode("ended")

func _set_mode(m: String, quiet := false) -> void:
	mode = m
	btn_run.text = {"running": "❚❚  Duraklat", "paused": "▶  Devam"}.get(m, "▶  Çalıştır")
	_style_button(btn_run, "#f5a524" if m == "running" else "#2fb36f", 20)
	lbl_status.visible = m == "paused" or m == "ended"
	if m == "paused":
		lbl_status.text = "Adım adım: ⏭ sonraki komut, ▶ devam" if quiet else "Mola — platformları çevir, kamerayı döndür, sonra ▶"
	elif m == "ended":
		lbl_status.text = {
			"end": "Program bitti ama Robo kristale ulaşmadı.",
			"dead": "Robo düştü! Programı düzenle ve tekrar dene.",
			"limit": "Robo yoruldu: %d komut sınırı aşıldı." % Program.MAX_STEPS,
			"depth": "Çok fazla iç içe fonksiyon çağrısı.",
			"loop": "Program boş bir döngüde dönüp duruyor.",
		}.get(end_reason, "Program durdu.")
	if objs.has("player"):
		var pl: Node3D = objs["player"]
		pl.get_meta("arrow").visible = m != "running"
		pl.get_meta("ring").visible = m != "running"
		var col: String = {"running": "#57e39a", "paused": "#ffd36e", "ended": "#ff6b7a"}.get(m, pal["accent"])
		var bm: StandardMaterial3D = pl.get_meta("bulb")
		bm.albedo_color = Color(col)
		bm.emission = Color(col)
	if m == "edit":
		_mark_exec(null, [])
	_update_hud()
	_render_rows()


# =====================================================================
# Dünya işlemleri (oyuncunun eli)
func _can_edit_world() -> bool:
	if win_shown or preview:
		return false
	if mode == "ended":
		_reset_to_setup()
	if mode == "running":
		_toast("Program çalışıyor — dünyayı değiştirmek için duraklat")
		return false
	return true

func _world_op(op: Dictionary) -> bool:
	if not _can_edit_world():
		return false
	if (anim != null or queue.size() > 0) and op["t"] != "view":
		return false
	if op["t"] == "rot" and L.rotators[int(op["i"])]["fixed"]:
		_toast("Bu platform yalnızca çarkla döner — Robo'ya Kullan dedir")
		return false
	var r := Program.world_op(L, state, op)
	if not r["ok"]:
		return false
	state = r["state"]
	var frames: Array = r["frames"]
	frames[frames.size() - 1] = state
	_enqueue(frames, op["t"])
	return true

func _rotate_view(s: int) -> bool:
	if preview:
		return false
	if mode == "running":
		_toast("Program çalışırken bakış açısı kilitli — Mola ver")
		return false
	if _world_op({"t": "view", "s": s}):
		cam_az += 90.0 * s
		return true
	return false

func _sync_view() -> void:
	var want: float = 45.0 + 90.0 * state["view"]
	cam_az += wrapf(want - cam_az, -180.0, 180.0)

func _reset_world() -> void:
	if preview or L == null:
		return
	if mode != "edit":
		_reset_to_setup()
	queue = []
	anim = null
	state = L.initial_state()
	displayed = state
	_apply_visual(state, state, 1.0)
	_sync_view()


# =====================================================================
# Kazanma
func _stars_for(blocks: int, par: int) -> int:
	return 3 if blocks <= par else (2 if blocks <= par + 3 else 1)

func _on_win() -> void:
	if win_shown:
		return
	win_shown = true
	mode = "won"
	_mark_exec(null, [])
	var blocks := Program.block_count(prog)
	var par := int(levels[level_idx]["par"])
	var stars := _stars_for(blocks, par)
	var key := str(level_idx)
	var prev = progress["best"].get(key)
	if prev == null or blocks < int(prev["blocks"]):
		progress["best"][key] = {"blocks": blocks, "stars": stars}
	progress["unlocked"] = maxi(int(progress["unlocked"]), mini(levels.size(), level_idx + 2))
	progress["progs"][key] = Program.program_to_src(prog)
	_save_progress()
	if not instant:
		_confetti(Vector3(L.goal))
	lbl_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	var txt := "%d blokla çözdün · par %d" % [blocks, par]
	if blocks < par:
		txt += "\nPar'dan da kısa — usta programcı!"
	elif stars < 3:
		txt += "\n3 yıldız için en fazla %d blok kullan." % par
	lbl_win.text = txt
	btn_next.visible = level_idx < levels.size() - 1
	if instant:
		_show("win")
	else:
		get_tree().create_timer(1.3).timeout.connect(func(): if win_shown: _show("win"))

func _confetti(at: Vector3) -> void:
	var cols := [pal["accent"], pal["mech"], pal["slide"], pal["bridge"], "#ffffff"]
	for i in 40:
		var rb := RigidBody3D.new()
		rb.position = at + Vector3(0, 0.3, 0)
		var sh := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * 0.14
		sh.shape = bs
		rb.add_child(sh)
		var m := MeshInstance3D.new()
		m.mesh = _box(Vector3.ONE * 0.14)
		m.material_override = _mat(cols[i % cols.size()], {"emit": 0.6})
		rb.add_child(m)
		level_root.add_child(rb)
		var a := randf() * TAU
		var sp := 2.0 + randf() * 3.0
		rb.linear_velocity = Vector3(cos(a) * sp, 6.0 + randf() * 5.0, sin(a) * sp)
		rb.angular_velocity = Vector3(randf() * 6 - 3, randf() * 6 - 3, randf() * 6 - 3)
		get_tree().create_timer(3.5).timeout.connect(rb.queue_free)


# =====================================================================
# Döngü, kamera, giriş
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	time += dt
	if cam_spin:
		cam_az += dt * 7.0
	cam_az_cur += (cam_az - cam_az_cur) * minf(1.0, dt * 8.0)
	var a := deg_to_rad(cam_az_cur)
	cam.position = cam_target + Vector3(cos(EL) * cos(a), sin(EL), cos(EL) * sin(a)) * 60.0
	cam.look_at(cam_target, Vector3.UP)
	cam.size = lerpf(cam.size, cam_size / cam_zoom, minf(1.0, dt * 8.0))
	_update_offset()
	if L != null and objs.has("player"):
		_update_queue(dt)
		var gem: MeshInstance3D = objs["gem"]
		gem.rotation.y = time * 1.6
		gem.position.y = L.goal.y + 0.1 + sin(time * 2.4) * 0.07
		objs["goal_ring"].scale = Vector3(1, 0.1, 1) * (1.0 + sin(time * 3.0) * 0.08)
		var pl: Node3D = objs["player"]
		pl.get_meta("body").position.y = 0.33 + sin(time * 4.0) * 0.012
		pl.get_meta("eyes").scale.y = 0.15 if fmod(time, 3.7) < 0.12 else 1.0
		for p in objs["portals"]:
			p["ring"].rotation.y = time * 1.4
	if toast_t > 0:
		toast_t -= dt
		lbl_toast.visible = toast_t > 0

func _update_offset() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0:
		return
	var px := (PANEL_W + 20.0) * 0.5 if hud.visible else 0.0
	cam.h_offset = px * cam.size / vs.y

func _on_resize() -> void:
	pass

func _unhandled_input(ev: InputEvent) -> void:
	if preview or L == null or not hud.visible:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom * 1.1, 0.5, 2.5)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom / 1.1, 0.5, 2.5)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				ptr = {"pos": ev.position, "moved": false, "drag": 0.0}
			elif ptr != null:
				if not ptr["moved"]:
					_click(ev.position)
				else:
					var steps := roundi(ptr["drag"] / 90.0)
					cam_az -= ptr["drag"]
					if steps != 0 and not _rotate_view(steps):
						pass
				ptr = null
	elif ev is InputEventMouseMotion and ptr != null:
		var d: Vector2 = ev.position - ptr["pos"]
		if not ptr["moved"] and d.length() > 12:
			ptr["moved"] = true
		if ptr["moved"]:
			var nd := d.x * 0.35
			cam_az += nd - ptr["drag"]
			ptr["drag"] = nd
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE: _run_toggle()
			KEY_N: _step_btn()
			KEY_S, KEY_ESCAPE: _reset_to_setup()
			KEY_Q: _rotate_view(-1)
			KEY_E: _rotate_view(1)
			KEY_UP: _insert("F")
			KEY_LEFT: _insert("L")
			KEY_RIGHT: _insert("R")
			KEY_BACKSPACE:
				if sel != null:
					_delete_sel()

func _click(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var to := from + cam.project_ray_normal(pos) * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit["collider"].has_meta("pick"):
		return
	var info: Dictionary = hit["collider"].get_meta("pick")
	match info["kind"]:
		"handle": _world_op({"t": "rot", "i": info["i"], "s": 1})
		"rot":
			if L.rotators[info["i"]]["fixed"]:
				_toast("Bu platform yalnızca çarkla döner")
			else:
				_world_op({"t": "rot", "i": info["i"], "s": 1})
		"sarrow": _world_op({"t": "slide", "i": info["i"], "s": info["s"]})
		"slide": _toast("Kaydırmak için ok konilerine dokun")


# =====================================================================
# Arayüz
func _style_button(b: Button, color: String, radius := 14, font_color := "#ffffff") -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var c := Color(color)
		if st == "hover":
			c = c.lightened(0.08)
		elif st == "pressed":
			c = c.darkened(0.12)
		elif st == "disabled":
			c.a = 0.4
		sb.bg_color = c
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if st != "pressed":
			sb.shadow_color = Color(0, 0, 0, 0.12)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(0, 3)
		if st == "focus":
			sb.draw_center = false
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, Color(font_color))

func _btn(text: String, color := "#ffffff", fc := "#3f3656", size := 18, cb = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	_style_button(b, color, 14, fc)
	if cb != null:
		b.pressed.connect(cb)
	return b

func _card(color := Color(1, 1, 1, 0.92), radius := 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_color = Color(0.25, 0.2, 0.35, 0.2)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _label(text: String, size := 18, color := "#3f3656") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(color))
	return l

func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(1, 1, 1, 0.12)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	ui.add_child(c)
	return c

func _center(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	cc.add_child(child)

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	# üst çubuk
	var top := HBoxContainer.new()
	top.position = Vector2(14, 12)
	top.add_theme_constant_override("separation", 12)
	hud.add_child(top)
	top.add_child(_btn("☰", "#ffffffcc", "#3f3656", 22, _open_levels))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	lbl_chap = _label("", 12, "#6f6687")
	lbl_name = _label("", 22)
	tv.add_child(lbl_chap)
	tv.add_child(lbl_name)
	top.add_child(tv)
	lbl_blocks = _label("", 16)
	var bc := _card(Color(1, 1, 1, 0.75), 14)
	bc.add_child(lbl_blocks)
	top.add_child(bc)
	# sol alt: kamera ve yardımcılar
	var side := HBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	side.position = Vector2(14, -66)
	side.add_theme_constant_override("separation", 8)
	hud.add_child(side)
	side.add_child(_btn("⟲ Kamera", "#ffffffcc", "#3f3656", 16, func(): _rotate_view(-1)))
	side.add_child(_btn("Kamera ⟳", "#ffffffcc", "#3f3656", 16, func(): _rotate_view(1)))
	side.add_child(_btn("İpucu", "#ffffffcc", "#3f3656", 16, func(): hint_panel.visible = not hint_panel.visible))
	side.add_child(_btn("Dünyayı sıfırla", "#ffffffcc", "#3f3656", 16, _reset_world))
	# program paneli (sağ)
	panel = _card(Color(1, 1, 1, 0.82), 26)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W - 10
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	hud.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	palette_box = HFlowContainer.new()
	palette_box.add_theme_constant_override("h_separation", 6)
	palette_box.add_theme_constant_override("v_separation", 6)
	pv.add_child(palette_box)
	pv.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(sc)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 8)
	sc.add_child(rows_box)
	sel_bar = HBoxContainer.new()
	sel_bar.add_theme_constant_override("separation", 6)
	sel_bar.add_child(_btn("◀", "#f3effa", "#3f3656", 18, func(): _move_sel(-1)))
	btn_cond = _btn("Her zaman", "#f3effa", "#3f3656", 15, _cycle_cond)
	btn_cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_bar.add_child(btn_cond)
	sel_bar.add_child(_btn("▶", "#f3effa", "#3f3656", 18, func(): _move_sel(1)))
	sel_bar.add_child(_btn("Sil", "#ffe3e6", "#d8435c", 16, _delete_sel))
	sel_bar.visible = false
	pv.add_child(sel_bar)
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 8)
	pv.add_child(ctl)
	ctl.add_child(_btn("Temizle", "#ffffff", "#3f3656", 15, _clear_prog))
	btn_stop = _btn("■", "#ffffff", "#3f3656", 18, _reset_to_setup)
	ctl.add_child(btn_stop)
	btn_step = _btn("⏭", "#ffffff", "#3f3656", 18, _step_btn)
	ctl.add_child(btn_step)
	btn_run = _btn("▶  Çalıştır", "#2fb36f", "#ffffff", 20, _run_toggle)
	btn_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.add_child(btn_run)
	btn_speed = _btn("1×", "#ffffff", "#3f3656", 16, _cycle_speed)
	ctl.add_child(btn_speed)
	# durum, ipucu, toast
	lbl_status = _label("", 16, "#ffffff")
	var stc := _card(Color("#e8648ae6"), 14)
	stc.add_child(lbl_status)
	stc.position = Vector2(20, 84)
	hud.add_child(stc)
	lbl_status.visibility_changed.connect(func(): stc.visible = lbl_status.visible)
	lbl_status.visible = false
	stc.visible = false
	hint_panel = _card(Color(1, 1, 1, 0.95), 18)
	lbl_hint = _label("", 17)
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.custom_minimum_size = Vector2(460, 0)
	hint_panel.add_child(lbl_hint)
	hint_panel.position = Vector2(20, 84)
	hint_panel.visible = false
	hud.add_child(hint_panel)
	lbl_toast = _label("", 18, "#ffffff")
	var tc := _card(Color("#3f3656e6"), 16)
	tc.add_child(lbl_toast)
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(300, 260)
	hud.add_child(tc)
	lbl_toast.visibility_changed.connect(func(): tc.visible = lbl_toast.visible)
	lbl_toast.visible = false
	tc.visible = false
	_build_screens()

func _build_screens() -> void:
	# başlık
	scr_title = _screen()
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 14)
	var logo := _label("Kayıp Kuleler", 72, "#c46ad8")
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	logo.add_theme_constant_override("outline_size", 14)
	tv.add_child(logo)
	var sub := _label("Robo'yu programla. Dünyayı döndür.\nİmkânsız kulelerin tepesindeki kristallere ulaş.", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	sub.add_theme_constant_override("outline_size", 8)
	tv.add_child(sub)
	var play := _btn("Oyna", "#ff8a7a", "#ffffff", 28, _play)
	play.custom_minimum_size = Vector2(240, 64)
	var pc := CenterContainer.new()
	pc.add_child(play)
	tv.add_child(pc)
	var small := _label("Godot 4 prototipi", 14, "#6f6687")
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(small)
	var tc := MarginContainer.new()
	tc.set_anchors_preset(Control.PRESET_FULL_RECT)
	tc.add_theme_constant_override("margin_top", 300)
	scr_title.add_child(tc)
	tc.add_child(tv)
	# seviyeler
	scr_levels = _screen()
	var lc := _card()
	lc.custom_minimum_size = Vector2(860, 620)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lc.add_child(lv)
	var head := HBoxContainer.new()
	head.add_child(_btn("‹", "#f3effa", "#3f3656", 22, _show_title))
	var ht := _label("  Kuleler", 30)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	head.add_child(_btn("Yedekle / geri yükle", "#f3effa", "#3f3656", 15, _open_backup))
	lv.add_child(head)
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(ls)
	levels_list = VBoxContainer.new()
	levels_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(levels_list)
	_center(scr_levels, lc)
	# kazanma
	scr_win = _screen()
	var wc := _card()
	wc.custom_minimum_size = Vector2(440, 0)
	var wv := VBoxContainer.new()
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 10)
	wc.add_child(wv)
	var wt := _label("Kristal bulundu!", 30)
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(wt)
	lbl_stars = _label("★★★", 54, "#ffb400")
	lbl_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(lbl_stars)
	lbl_win = _label("", 18)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(lbl_win)
	var wr := HBoxContainer.new()
	wr.alignment = BoxContainer.ALIGNMENT_CENTER
	wr.add_theme_constant_override("separation", 10)
	wr.add_child(_btn("Seviyeler", "#f3effa", "#3f3656", 18, _open_levels))
	wr.add_child(_btn("Programa dön", "#f3effa", "#3f3656", 18, _retry))
	btn_next = _btn("Sonraki ▸", "#ff8a7a", "#ffffff", 18, func(): _start_level(mini(levels.size() - 1, level_idx + 1)))
	wr.add_child(btn_next)
	wv.add_child(wr)
	_center(scr_win, wc)
	# tanıtım kartı
	scr_intro = _screen()
	var ic := _card()
	ic.custom_minimum_size = Vector2(500, 0)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	ic.add_child(iv)
	var badge := _label("YENİ", 13, "#ff8e72")
	iv.add_child(badge)
	lbl_intro_title = _label("", 26)
	iv.add_child(lbl_intro_title)
	lbl_intro_text = RichTextLabel.new()
	lbl_intro_text.bbcode_enabled = true
	lbl_intro_text.fit_content = true
	lbl_intro_text.custom_minimum_size = Vector2(456, 0)
	lbl_intro_text.add_theme_font_size_override("normal_font_size", 17)
	lbl_intro_text.add_theme_font_size_override("bold_font_size", 17)
	lbl_intro_text.add_theme_color_override("default_color", Color("#3f3656"))
	iv.add_child(lbl_intro_text)
	iv.add_child(_btn("Anladım", "#ff8a7a", "#ffffff", 18, func():
		progress["seen"][str(level_idx)] = 1
		_save_progress()
		scr_intro.visible = false))
	_center(scr_intro, ic)
	# yedek
	scr_backup = _screen()
	var bk := _card()
	bk.custom_minimum_size = Vector2(560, 0)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bk.add_child(bv)
	bv.add_child(_label("İlerleme yedeği", 26))
	var bl := _label("Web/Android sürümündeki KK1 koduyla aynıdır. Kodu buraya yapıştırıp Geri yükle'ye bas.", 15, "#6f6687")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(516, 0)
	bv.add_child(bl)
	backup_edit = TextEdit.new()
	backup_edit.custom_minimum_size = Vector2(516, 120)
	backup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	bv.add_child(backup_edit)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	br.add_child(_btn("Kopyala", "#f3effa", "#3f3656", 16, func():
		DisplayServer.clipboard_set(_export_code())
		_toast("Yedek kodu kopyalandı")))
	br.add_child(_btn("Geri yükle", "#ff8a7a", "#ffffff", 16, func():
		if _import_code(backup_edit.text):
			scr_backup.visible = false
			_toast("İlerleme geri yüklendi")
			_open_levels()
		else:
			_toast("Geçersiz yedek kodu")))
	br.add_child(_btn("Kapat", "#ffffff", "#6f6687", 16, func(): scr_backup.visible = false))
	bv.add_child(br)
	_center(scr_backup, bk)

func _show(which: String) -> void:
	scr_title.visible = which == "title"
	scr_levels.visible = which == "levels"
	scr_win.visible = which == "win"
	scr_backup.visible = false
	scr_intro.visible = false
	hud.visible = which == ""
	cam_spin = which == "title"

func _show_title() -> void:
	build_level(5, true)
	cam_az = 20.0
	cam_az_cur = 20.0
	cam_zoom = 0.85
	_show("title")

func _play() -> void:
	var n := int(progress["unlocked"]) - 1
	if not progress["best"].has(str(n)) and n < levels.size():
		_start_level(n)
	else:
		_open_levels()

func _open_backup() -> void:
	backup_edit.text = _export_code()
	scr_backup.visible = true

func _open_levels() -> void:
	if mode == "running":
		_set_mode("paused", true)
	for c in levels_list.get_children():
		c.queue_free()
	var chapter := ""
	var grid: GridContainer
	var ch_i := 0
	for i in levels.size():
		var lv: Dictionary = levels[i]
		if lv["chapter"] != chapter:
			chapter = lv["chapter"]
			ch_i += 1
			levels_list.add_child(_label("Bölüm %d · %s" % [ch_i, chapter], 18, "#9a7cf0"))
			grid = GridContainer.new()
			grid.columns = 6
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			levels_list.add_child(grid)
		var locked := i >= int(progress["unlocked"])
		var best = progress["best"].get(str(i))
		var p: Dictionary = PALETTES[int(lv.get("palette", i)) % PALETTES.size()]
		var stars := ""
		if best != null:
			stars = "\n" + "★".repeat(int(best["stars"])) + "☆".repeat(3 - int(best["stars"]))
		var b := _btn(("🔒" if locked else str(i + 1)) + "\n" + lv["name"] + stars, "#cfc8dd" if locked else p["bg"][0], "#3f3656", 14)
		b.custom_minimum_size = Vector2(128, 96)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = locked
		var idx := i
		b.pressed.connect(func(): _start_level(idx))
		grid.add_child(b)
	_show("levels")

func _start_level(i: int) -> void:
	build_level(i)
	var saved = progress["progs"].get(str(i))
	prog = Program.parse_program(saved) if saved is Dictionary else {"main": [], "p1": [], "p2": []}
	var slots: Dictionary = levels[i]["slots"]
	for r in ROWS:
		var cap := int(slots.get(r, 0))
		if prog[r].size() > cap:
			prog[r] = prog[r].slice(0, cap)
	active_row = "main"
	sel = null
	_show("")
	lbl_hint.text = "İpucu: " + levels[i].get("hint", "")
	hint_panel.visible = false
	_render_palette()
	_set_mode("edit")
	var intro = levels[i].get("intro")
	if intro is Dictionary and not progress["seen"].has(str(i)) and not instant:
		lbl_intro_title.text = intro["title"]
		lbl_intro_text.text = _html_to_bb(intro["text"])
		scr_intro.visible = true

func _html_to_bb(s: String) -> String:
	var re := RegEx.new()
	re.compile("<span class=\"cond (o|x)\">(.*?)</span>")
	var out := re.sub(s, "[color=#2fc37a]$2[/color]", true)
	return out.replace("<b>", "[b]").replace("</b>", "[/b]").replace("<i>", "[i]").replace("</i>", "[/i]")

func _retry() -> void:
	win_shown = false
	_show("")
	_reset_to_setup()
	_set_mode("edit")

func _update_hud() -> void:
	if L == null or preview:
		return
	var def: Dictionary = levels[level_idx]
	var ch := 0
	var last := ""
	for k in level_idx + 1:
		if levels[k]["chapter"] != last:
			last = levels[k]["chapter"]
			ch += 1
	lbl_chap.text = ("BÖLÜM %d · %s" % [ch, def["chapter"]]).to_upper()
	var dark: bool = pal.get("dark", false)
	lbl_chap.add_theme_color_override("font_color", Color("#cfc6ee") if dark else Color("#6f6687"))
	lbl_name.add_theme_color_override("font_color", Color("#f5efff") if dark else Color("#3f3656"))
	lbl_name.text = "%d · %s" % [level_idx + 1, def["name"]]
	var blocks := Program.block_count(prog)
	var st := _stars_for(blocks, int(def["par"])) if blocks > 0 else 3
	lbl_blocks.text = "%d / par %d   %s" % [blocks, int(def["par"]), "★".repeat(st) + "☆".repeat(3 - st)]
	btn_stop.disabled = mode == "edit"

func _toast(msg: String) -> void:
	if instant:
		return
	lbl_toast.text = msg
	lbl_toast.visible = true
	toast_t = 2.0


# ---------- program editörü ----------
class CmdIcon extends Control:
	var c := "F"
	func _draw() -> void:
		var s := size
		var w := maxf(2.5, s.x * 0.075)
		var col := Color.WHITE
		var P := func(x, y): return Vector2(x * s.x, y * s.y)
		match c:
			"F":
				draw_line(P.call(0.5, 0.8), P.call(0.5, 0.22), col, w, true)
				draw_polyline([P.call(0.26, 0.46), P.call(0.5, 0.22), P.call(0.74, 0.46)], col, w, true)
			"L", "R":
				var m := -1.0 if c == "L" else 1.0
				var X := func(x): return 0.5 + (x - 0.5) * m
				var pts := [P.call(X.call(0.32), 0.84), P.call(X.call(0.32), 0.55)]
				for k in range(1, 9):
					var a := PI + PI * 0.5 * k / 8.0
					pts.append(P.call(X.call(0.55 + 0.23 * cos(a)), 0.55 + 0.23 * sin(a)))
				pts.append(P.call(X.call(0.76), 0.32))
				draw_polyline(PackedVector2Array(pts), col, w, true)
				draw_polyline([P.call(X.call(0.62), 0.18), P.call(X.call(0.77), 0.32), P.call(X.call(0.62), 0.46)], col, w, true)
			"J":
				var pts := []
				for k in 13:
					var a := PI * k / 12.0
					pts.append(P.call(0.2 + 0.6 * k / 12.0, 0.78 - 0.5 * sin(a)))
				draw_polyline(PackedVector2Array(pts), col, w, true)
				draw_polyline([P.call(0.66, 0.66), P.call(0.8, 0.78), P.call(0.88, 0.6)], col, w, true)
			"A":
				draw_arc(P.call(0.5, 0.5), s.x * 0.13, 0, TAU, 20, col, w, true)
				for k in 8:
					var a := TAU * k / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(P.call(0.5, 0.5) + d * s.x * 0.24, P.call(0.5, 0.5) + d * s.x * 0.36, col, w, true)
			"W":
				draw_line(P.call(0.38, 0.25), P.call(0.38, 0.75), col, w * 1.3, true)
				draw_line(P.call(0.62, 0.25), P.call(0.62, 0.75), col, w * 1.3, true)
			_:
				var f := ThemeDB.fallback_font
				var fs := int(s.y * 0.36)
				var t := "F" + c
				var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2((s.x - tw) / 2, s.y * 0.62), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _tile(ins: Dictionary, size := 46.0, state_flag := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var col: String = CMD_COLOR.get(ins["c"], "#888888")
	_style_button(b, col, 12)
	if ins["k"] != "":
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.border_color = Color(COND_COLOR[ins["k"]])
			sb.set_border_width_all(4)
	if state_flag == "sel":
		for st in ["normal", "hover"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.border_color = Color("#9a7cf0")
			sb.set_border_width_all(4)
			sb.expand_margin_top = 4
	elif state_flag == "run":
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.border_color = Color("#ffb400")
		sb.set_border_width_all(4)
		sb.shadow_color = Color("#ffb40099")
		sb.shadow_size = 10
	elif state_flag == "skip":
		b.modulate = Color(1, 1, 1, 0.45)
	var ic := CmdIcon.new()
	ic.c = ins["c"]
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	if ins["k"] != "":
		var dot := _label("✓" if ins["k"] == "o" else "✕", 11, "#ffffff")
		var dp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COND_COLOR[ins["k"]])
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		dp.add_theme_stylebox_override("panel", sb)
		dp.add_child(dot)
		dp.position = Vector2(-6, -6)
		dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dp)
	return b

func _render_palette() -> void:
	for c in palette_box.get_children():
		c.queue_free()
	for c in levels[level_idx]["cmds"]:
		var b := _tile({"c": c, "k": ""}, 52)
		b.tooltip_text = Program.COMMANDS[c]["name"] + " — " + Program.COMMANDS[c]["desc"]
		var cc: String = c
		b.pressed.connect(func(): _insert(cc))
		palette_box.add_child(b)

var _exec := {"proc": "", "idx": -1}
var _skipped := []

func _mark_exec(n, skipped: Array) -> void:
	_exec = {"proc": n["proc"], "idx": n["idx"]} if n != null else {"proc": "", "idx": -1}
	_skipped = skipped
	if not instant:
		_render_rows()

func _render_rows() -> void:
	if rows_box == null or L == null:
		return
	for c in rows_box.get_children():
		c.queue_free()
	var slots: Dictionary = levels[level_idx]["slots"]
	for row in ROWS:
		var cap := int(slots.get(row, 0))
		if cap <= 0:
			continue
		var rp := PanelContainer.new()
		var rsb := StyleBoxFlat.new()
		rsb.set_corner_radius_all(14)
		rsb.content_margin_left = 6
		rsb.content_margin_right = 6
		rsb.content_margin_top = 6
		rsb.content_margin_bottom = 6
		rsb.bg_color = Color("#9a7cf01a") if row == active_row and mode == "edit" else Color(0, 0, 0, 0)
		if _exec["proc"] == row:
			rsb.bg_color = Color("#ffc83c22")
		rp.add_theme_stylebox_override("panel", rsb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		rp.add_child(h)
		var lbl := _btn(ROW_LABEL[row], ROW_COLOR[row], "#ffffff", 15)
		lbl.custom_minimum_size = Vector2(52, 46)
		var rr: String = row
		lbl.pressed.connect(func():
			active_row = rr
			sel = null
			_render_rows())
		h.add_child(lbl)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		h.add_child(flow)
		for idx in prog[row].size():
			var flag := ""
			if sel != null and sel["row"] == row and sel["idx"] == idx:
				flag = "sel"
			if _exec["proc"] == row and _exec["idx"] == idx:
				flag = "run"
			for sk in _skipped:
				if sk["proc"] == row and sk["idx"] == idx:
					flag = "skip"
			var t := _tile(prog[row][idx], 46, flag)
			var ii: int = idx
			t.pressed.connect(func(): _select(rr, ii))
			flow.add_child(t)
		for k in range(prog[row].size(), cap):
			var e := Panel.new()
			e.custom_minimum_size = Vector2(46, 46)
			var esb := StyleBoxFlat.new()
			esb.bg_color = Color(0, 0, 0, 0)
			esb.border_color = Color("#3f365624")
			esb.set_border_width_all(2)
			esb.set_corner_radius_all(12)
			e.add_theme_stylebox_override("panel", esb)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flow.add_child(e)
		rows_box.add_child(rp)
	sel_bar.visible = sel != null and mode == "edit"
	if sel != null and sel["idx"] < prog[sel["row"]].size():
		var ins: Dictionary = prog[sel["row"]][sel["idx"]]
		btn_cond.text = "Koşul: " + COND_NAME[ins["k"]]
		btn_cond.visible = levels[level_idx].get("conds", false) and ins["c"] != "W"
	_update_hud()

func _editable() -> bool:
	if win_shown or preview:
		return false
	if mode == "ended":
		_reset_to_setup()
	return mode == "edit"

func _insert(c: String) -> void:
	if not _editable() or not (c in levels[level_idx]["cmds"]):
		return
	var cap := int(levels[level_idx]["slots"].get(active_row, 0))
	if prog[active_row].size() >= cap:
		_toast("%s satırı dolu (%d blok)" % [ROW_LABEL[active_row], cap])
		return
	prog[active_row].append({"c": c, "k": ""})
	sel = null
	_prog_changed()

func _select(row: String, idx: int) -> void:
	if not _editable():
		return
	if sel != null and sel["row"] == row and sel["idx"] == idx:
		sel = null
	else:
		sel = {"row": row, "idx": idx}
	active_row = row
	_render_rows()

func _delete_sel() -> void:
	if sel == null or not _editable():
		return
	prog[sel["row"]].remove_at(sel["idx"])
	sel = null
	_prog_changed()

func _move_sel(d: int) -> void:
	if sel == null or not _editable():
		return
	var row: Array = prog[sel["row"]]
	var j: int = sel["idx"] + d
	if j < 0 or j >= row.size():
		return
	var t = row[sel["idx"]]
	row[sel["idx"]] = row[j]
	row[j] = t
	sel["idx"] = j
	_prog_changed()

func _cycle_cond() -> void:
	if sel == null or not _editable():
		return
	var ins: Dictionary = prog[sel["row"]][sel["idx"]]
	ins["k"] = {"": "o", "o": "x", "x": ""}[ins["k"]]
	_prog_changed()

func _clear_prog() -> void:
	if not _editable():
		return
	prog = {"main": [], "p1": [], "p2": []}
	sel = null
	_prog_changed()

func _cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % SPEEDS.size()
	btn_speed.text = "%d×" % int(SPEEDS[speed_idx])

func _prog_changed() -> void:
	progress["progs"][str(level_idx)] = Program.program_to_src(prog)
	_save_progress()
	_render_rows()


# =====================================================================
# Otomatik test: her seviyenin referans programı gerçek sahne hattından çalıştırılır.
# godot --headless --path godot-program -- --autotest
func _autotest() -> void:
	instant = true
	var ok := 0
	for i in levels.size():
		_start_level(i)
		var sol: Dictionary = levels[i]["solution"]
		prog = Program.parse_program(sol)
		var ops: Array = sol.get("ops", [])
		for op in (ops[0] if ops.size() > 0 else []):
			if op["t"] == "view":
				_rotate_view(int(op["s"]))
			else:
				_world_op(op)
			_update_queue(0.0)
		_run_toggle()
		var k := 0
		for guard in 200:
			_update_queue(0.0)
			if mode == "paused":
				k += 1
				for op in (ops[k] if ops.size() > k else []):
					if op["t"] == "view":
						_rotate_view(int(op["s"]))
					else:
						_world_op(op)
					_update_queue(0.0)
				_run_toggle()
			elif mode != "running":
				break
		var good := win_shown
		if good:
			ok += 1
		print("autotest #%d %s: %s" % [i + 1, levels[i]["name"], "TAMAM" if good else "HATA (" + mode + ")"])
	print("autotest: %d/%d" % [ok, levels.size()])
	get_tree().quit(0 if ok == levels.size() else 1)

## Ekran görüntüsü: godot --path godot-program -- --shot=<seviye>:<dosya>
func _shot(spec: String) -> void:
	var parts := spec.split(":")
	var i := int(parts[0]) - 1
	if i < 0:
		_show_title()
	else:
		_start_level(i)
		scr_intro.visible = false
		var sol: Dictionary = levels[i]["solution"]
		prog = Program.parse_program(sol)
		_render_rows()
	for f in 90:
		await get_tree().process_frame
	if i >= 0 and parts.size() > 2:
		_run_toggle()
		for f in int(parts[2]):
			await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(parts[1])
	get_tree().quit()
