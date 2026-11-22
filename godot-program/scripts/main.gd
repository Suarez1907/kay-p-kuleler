## Kayıp Kuleler — Godot 4 istemcisi (programlama bulmacası, prototip).
## Kurallar: scripts/logic.gd (ızgara fizik motoru) + scripts/program.gd (yorumlayıcı).
## Seviyeler: data/levels_100.json (tools/level_database_builder.gd üretir; 10 donanım fazı × 10 seviye).
extends Node3D

const SAVE_PATH := "user://ilerleme.json"
const DIRS := PuzzleLogic.DIRS
const EL := 0.6154797
## Bakış açılarının (0..3) renkleri: hayalet bloklar ve açı göstergesi aynı rengi kullanır.
const VIEW_COLS := [Color("#5fc8ff"), Color("#b58cff"), Color("#4fe0a0"), Color("#ffb84d")]
const ROWS := ["main", "p1", "p2"]
const ROW_LABEL := {"main": "Ana", "p1": "F1", "p2": "F2"}
const SPEEDS := [1.0, 2.0, 4.0]
const PANEL_W := 400.0
const CMD_COLOR := {"F": "#5b8def", "L": "#9b7be8", "R": "#9b7be8", "J": "#2fb39f", "A": "#ff9248", "W": "#e8648a", "1": "#efa92b", "2": "#3fb0dd", "C": "#38c6d8"}
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
var run_ctx := {}           # tur tabanlı yürütücü: {prog, main: Runner, clone: Runner, gen}
var step_once = false
var speed_idx := 0
var end_reason := ""
var run_log := {}
# ---------- bilgisayar toplama (montaj sahnesi / vitrin) ----------
const ASSEMBLY_SCENE := preload("res://scenes/AssemblyScene.tscn")
var assembly: Control = null
var asm_layer: CanvasLayer
var _asm_return := ""
var btn_pc_title: Button
var btn_pc_pause: Button           # Nova analizi için: {last, first_bump, bumps}
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
# ---------- game feel (Faz 3) ----------
var _tw := {}               # isimli tween'ler: yenisi başlamadan eskisi kill() edilir
var cell_nodes := {}        # Vector3i -> Node3D (statik blok/merdiven hücresi; zıplama ve açılış için)

# ---------- sahne ----------
var world: Node3D
var level_root: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var weather: Weather
var theme_app: ThemeApplicator
var objs := {}
var mat_cache := {}
var rbox_mesh: ArrayMesh
var crate_mesh: ArrayMesh
var cam_az := 45.0
var cam_az_cur := 45.0
var cam_zoom := 1.0
var cam_target := Vector3.ZERO
## Başlık ekranı dioraması (Blender: devre adasındaki kayıp kule); seviye yüklenince kaldırılır
var title_dio: Node3D = null
var cam_size := 12.0
var cam_spin := false
var ptr = null

# ---------- arayüz (bkz. "Arayüz" bölümü) ----------
var audio: GameAudio
var gfx := 2                # 0 düşük, 1 orta, 2 yüksek
var ui: CanvasLayer
var ui_root: Control
var fx_layer: CanvasLayer
var hud: Control
var panel: PanelContainer
var panel_sep: ColorRect
var palette_box: HBoxContainer
var palette_scroll: ScrollContainer
var panel_box: VBoxContainer
var rows_box: VBoxContainer
var rows_scroll: ScrollContainer
var sel_bar: HBoxContainer
var btn_cond: Button
var btn_run: Button
var btn_step: Button
var btn_stop: Button
var btn_speed: Button
var btn_clear: Button
var btn_menu: Button
var btn_hint: Button
var btn_cam: Button
var top_bar: HBoxContainer
var theme_bar: HBoxContainer
var lbl_theme: Label
var row_tabs: HBoxContainer
var tool_row: HBoxContainer
var run_row: HBoxContainer
var theme_compact := false
## Sol, üst, sağ, alt. x < 0 ise DisplayServer güvenli alanı kullanılır (ekran görüntüsünde çentik simülasyonu).
var safe_override := Vector4(-1, -1, -1, -1)
var _safe_applied := Vector4(-2, -2, -2, -2)
var lbl_chap: Label
var lbl_name: Label
var lbl_blocks: Label
var mini_stars: HBoxContainer
var status_pill: PanelContainer
var lbl_status: Label
var hint_card: PanelContainer
var lbl_hint: Label
var nova_card: PanelContainer
var lbl_nova_title: Label
var lbl_nova: Label
var view_dots: HBoxContainer
var intro_badge: PanelContainer
var intro_nova: Control
var toast_pill: PanelContainer
var lbl_toast: Label
var veil: ColorRect
var screens := {}
var levels_list: VBoxContainer
var title_logo: Control
var title_play: Button
var _play_tw: Tween = null
var win_card: PanelContainer
var win_stars: Array = []
var lbl_win_title: Label
var lbl_win: Label
var btn_next: Button
var lbl_intro_title: Label
var lbl_intro_text: RichTextLabel
var backup_edit: TextEdit
var btn_sound: Button
var btn_music: Button
var btn_gfx: Button
var btn_vib: Button
var dev_jump: SpinBox
var lbl_title_stars: Label
var tile_nodes := {}        # row -> [Button]
var _run_tw: Tween = null
var _toast_tw: Tween = null
var _insert_anim = null     # {row, idx}
var portrait := false


# =====================================================================
func _ready() -> void:
	levels = LevelProgressionManager.levels()
	_load_progress()
	UIKit.init_fonts()
	audio = GameAudio.new()
	add_child(audio)
	audio.sound_on = progress.get("sound", true)
	var ah := Sfx.ah()
	if ah != null:
		ah.sound_on = audio.sound_on
		ah.haptics_on = progress.get("haptics", true)
	gfx = int(progress.get("gfx", 2))
	rbox_mesh = _rounded_box(Vector3.ONE, 0.03, 0)
	crate_mesh = _rounded_box(Vector3(0.84, 0.84, 0.84), 0.04, 0)
	_setup_world()
	_setup_ui()
	_apply_gfx()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		_autotest.call_deferred()
	if "--feeltest" in args:
		_feeltest.call_deferred()
		return
	for a in args:
		if a.begins_with("--shot="):
			_shot.call_deferred(a.substr(7))
			return
		if a == "--layouttest":
			_layouttest.call_deferred()
			return
		if a.begins_with("--themecycle="):
			_themecycle.call_deferred(a.substr(13))
			return
	var migrated := _migrate_webview()
	_show_title()
	audio.set_music(progress.get("music", true))
	if migrated:
		_toast.call_deferred("Önceki sürümdeki ilerlemen taşındı")


# ---------- kayıt ----------
func _load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
		if d is Dictionary:
			for k in d:
				progress[k] = d[k]
	progress["unlocked"] = int(progress.get("unlocked", 1))
	# bilgisayar parçaları: eski kayıtlarda tamamlanmış her seviyenin parçası verilir
	if not progress.has("unlocked_parts"):
		var parts := []
		for k in progress.get("best", {}):
			parts.append(int(k) + 1)
		parts.sort()
		progress["unlocked_parts"] = parts
	var clean := []
	for v in progress["unlocked_parts"]:
		if int(v) >= 1 and int(v) <= PCPartLibrary.COUNT and not (int(v) in clean):
			clean.append(int(v))
	progress["unlocked_parts"] = clean
	# devre kampanyasına geçiş (levels_100.json): eski kampanyanın kayıtları "legacy" altında saklanır,
	# tamamlanan seviye sayısı kadar yeni seviye açık başlar; kazanılmış parçalar korunur
	if int(progress.get("campaign", 1)) < 2:
		progress["legacy"] = {"unlocked": progress["unlocked"], "best": progress["best"], "progs": progress["progs"], "seen": progress["seen"]}
		progress["unlocked"] = clampi((progress["best"] as Dictionary).size() + 1, 1, 100)
		progress["best"] = {}
		progress["progs"] = {}
		progress["seen"] = {}
		progress["campaign"] = 2

func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))

## Ana sürüm eskiden bir WebView uygulamasıydı (aynı paket adı). Güncellemeden sonra eski ilerleme
## WebView'in localStorage'ında (LevelDB dosyaları) kalır; ilk açılışta oradan okunup birleştirilir.
func _migrate_webview() -> bool:
	if progress.get("webview_checked", false):
		return false
	progress["webview_checked"] = true
	var dir := OS.get_user_data_dir().get_base_dir().path_join("app_webview/Default/Local Storage/leveldb")
	var found := _scan_leveldb(dir)
	var ok := false
	if found != "":
		ok = _import_code("KK1:" + Marshalls.utf8_to_base64(found))
	_save_progress()
	return ok

## LevelDB dosyalarında ilerleme JSON'unu arar (Latin-1 ya da UTF-16LE kodlu); en ileri olanı döndürür.
static func _scan_leveldb(dir: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	var best := ""
	var best_score := -1
	for fn in d.get_files():
		if not (fn.ends_with(".log") or fn.ends_with(".ldb")):
			continue
		var bytes := FileAccess.get_file_as_bytes(dir.path_join(fn))
		for cand in _json_candidates(bytes):
			var data = JSON.parse_string(cand)
			if data is Dictionary and data.has("unlocked") and data.has("best"):
				var score := int(data["unlocked"]) * 1000 + (data["best"] as Dictionary).size()
				if score > best_score:
					best_score = score
					best = cand
	return best

static func _json_candidates(bytes: PackedByteArray) -> Array:
	var out := []
	var pats := [["{\"unlocked\":".to_ascii_buffer(), 1], ["{\"unlocked\":".to_utf16_buffer(), 2]]
	for pat in pats:
		var needle: PackedByteArray = pat[0]
		var step: int = pat[1]
		var i := 0
		while true:
			i = _find_bytes(bytes, needle, i)
			if i < 0:
				break
			var depth := 0
			var j := i
			var chars := PackedByteArray()
			while j < bytes.size():
				var c := bytes[j]
				chars.append(c)
				if c == 0x7B:
					depth += 1
				elif c == 0x7D:
					depth -= 1
					if depth == 0:
						break
				j += step
			if depth == 0:
				out.append(chars.get_string_from_utf8())
			i += needle.size()
	return out

static func _find_bytes(hay: PackedByteArray, needle: PackedByteArray, from: int) -> int:
	var n := needle.size()
	var first := needle[0]
	var i := hay.find(first, from)
	while i >= 0 and i + n <= hay.size():
		if hay.slice(i, i + n) == needle:
			return i
		i = hay.find(first, i + 1)
	return -1

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
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4ecff")
	env.ambient_light_energy = 0.38
	# Doğrusal ton eşleme: pastel, düşük dinamik aralıklı bu sahnede renkler ekrana olduğu gibi gider.
	# AgX beyazları ~%80'de tavanlıyor, ACES (beyaz=1) orta-açık tonları beyaza sıkıştırıyordu; ikisi de
	# soğuk gökyüzü gradyanını ve taş blok tonlarını birlikte tutturmayı engelliyordu.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# sis kapalı: sahne net ve kontrastlı kalsın (derinlik ışık ve temas gölgeleriyle verilir)
	env.fog_enabled = false
	env.fog_density = 0.0
	env.fog_light_energy = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 0.78
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.2
	sun.shadow_opacity = 0.82
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	# güneş: üst yüz en parlak, +x yüzü orta, +z yüzü koyu → izometrik bakışta 3 ayrı ton
	sun.look_at_from_position(Vector3(7.0, 10.0, 3.0), Vector3.ZERO, Vector3.UP)
	fill = DirectionalLight3D.new()
	fill.light_color = Color("#b9c4ff")
	fill.light_energy = 0.22
	add_child(fill)
	fill.look_at_from_position(Vector3(-6.0, 4.0, -2.0), Vector3.ZERO, Vector3.UP)
	theme_app = ThemeApplicator.new()
	theme_app.bind(self)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 300.0
	add_child(cam)
	world = Node3D.new()
	add_child(world)
	# gökyüzü + hava durumu (prosedürel shader, 3B yağış, şimşek, ortam sesi)
	weather = Weather.new()
	add_child(weather)
	weather.setup(bg_layer, world, env, sun, audio)


# ---------- geometri / malzeme ----------
## Yuvarlatılmış kutu: alt bölümlü bir kutunun köşelerini küreye yaklaştırır.
## seg == 0: "keskin pah" modu. Kutu eksen başına 3 dilime bölünür ve iç ızgara çizgileri pahın tam
## başına (yarı boyut − r) taşınır; böylece yumuşak normal geçişi yalnızca ince pah bandında kalır,
## yüzler düz ve keskin okunur (eskiden geçiş yüzün dörtte birine yayılıp "sabun" görünümü veriyordu).
func _rounded_box(size: Vector3, r: float, seg: int) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	var crisp := seg == 0
	var n_seg := 2 if crisp else seg
	bm.subdivide_width = n_seg
	bm.subdivide_height = n_seg
	bm.subdivide_depth = n_seg
	var arr := bm.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var inner := size * 0.5 - Vector3(r, r, r)
	if crisp:
		var half := size * 0.5
		for i in verts.size():
			var v := verts[i]
			for ax in 3:
				if absf(v[ax]) < half[ax] - 0.001:
					v[ax] = signf(v[ax]) * inner[ax]
			verts[i] = v
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
	# sahte ortam gölgesi: blok dibe doğru hafifçe koyulaşır, üst kenarlar parlar
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var h := clampf(verts[i].y / size.y + 0.5, 0.0, 1.0)
		var k := lerpf(0.74, 1.0, pow(h, 0.7))
		if norms[i].y > 0.5:
			k = 1.0
		cols[i] = Color(k, k, k)
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## Blok başına temas gölgesi (Mobile renderer'da SSAO yok): üst yüzün, yanında/köşesinde bir üst katta
## blok bulunan kenarları koyulaşır. Komşu düzenine göre (8 bit) önbelleğe alınır.
var _ao_cache := {}
var _rbox_arrays = null

func _ao_box(p: Vector3i) -> Mesh:
	var sides := [Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 1, -1),
		Vector3i(1, 1, 1), Vector3i(1, 1, -1), Vector3i(-1, 1, 1), Vector3i(-1, 1, -1)]
	var mask := 0
	for k in sides.size():
		if L.statics.has(p + sides[k]):
			mask |= 1 << k
	if mask == 0:
		return rbox_mesh
	if _ao_cache.has(mask):
		return _ao_cache[mask]
	if _rbox_arrays == null:
		_rbox_arrays = rbox_mesh.surface_get_arrays(0)
	var arr: Array = _rbox_arrays.duplicate()
	if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
		return rbox_mesh
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = (arr[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
	for i in verts.size():
		var v := verts[i]
		if v.y < 0.3:
			continue
		var occ := 0.0
		var wx := clampf((v.x - 0.0) / 0.5, 0.0, 1.0)
		var wnx := clampf((-v.x) / 0.5, 0.0, 1.0)
		var wz := clampf(v.z / 0.5, 0.0, 1.0)
		var wnz := clampf((-v.z) / 0.5, 0.0, 1.0)
		var e := 2.2
		if mask & 1: occ += pow(wx, e)
		if mask & 2: occ += pow(wnx, e)
		if mask & 4: occ += pow(wz, e)
		if mask & 8: occ += pow(wnz, e)
		if mask & 16: occ += pow(minf(wx, wz), e) * 0.6
		if mask & 32: occ += pow(minf(wx, wnz), e) * 0.6
		if mask & 64: occ += pow(minf(wnx, wz), e) * 0.6
		if mask & 128: occ += pow(minf(wnx, wnz), e) * 0.6
		var k := 1.0 - minf(occ, 1.0) * 0.42
		cols[i] = Color(cols[i].r * k, cols[i].g * k, cols[i].b * k)
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_ao_cache[mask] = m
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
	if opts.get("vc", false):
		m.vertex_color_use_as_albedo = true
	if opts.get("rim", false):
		m.rim_enabled = true
		m.rim = 0.12
		m.rim_tint = 0.8
	if not opts.get("unique", false):
		mat_cache[key] = m
	return m

## Blender bulmaca modeli (assets/models/puzzle/<ad>.glb). Grafik "Düşük" ya da dosya yoksa null → prosedürel.
func _pz(name: String, target: Vector3, align = true) -> Node3D:
	if not ComponentFactory.use_models:
		return null
	return AssetLoader.load_model(AssetLoader.MODELS + "puzzle/%s.glb" % name, target, align)

## Modeldeki adı verilen malzemenin yüzeylerine örneğe özel, verilen renkte ışıyan kopya bağlar
func _pz_tint(root: Node, mat_name: String, col: Color, energy := 2.5, alpha := 1.0) -> Array:
	var ms := AssetLoader.unique_surfaces(root, mat_name)
	for m in ms:
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			sm.albedo_color = Color(col, alpha)
			sm.emission_enabled = true
			sm.emission = col
			sm.emission_energy_multiplier = energy
			if alpha < 1.0:
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return ms

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

## Mimari taş/krem tonları (kat sırasına göre); seviyenin kimliği için paletten yalnızca hafif ton.
## Gece paletlerinde paletin kendi renkleri korunur.
const STONE := ["#EAE4DC", "#E2DACF", "#D8CFC2", "#C4D3DF"]
const SKY_TOP := "#B8D4E8"
const SKY_BOTTOM := "#EBF3F8"

func _block_color(p: Vector3i) -> Color:
	var layer := ((p.y - L.min_y) % 4 + 4) % 4
	var c: Color
	if pal.get("dark", false):
		var b: Array = pal["blocks"]
		c = Color(b[layer % b.size()])
	else:
		c = Color(STONE[layer]).lerp(Color(pal["blocks"][layer % pal["blocks"].size()]), 0.16)
	if (p.x + p.z) % 2 == 0:
		c = c.lightened(0.03)
	return c

## Seviyenin bölüm sırası (0'dan)
func _chapter_of(i: int) -> int:
	var ch := -1
	var last := ""
	for k in i + 1:
		if levels[k]["chapter"] != last:
			last = levels[k]["chapter"]
			ch += 1
	return maxi(ch, 0)

func _sky_colors() -> Array:
	if pal.get("dark", false):
		return [Color(pal["bg"][0]), Color(pal["bg"][1])]
	return [Color(SKY_TOP), Color(SKY_BOTTOM)]

## Doğrusal ton eşlemede arka plan gradyanı ekranda birebir görünür; giriş renkleri hedef renklerle aynıdır.
const SKY_TOP_IN := "#B8D4E8"
const SKY_BOTTOM_IN := "#EBF3F8"

func _sky_input() -> Array:
	if pal.get("dark", false):
		return _sky_colors()
	return [Color(SKY_TOP_IN), Color(SKY_BOTTOM_IN)]


# =====================================================================
# Seviye kurulumu
func build_level(i: int, as_preview := false) -> void:
	level_idx = i
	preview = as_preview
	var def: Dictionary = levels[i]
	pal = PALETTES[int(def.get("palette", i)) % PALETTES.size()]
	# hava durumu bölüme göre: gökyüzü, bulutlar, yağış, şimşek ve sahne ışığı
	weather.apply(Weather.for_chapter(_chapter_of(i)), float(i) * 7.31 + 1.0)
	# bölüm teması havanın üstüne biner; (bölüm - 1) % 15 + 1
	theme_app.prepare(ThemeLibrary.theme(ThemeLibrary.id_for_chapter(_chapter_of(i) + 1)))
	_kill_all_tweens()
	if level_root:
		level_root.queue_free()
	if title_dio != null:
		title_dio.queue_free()
		title_dio = null
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
		"crumbles": [], "links": [], "cranks": [], "portals": [], "phantoms": [], "relays": [], "trail": Node3D.new()}
	level_root.add_child(objs["trail"])
	# Not: GDScript lambdaları yerel değişkenleri kopyalar; sınır kutusu bir sözlükte tutulur.
	var bb := {"box": AABB(Vector3(L.start), Vector3.ZERO)}
	var grow := func(p: Vector3i): bb["box"] = bb["box"].expand(Vector3(p))
	# statik bloklar ve merdivenler
	cell_nodes = {}
	for p in L.statics:
		var v: Dictionary = L.statics[p]
		grow.call(p)
		if v["t"] == "b":
			var first := level_root.get_child_count()
			# zemin bloğu bir devre elemanıdır (varsayılan SMD transistör)
			var cdef: Dictionary = L.comps.get(p, {})
			var comp := ComponentFactory.build(ComponentFactory.type_of(String(cdef.get("t", ""))), int(cdef.get("d", 0)), int(cdef.get("delay", 1)))
			comp.position = Vector3(p)
			level_root.add_child(comp)
			if cdef.get("t", "") == "relay" and String(cdef.get("mode", "")) == "":
				objs["relays"].append({"n": comp, "ri": int(cdef["ri"])})
			# bloğun tüm parçaları tek bir hücre düğümünde: zıplama/açılış animasyonu hepsini birlikte taşır
			var made := level_root.get_children().slice(first)
			var cell := Node3D.new()
			cell.position = Vector3(p)
			level_root.add_child(cell)
			for nd in made:
				level_root.remove_child(nd)
				nd.position -= Vector3(p)
				cell.add_child(nd)
			cell.set_meta("comp", comp)
			cell_nodes[p] = cell
		else:
			var sg := Node3D.new()
			sg.position = Vector3(p)
			sg.rotation.y = [0.0, -PI / 2, PI, PI / 2][int(v["d"])]
			level_root.add_child(sg)
			cell_nodes[p] = sg
			# merdiven: Blender PCB basamakları (varsa), yoksa bloklardan bir ton farklı prosedürel basamaklar
			var stg := _pz("stairs", Vector3.ONE)
			if stg != null:
				stg.position = Vector3(0, -0.5, 0)
				sg.add_child(stg)
				continue
			for k in 3:
				var h := (k + 1) / 3.0
				_mesh(_box(Vector3(1.0 / 3.0, h, 1.0)), theme_app.stair_mat, Vector3(-1.0 / 3.0 + k / 3.0, -0.5 + h / 2.0, 0), sg)
	# köprüler / kapılar
	for bi in L.bridges.size():
		var b: Dictionary = L.bridges[bi]
		var ms := []
		for c in b["cells"]:
			grow.call(c)
			var bg: Node3D = AssetLoader.component_model("bridge", "top") if ComponentFactory.use_models and not b["door"] else null
			if bg != null:
				# harici köprü modeli: üst yüzü hücrenin üstüne hizalı; açılırken yükselir
				var holder := Node3D.new()
				holder.position = Vector3(c) + Vector3(0, 0.5, 0)
				holder.add_child(bg)
				level_root.add_child(holder)
				holder.set_meta("glb", true)
				ms.append(holder)
				continue
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
			_mesh(rbox_mesh, theme_app.block_mat, local, rg)
			_tile_plate(rg, local)
			_mesh(_cyl(0.13, 0.13, 0.02), _mat("#ffffff", {"unshaded": true}), local + Vector3(0, 0.51, 0), rg)
			_pick(rg, Vector3.ONE, {"kind": "rot", "i": ri}, local)
			grow.call(Vector3i(r["pivot"].x + (b.z - r["pivot"].y), b.y, r["pivot"].y + (b.x - r["pivot"].x)))
			grow.call(Vector3i(r["pivot"].x - (b.z - r["pivot"].y), b.y, r["pivot"].y - (b.x - r["pivot"].x)))
		if not r["fixed"]:
			var hy: float = r["handle"].y if r["handle"] != null else r["blocks"][0].y - 1
			var hg := Node3D.new()
			hg.position = Vector3(0, hy + 0.15, 0)
			rg.add_child(hg)
			var hgl := _pz("handle", Vector3(2.2, 0.4, 2.2), false)
			if hgl != null:
				hg.add_child(hgl)
			else:
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
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.56, 0)
		cg.add_child(wheel)
		var cb := _pz("crank_base", Vector3(0.72, 0.56, 0.72))
		var cw := _pz("crank_wheel", Vector3(0.74, 0.2, 0.74), false)
		if cb != null and cw != null:
			cg.add_child(cb)
			wheel.add_child(cw)
		else:
			_mesh(_cyl(0.3, 0.36, 0.14), _mat("#8a7fa3"), Vector3(0, 0.07, 0), cg)
			_mesh(_cyl(0.07, 0.07, 0.42), _mat("#d8d0e6"), Vector3(0, 0.33, 0), cg)
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
		for b in s["blocks"]:
			grow.call(b)
			grow.call(b + s["axis"] * s["max"])
			grow.call(b + s["axis"] * s["min"])
			var slg := _pz("slider", Vector3.ONE, false)
			if slg != null:
				slg.position = Vector3(b)
				sg.add_child(slg)
			else:
				_mesh(rbox_mesh, theme_app.block_mat, Vector3(b), sg)
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
		var crg := _pz("crumble", Vector3.ONE, false)
		if crg != null:
			crg.position = Vector3(c)
			level_root.add_child(crg)
			objs["crumbles"].append(crg)
		else:
			objs["crumbles"].append(_mesh(rbox_mesh, theme_app.block_mat, Vector3(c)))
	# plakalar
	for pl in L.plates:
		var m := _mesh(_cyl(0.36, 0.4, 0.08), _mat(pal["mech"], {"emit": 0.0, "unique": true, "rough": 0.4}), Vector3(pl["p"]) + Vector3(0, -0.46, 0))
		var plg := _pz("plate", Vector3(0.82, 0.1, 0.82), false)
		if plg != null:
			m.mesh = null
			m.add_child(plg)
			m.set_meta("led", _pz_tint(plg, "PlateLED", Color(pal["accent"]), 0.0))
		objs["plates"].append(m)
	# kollar
	for lv in L.levers:
		var lg := Node3D.new()
		lg.position = Vector3(lv["p"]) + Vector3(0, -0.5, 0)
		level_root.add_child(lg)
		var arm := Node3D.new()
		arm.position = Vector3(0, 0.16, 0)
		var lb := _pz("lever_base", Vector3(0.6, 0.26, 0.4))
		var la := _pz("lever_arm", Vector3(0.24, 0.68, 0.24))
		if lb != null and la != null:
			lg.add_child(lb)
			lg.add_child(arm)
			la.position = Vector3(0, -0.03, 0)
			arm.add_child(la)
		else:
			_mesh(_box(Vector3(0.6, 0.18, 0.4)), _mat("#8a7fa3"), Vector3(0, 0.09, 0), lg)
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
	# hayalet bloklar: renk, katılaştıkları bakış açısını gösterir
	for phi in L.phantoms.size():
		var ph: Dictionary = L.phantoms[phi]
		var col: Color = VIEW_COLS[int(ph["views"][0]) % 4]
		var ms := []
		for c in ph["cells"]:
			grow.call(c)
			var m := _mesh(rbox_mesh, _mat(col, {"alpha": true, "unique": true, "rough": 0.35, "emit": 0.0}), Vector3(c))
			var edge := _mesh(_box(Vector3(1.04, 1.04, 1.04)), _mat(col, {"alpha": true, "unique": true, "unshaded": true}), Vector3.ZERO, m)
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var pf := _pz("phantom", Vector3(1.04, 1.04, 1.04), false)
			if pf != null:
				m.add_child(pf)
				_pz_tint(pf, "PhantomFrame", col, 1.8, 0.7)
			ms.append({"m": m, "edge": edge})
		objs["phantoms"].append({"ms": ms, "views": ph["views"], "col": col})
	# ışınlayıcılar
	var pcols := ["#5ef0ff", "#c58bff", "#7dffb0", "#ffd36e"]
	for pi in L.portals.size():
		var pt: Dictionary = L.portals[pi]
		for c in [pt["a"], pt["b"]]:
			var col: String = pcols[pi % pcols.size()]
			var ptg := _pz("portal", Vector3(0.8, 0.14, 0.8), false)
			var m: Node3D
			if ptg != null:
				m = Node3D.new()
				m.position = Vector3(c) + Vector3(0, -0.44, 0)
				level_root.add_child(m)
				m.add_child(ptg)
				_pz_tint(ptg, "PortalGlow", Color(col), 3.0)
			else:
				m = _mesh(_torus(0.26, 0.38), _mat(col, {"emit": 2.2, "unshaded": true}), Vector3(c) + Vector3(0, -0.46, 0))
				m.scale = Vector3(1, 0.2, 1)
			var beam := _mesh(_cyl(0.3, 0.34, 1.2), _mat(col, {"alpha": true, "unique": true, "unshaded": true}), Vector3(c) + Vector3(0, 0.12, 0))
			beam.material_override.albedo_color.a = 0.18
			objs["portals"].append({"ring": m, "beam": beam})
	# hedef kristal
	var gp := Vector3(L.goal)
	grow.call(L.goal)
	var gem := _mesh(_gem_mesh(), theme_app.crystal_mat, gp + Vector3(0, 0.1, 0))
	gem.scale = Vector3(1, 1.35, 1)
	var ggl := _pz("goal_crystal", Vector3(0.62, 0.62, 0.62), false)
	if ggl != null:
		# kuantum işlemci: ışıyan çekirdeği tema kristal malzemesini kullanır
		gem.mesh = null
		ggl.scale = Vector3(1, 1.0 / 1.35, 1)
		gem.add_child(ggl)
		AssetLoader.bind_surfaces(ggl, "CrystalCore", theme_app.crystal_mat)
	var ring := _mesh(_torus(0.28, 0.42), _mat("#ffffff", {"alpha": true, "unique": true, "unshaded": true}), gp + Vector3(0, -0.47, 0))
	ring.scale = Vector3(1, 0.1, 1)
	ring.material_override.albedo_color.a = 0.8
	var beam := _mesh(_cyl(0.12, 0.26, 3.2), _mat(pal["accent"], {"alpha": true, "unique": true, "unshaded": true}), gp + Vector3(0, 1.1, 0))
	beam.material_override.albedo_color.a = 0.22
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objs["gem"] = gem
	# kristal çevresini palet rengiyle aydınlatır
	var gl := OmniLight3D.new()
	gl.light_color = theme_app.theme.accent_color
	gl.light_energy = 1.4
	gl.omni_range = 2.6
	gl.position = gp + Vector3(0, 0.3, 0)
	level_root.add_child(gl)
	objs["gem_light"] = gl
	objs["goal_ring"] = ring
	# varlıklar
	for c in state["crates"]:
		var m := _mesh(crate_mesh, _mat("#d9a066", {"alpha": true, "unique": true}))
		var cgl := _pz("crate", Vector3(0.84, 0.84, 0.84), false)
		if cgl != null:
			# CPU paketi kasası
			m.mesh = null
			m.add_child(cgl)
		else:
			_mesh(_box(Vector3(0.7, 0.08, 0.86)), _mat("#a8703f"), Vector3(0, 0.25, 0), m)
			_mesh(_box(Vector3(0.7, 0.08, 0.86)), _mat("#a8703f"), Vector3(0, -0.25, 0), m)
		objs["crates"].append(m)
	for b in state["balls"]:
		var m := _mesh(_sphere(0.36), _mat("#f4f1ff", {"alpha": true, "unique": true, "rough": 0.35}))
		_mesh(_torus(0.33, 0.37), _mat("#ff7f88"), Vector3.ZERO, m)
		objs["balls"].append(m)
	objs["player"] = _make_robot()
	level_root.add_child(objs["player"])
	# klon hologramı (yarı saydam, camgöbeği)
	var holo := _make_robot()
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(0.35, 0.9, 1.0, 0.38)
	hm.emission_enabled = true
	hm.emission = Color(0.3, 0.85, 1.0)
	hm.emission_energy_multiplier = 0.7
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_holo_paint(holo, hm)
	holo.get_meta("arrow").visible = false
	holo.get_meta("ring").visible = false
	holo.visible = false
	level_root.add_child(holo)
	objs["clone"] = holo
	_build_relay_traces()
	var aabb: AABB = bb["box"]
	_build_goal_sparkles(Vector3(L.goal))
	# kamera
	cam_target = aabb.get_center()
	var sz := aabb.size
	_build_pcb(aabb)
	weather.place(cam_target, sz)
	theme_app.bounds = aabb
	theme_app.refresh_props()
	theme_app.paint_robot()
	_update_theme_label()
	cam_size = maxf(9.0, (maxf(sz.x, sz.z) * 0.62 + sz.y * 0.55) * 1.2 + 3.2)
	cam_az = 45.0 + 90.0 * state["view"]
	cam_az_cur = cam_az + 30.0
	cam_zoom = 1.0
	displayed = state
	view_dots.get_meta("pill").visible = not L.phantoms.is_empty()
	_apply_visual(state, state, 1.0)
	_on_resize()
	if not instant and not as_preview:
		_cascade_in()

func _holo_paint(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_holo_paint(c, m)

## Röle devreleri: rölelerden kontrol ettikleri köprüye PCB üstünde bakır iz; devre kapanınca parlar
func _build_relay_traces() -> void:
	objs["traces"] = []
	objs["crelays"] = []
	if L.circuits.is_empty():
		return
	var y := float(L.min_y) - 0.5 - 0.09 + 0.075
	for cid in L.circuits:
		var target = null
		for b in L.bridges:
			if String(b["on"]) == "C:" + cid:
				target = b["cells"][0]
				break
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#6b3c1c")
		mat.metallic = 0.8
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = Color("#3cf08a")
		mat.emission_energy_multiplier = 0.0
		for cell in L.circuits[cid]["cells"]:
			var rc: Vector3i = cell + Vector3i.DOWN
			if cell_nodes.has(rc) and cell_nodes[rc].has_meta("comp"):
				objs["crelays"].append({"n": cell_nodes[rc].get_meta("comp"), "cell": cell, "cid": cid})
			if target == null:
				continue
			var a := Vector3(rc.x, y, rc.z)
			var b2 := Vector3(target.x, y, target.z)
			for seg in [[a, Vector3(b2.x, y, a.z)], [Vector3(b2.x, y, a.z), b2]]:
				var p0: Vector3 = seg[0]
				var p1: Vector3 = seg[1]
				var ln := p0.distance_to(p1)
				if ln < 0.01:
					continue
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(ln + 0.08 if absf(p1.x - p0.x) > 0.01 else 0.08, 0.012, ln + 0.08 if absf(p1.z - p0.z) > 0.01 else 0.08)
				m.mesh = bm
				m.material_override = mat
				m.position = (p0 + p1) / 2.0
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				level_root.add_child(m)
		objs["traces"].append({"cid": cid, "mat": mat})

## Kulenin altındaki baskı devre kartı (PCB) tabanı
func _build_pcb(aabb: AABB) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(aabb.size.x + 6.0, 0.14, aabb.size.z + 6.0)
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/pcb.gdshader")
	# Blender'da pişirilmiş PCB doku seti (varsa ve grafik "Düşük" değilse)
	var dd := AssetLoader.PBR + "pcb_detail/"
	if ComponentFactory.use_models and ResourceLoader.exists(dd + "albedo.png"):
		pm.set_shader_parameter("detail_albedo", load(dd + "albedo.png"))
		pm.set_shader_parameter("detail_normal", load(dd + "normal.png"))
		pm.set_shader_parameter("detail_mask", load(dd + "mask.png"))
		pm.set_shader_parameter("detail_mix", 1.0)
	var m := MeshInstance3D.new()
	m.mesh = bm
	m.material_override = pm
	m.position = Vector3(aabb.get_center().x, float(L.min_y) - 0.5 - 0.09, aabb.get_center().z)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(m)
	objs["pcb"] = pm

## Bir hücredeki devre elemanını parlat (Robo bastı / kondansatör boşaldı)
func _comp_flash(cell_p: Vector3i, param := "glow", strength := 1.0) -> void:
	var cell = cell_nodes.get(cell_p)
	if cell == null or not is_instance_valid(cell) or not cell.has_meta("comp"):
		return
	var comp: Node3D = cell.get_meta("comp")
	var body: MeshInstance3D = comp.get_meta("body")
	var mats: Array = comp.get_meta("glow_mats" if param == "glow" else "charge_mats", [])
	if comp.has_meta("glow_mats"):
		# harici model: bacakların / şarj halkasının emisyonu
		if mats.is_empty():
			return
		var tw2 := _new_tw("cflash:%s:%s" % [cell_p, param], comp)
		tw2.tween_method(func(v: float):
			for m in mats:
				if m is StandardMaterial3D:
					(m as StandardMaterial3D).emission_energy_multiplier = (3.0 if param == "glow" else 6.0) * v, strength, 0.0, 0.7 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	var tw := _new_tw("cflash:%s:%s" % [cell_p, param], body)
	tw.tween_method(func(v: float): body.set_instance_shader_parameter(param, v), strength, 0.0, 0.7 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Yürünebilir üst yüz karo detayı: bloğun üstünde açıkta kalan yüze biraz daha açık, kenarlardan içeri
## çekilmiş ince bir plaka. Aradaki şerit karo çerçevesi gibi okunur; ızgara kareleri anında sayılır.
var _plate_mesh: BoxMesh = null

func _add_tile(p: Vector3i) -> void:
	if L.statics.has(p + Vector3i.UP):
		return
	_tile_plate(level_root, Vector3(p))

func _tile_plate(parent: Node3D, pos: Vector3) -> void:
	if _plate_mesh == null:
		_plate_mesh = _box(Vector3(0.82, 0.014, 0.82))
	var m := _mesh(_plate_mesh, theme_app.block_mat, pos + Vector3(0, 0.503, 0), parent)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

func _build_goal_sparkles(at: Vector3) -> void:
	var pm := CPUParticles3D.new()
	pm.amount = 14
	pm.lifetime = 2.6
	pm.preprocess = 2.6
	pm.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.34
	pm.emission_ring_inner_radius = 0.12
	pm.emission_ring_height = 0.05
	pm.position = at + Vector3(0, -0.35, 0)
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.32
	pm.scale_amount_min = 0.6
	pm.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(1, 0))
	pm.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(pal["accent"]).lerp(Color.WHITE, 0.55)
	m.albedo_color.a = 0.85
	q.material = m
	pm.mesh = q
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(pm)

func _make_robot() -> Node3D:
	var g := Node3D.new()
	var amber := _mat("#ff9a3c", {"rough": 0.55})
	var dark := _mat("#2c2836", {"rough": 0.6})
	# zemine oturan yumuşak gölge lekesi (robotu zeminden ayırır)
	var blob := _mesh(_cyl(0.3, 0.3, 0.005), _mat("#140c28", {"alpha": true, "unshaded": true, "unique": true}), Vector3(0, 0.012, 0), g)
	blob.material_override.albedo_color.a = 0.32
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# vis: Tween'lerle sürülen katman (iniş ezilmesi, çarpma titremesi, zafer dönüşü)
	# pose: her karede hesaplanan katman (nefes, adım esnemesi, dönüş zıplaması). Izgara konumu g'de kalır.
	var vis := Node3D.new()
	g.add_child(vis)
	var pose := Node3D.new()
	vis.add_child(pose)
	var body := _mesh(_rounded_box(Vector3(0.46, 0.42, 0.4), 0.1, 3), amber, Vector3(0, 0.33, 0), pose)
	_mesh(_box(Vector3(0.36, 0.22, 0.04)), _mat("#1e1b27", {"rough": 0.35}), Vector3(0, 0.04, 0.2), body)
	_mesh(_box(Vector3(0.48, 0.05, 0.42)), dark, Vector3(0, -0.12, 0), body)
	var eyes := Node3D.new()
	eyes.position = Vector3(0, 0.05, 0.225)
	body.add_child(eyes)
	var eye_mat := _mat("#6ff6ff", {"emit": 4.0, "unshaded": true, "unique": true})
	for x in [-0.08, 0.08]:
		_mesh(_sphere(0.04), eye_mat, Vector3(x, 0, 0), eyes)
	_mesh(_cyl(0.018, 0.018, 0.16), dark, Vector3(0, 0.62, 0), pose)
	var bulb_mat := _mat("#6ff6ff", {"emit": 4.0, "unique": true})
	_mesh(_sphere(0.05), bulb_mat, Vector3(0, 0.72, 0), pose)
	for x in [-0.12, 0.12]:
		_mesh(_box(Vector3(0.12, 0.1, 0.18)), dark, Vector3(x, 0.06, 0.02), pose)
	for x in [-0.27, 0.27]:
		var cap := CapsuleMesh.new()
		cap.radius = 0.045
		cap.height = 0.22
		_mesh(cap, dark, Vector3(x, 0.3, 0), pose)
	# yön oku ve halka
	var arrow := _mesh(_cyl(0.0, 0.16, 0.02), _mat("#ffffff", {"unshaded": true, "alpha": true, "unique": true}), Vector3(0, 0.03, 0.5), g)
	arrow.rotation.x = PI / 2
	arrow.scale = Vector3(1, 1, 0.12)
	var ring := _mesh(_torus(0.34, 0.4), _mat("#ffffff", {"unshaded": true, "alpha": true, "unique": true}), Vector3(0, 0.02, 0), g)
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override.albedo_color.a = 0.55
	# res://assets/models/robot.glb varsa prosedürel gövde gizlenir, model yerine konur (meta düğümler korunur)
	var rglb := AssetLoader.robot_model()
	if rglb != null:
		for c in pose.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
		pose.add_child(rglb)
		g.set_meta("led_mats", AssetLoader.unique_surfaces(rglb, "RobotLED"))
		var ap := AssetLoader.anim_player(rglb)
		if ap != null:
			g.set_meta("anim", ap)
			ap.play("idle")
	# direnç bekleme göstergesi: başın üstünde dönen şarj halkası
	var wr := _mesh(_torus(0.16, 0.2), _mat("#ffb84d", {"unshaded": true, "unique": true}), Vector3(0, 0.95, 0), g)
	wr.scale = Vector3(1, 0.2, 1)
	wr.visible = false
	g.set_meta("wait_ring", wr)
	g.set_meta("body", body)
	g.set_meta("vis", vis)
	g.set_meta("pose", pose)
	g.set_meta("eyes", eyes)
	g.set_meta("eye_mat", eye_mat)
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

## Işınlayıcı / göz yanılması geçişi mi? Yalnızca yatayda 1 kareden uzağa ya da dikeyde 1 kattan fazla
## sıçrayan hareketler. (Eskiden yatay + dikey toplanıyordu; merdiven adımı 1+1=2 olduğu için ışınlanma
## sanılıp robot küçülüp öbür karede beliriyordu.)
func _jumpy(a, b, sA: Dictionary, sB: Dictionary) -> bool:
	if a == null or b == null or sA["rots"] != sB["rots"] or sA["slides"] != sB["slides"]:
		return false
	return absi(a.x - b.x) + absi(a.z - b.z) > 1 or absi(a.y - b.y) > 1

static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Robotun tabanının yolu. Kat değiştiren adımlarda düz çizgi yerine eğimi izler:
## merdiven çıkarken erken yükselir (basamak kenarının içinden geçmez), inerken merdivenin üstünde kalıp
## sonda alçalır; zıplamada blok kenarını aşan bir yay çizer. Her adımda hafif sekme (adım atma hissi).
func _step_path(pa: Vector3i, pb: Vector3i, t: float) -> Vector3:
	var horiz := Vector3(pa.x, 0, pa.z).lerp(Vector3(pb.x, 0, pb.z), t)
	var dy := pb.y - pa.y
	var y := float(pa.y) - 0.5
	if dy == 0:
		y += absf(sin(TAU * t)) * 0.07
	else:
		var below_a = L.statics.get(pa + Vector3i.DOWN)
		var below_b = L.statics.get(pb + Vector3i.DOWN)
		var stair: bool = (dy > 0 and below_b != null and below_b["t"] == "s") or (dy < 0 and below_a != null and below_a["t"] == "s")
		if stair:
			var k := _smooth(0.0, 0.72, t) if dy > 0 else _smooth(0.3, 1.0, t)
			y += dy * k + absf(sin(TAU * t)) * 0.06
		else:
			var k2 := _smooth(0.0, 0.55, t) if dy > 0 else _smooth(0.45, 1.0, t)
			y += dy * k2 + sin(PI * t) * 0.32
	return Vector3(horiz.x, y, horiz.z)

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
			if pa != null and pb != null and pa != pb and not carried and absi(pa.x - pb.x) + absi(pa.z - pb.z) == 1:
				pl.position = _step_path(pa, pb, te)
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
			if m.has_meta("glb"):
				m.visible = v > 0.02
				m.scale = Vector3(1, maxf(0.05, v), 1)
				continue
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
		for lm in objs["plates"][i].get_meta("led", []):
			(lm as StandardMaterial3D).emission_energy_multiplier = 3.5 if down else 0.0
	_apply_circuit_visual(sA, sB, te)
	for r in objs["relays"]:
		ComponentFactory.set_relay(r["n"], bool(sB["relays"][r["ri"]]) if sB.has("relays") else false)
	for o in objs["links"]:
		o["m"].material_override.albedo_color.a = 0.95 if sB["view"] == o["view"] else 0.22
	if not objs["phantoms"].is_empty():
		for k in 4:
			var sb := StyleBoxFlat.new()
			var cur: bool = k == int(sB["view"])
			sb.bg_color = VIEW_COLS[k] if cur else Color(VIEW_COLS[k], 0.3)
			sb.set_corner_radius_all(8)
			if cur:
				sb.border_color = Color.WHITE
				sb.set_border_width_all(2)
			view_dots.get_child(k).add_theme_stylebox_override("panel", sb)
	for o in objs["phantoms"]:
		var on := lerpf(1.0 if int(sA["view"]) in o["views"] else 0.0, 1.0 if int(sB["view"]) in o["views"] else 0.0, te)
		for e in o["ms"]:
			var mm: StandardMaterial3D = e["m"].material_override
			mm.albedo_color = Color(o["col"]).lerp(Color("#f4f1ea"), 0.35 * on)
			mm.albedo_color.a = 0.12 + 0.83 * on
			mm.emission_energy_multiplier = 0.25 * on
			e["m"].scale = Vector3.ONE * (0.9 + 0.1 * on)
			e["m"].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on > 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(e["edge"].material_override as StandardMaterial3D).albedo_color.a = 0.16 * (1.0 - on)

## Klon, bekleme halkası, röle devre izleri
func _apply_circuit_visual(sA: Dictionary, sB: Dictionary, te: float) -> void:
	var pl: Node3D = objs["player"]
	(pl.get_meta("wait_ring") as Node3D).visible = int(sB.get("wait", 0)) > 0 and not sB["dead"]
	var cn: Node3D = objs.get("clone")
	if cn != null:
		var ca: Dictionary = sA.get("clone", {})
		var cb: Dictionary = sB.get("clone", {})
		cn.visible = not cb.is_empty()
		if not cb.is_empty():
			var same: bool = not ca.is_empty() and ca.get("gen", 0) == cb.get("gen", 0)
			var a0: Vector3i = ca["p"] if same else cb["p"]
			var b0: Vector3i = cb["p"]
			if a0 != b0 and absi(a0.x - b0.x) + absi(a0.z - b0.z) == 1 and absi(a0.y - b0.y) <= 1:
				cn.position = _step_path(a0, b0, te)
			else:
				cn.position = Vector3(a0).lerp(Vector3(b0), te) + Vector3(0, -0.5 + sin(PI * te) * 0.3 * float(a0 != b0), 0)
			var fa := Vector3(DIRS[int(ca.get("f", cb["f"])) if same else int(cb["f"])])
			var fb := Vector3(DIRS[int(cb["f"])])
			var from := atan2(fa.x, fa.z)
			cn.rotation.y = from + wrapf(atan2(fb.x, fb.z) - from, -PI, PI) * te
	var circ: Dictionary = sB.get("circuits", {})
	for t in objs.get("traces", []):
		var on: bool = circ.get(t["cid"], false)
		var m: StandardMaterial3D = t["mat"]
		m.emission_energy_multiplier = 1.8 if on else 0.0
		m.albedo_color = Color("#3cf08a") if on else Color("#6b3c1c")
	for r in objs.get("crelays", []):
		var pressed: bool = (not sB["dead"] and sB["p"] == r["cell"]) or (not sB.get("clone", {}).is_empty() and sB["clone"]["p"] == r["cell"])
		ComponentFactory.set_relay(r["n"], pressed or circ.get(r["cid"], false))
		ComponentFactory.set_contact(r["n"], pressed)

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
		d = {"F": 0.34, "J": 0.4, "L": 0.22, "R": 0.22, "A": 0.3, "rot": 0.42, "slide": 0.26, "view": 0.0, "bump": 0.26, "wait": 0.4, "C": 0.4, "clone": 0.3}.get(kind, 0.3)
		if kind == "A" and a["rots"] != b["rots"]:
			d = 0.5
	elif a == b:
		d = 0.38   # direnç: Robo bir adım bekler
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
		queue.append({"from": prev, "to": f, "dur": _frame_dur(prev, f, k == 0, kind), "t": 0.0, "bump": bump and k == 0, "first": k == 0, "kind": kind})
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
			if not instant:
				_sound_for(anim)
				_comp_events(anim)
				if anim["bump"]:
					_robot_shake()
		anim["t"] += dt / anim["dur"] if anim["dur"] > 0 else 1.0
		dt = 0.0
		if anim["t"] >= 1.0:
			_apply_visual(anim["from"], anim["to"], 1.0)
			displayed = anim["to"]
			var done: Dictionary = anim
			anim = null
			if done.get("first", false) and not done["bump"] and String(done.get("kind", "")) in ["F", "J"] \
					and not done["to"]["dead"] and done["from"]["p"] != done["to"]["p"]:
				_robot_land(done["to"]["p"])
			if not instant and queue.size() > 0:
				return
		else:
			_apply_visual(anim["from"], anim["to"], anim["t"], anim["bump"])
			return

## Devre elemanı olayları: kondansatör fırlatması, direnç beklemesi, röle devresi
func _comp_events(a: Dictionary) -> void:
	var sa: Dictionary = a["from"]
	var sb: Dictionary = a["to"]
	if sa.get("circuits", {}) != sb.get("circuits", {}) or sa.get("relays", []) != sb.get("relays", []):
		Sfx.call_ah("relay")
	if String(a.get("kind", "")) == "wait" and not sb["dead"]:
		_comp_flash(Vector3i(sb["p"]) + Vector3i.DOWN, "glow", 0.8)
	if a.get("first", false) or sa["dead"] or sb["dead"]:
		return
	var below: Vector3i = sa["p"] + Vector3i.DOWN
	var c: Dictionary = L.comps.get(below, {})
	if c.get("t", "") == "cap" and sa["p"] != sb["p"]:
		_comp_flash(below, "charge", 1.0)
		Sfx.call_ah("cap_launch")
	elif c.get("t", "") == "res" and sa == sb:
		_comp_flash(below, "glow", 0.7)

func _sound_for(a: Dictionary) -> void:
	var sa: Dictionary = a["from"]
	var sb: Dictionary = a["to"]
	if a["bump"]:
		pass   # hata sesi _bump_fx'te (AudioHaptics)
	elif a.get("first", false):
		match a.get("kind", ""):
			"F", "J":
				if sa["p"] != sb["p"]:
					Sfx.call_ah("step", [int(sb["p"].y) - L.min_y])
			"C":
				audio.play("whoosh", 1.4)
			"L", "R": audio.play("turn")
			"rot", "slide": audio.play("mech")
			"A":
				if sa["crates"] != sb["crates"]:
					audio.play("push")
				elif sa["rots"] != sb["rots"]:
					audio.play("mech")
				else:
					audio.play("click")
	if sa["bridges"] != sb["bridges"]:
		audio.play("bridge")
	if sa["levers"] != sb["levers"] and not a.get("first", false):
		audio.play("click")
	for i in sb["crumbles"].size():
		if sb["crumbles"][i] != 0 and sa["crumbles"][i] == 0:
			audio.play("crumble")
	if sb["dead"] and not sa["dead"]:
		audio.play("fail")

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
	var pre: Dictionary = state
	# bir tur: önce klon (F1), sonra ana Robo; direnç bekletmesi bir tur yer
	var t := Program.tick(L, state, run_ctx)
	var n = t["n"]
	if not t["wait"]:
		_mark_exec(n, runner.skipped)
	if t["ended"]:
		state = t["state"]
		if not (t["frames"] as Array).is_empty():
			_enqueue(t["frames"], "clone")
		if L.is_win(state):
			return true
		_end_run(t["reason"])
		return false
	if t["wait"]:
		state = t["state"]
		_enqueue(t["frames"], "wait")
		return true
	if not run_log.has("faced"):
		var fk := Nova.front_object(L, pre)
		if fk != "":
			run_log["faced"] = fk
	if n["ins"]["c"] == "A":
		run_log["used_A"] = true
	run_log["last"] = {"proc": n["proc"], "idx": n["idx"], "c": n["ins"]["c"]}
	if t["bump"]:
		run_log["bumps"] = int(run_log.get("bumps", 0)) + 1
		if run_log.get("first_bump") == null:
			run_log["first_bump"] = run_log["last"]
	if str(step_once) == "true":
		step_once = "done"
	if t["pause"]:
		state = t["state"]
		step_once = false
		_set_mode("paused")
		return false
	if t["bump"]:
		state = t["state"]
		_bump_fx(pre, n["ins"]["c"])
		_enqueue([state], "bump", true)
		return true
	if n["ins"]["c"] in ["F", "J"] and not instant:
		var dot := _mesh(_cyl(0.11, 0.11, 0.01), _mat(pal["accent"], {"unshaded": true}), Vector3(pre["p"]) + Vector3(0, -0.47, 0), objs["trail"])
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	state = t["state"]
	_enqueue(t["frames"], n["ins"]["c"])
	return true

## Çarpma tepkisi: diyota ters yönden girilmeye çalışıldıysa kırmızı kısa devre kıvılcımı; her durumda hata sesi
func _bump_fx(pre: Dictionary, c: String) -> void:
	if instant:
		return
	Sfx.call_ah("error")
	if c == "F" and L.diode_blocked(pre):
		var at := Vector3(pre["p"]) + Vector3(DIRS[pre["f"]]) * 0.5 + Vector3(0, -0.35, 0)
		_spark(at, Color("#ff3b3b"))

func _spark(at: Vector3, col: Color) -> void:
	var pm := CPUParticles3D.new()
	pm.one_shot = true
	pm.explosiveness = 1.0
	pm.amount = 26
	pm.lifetime = 0.45
	pm.position = at
	pm.direction = Vector3.UP
	pm.spread = 160.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(0, -6.0, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col.lightened(0.3)
	q.material = m
	pm.mesh = q
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(pm)
	pm.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(pm): pm.queue_free())

func _start_run(step := false) -> void:
	if Program.block_count(prog) == 0:
		_toast("Önce programa blok ekle")
		return
	if mode == "ended":
		_reset_to_setup()
	sel = null
	setup_state = PuzzleLogic.clone(state)
	var pp := Program.parse_program(Program.program_to_src(prog))
	run_ctx = {"prog": pp, "main": Program.Runner.new(pp), "clone": null, "gen": -1}
	runner = run_ctx["main"]
	for c in objs["trail"].get_children():
		c.queue_free()
	step_once = "true" if step else false
	run_log = {"last": null, "first_bump": null, "bumps": 0}
	_hide_hint()
	_hide_nova()
	audio.play("run")
	_set_mode("running")

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
	_robot_reset()
	_gem_restore()
	runner = null
	_apply_visual(state, state, 1.0)
	_sync_view()
	for c in objs["trail"].get_children():
		c.queue_free()
	_set_mode("edit")

func _end_run(reason: String) -> void:
	end_reason = reason
	if not instant and reason != "dead":
		audio.play("fail")
	_set_mode("ended")
	if reason != "dead":
		_robot_shake()
	_nova_analyze(reason)

## Nova başarısız çalıştırmayı analiz eder, açıklar ve sorunlu bloğu seçip vurgular.
func _nova_analyze(reason: String) -> void:
	var a := Nova.analyze(L, prog, state, reason, run_log)
	if instant:
		nova_card.set_meta("last", a)
		return
	lbl_nova_title.text = String(a["title"]).to_upper()
	lbl_nova.text = a["text"]
	var f = a["focus"]
	if f != null and int(f["idx"]) < prog[f["row"]].size():
		sel = {"row": f["row"], "idx": int(f["idx"])}
		active_row = f["row"]
		_render_rows()
	hint_card.visible = false
	get_tree().create_timer(0.45).timeout.connect(func():
		if mode == "ended" and _current == "":
			nova_card.visible = true
			_layout()
			UIKit.pop_in(nova_card, 0.0, 0.7)
			# sorunlu bloğu sallayarak göster (yerleşim oturduktan sonra)
			if f != null and sel != null and sel["row"] == f["row"] and sel["idx"] == int(f["idx"]):
				var tiles: Array = tile_nodes.get(f["row"], [])
				if int(f["idx"]) < tiles.size():
					UIKit.shake(tiles[int(f["idx"])]))

func _hide_nova() -> void:
	if nova_card != null:
		nova_card.visible = false

func _set_mode(m: String, quiet := false) -> void:
	mode = m
	_ui_mode_changed(m, quiet)
	if objs.has("player"):
		var pl: Node3D = objs["player"]
		pl.get_meta("arrow").visible = m != "running"
		pl.get_meta("ring").visible = m != "running"
		_apply_led_color()
	if m == "edit":
		_mark_exec(null, [])
	_update_hud()


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
		audio.play("whoosh")
		return true
	if not L.phantoms.is_empty() and _can_edit_world():
		_toast("Bu açıda bir hayalet blok Robo'nun ya da kutunun içinde belirirdi")
		UIKit.shake(view_dots.get_meta("pill"))
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
# Game feel: prosedürel animasyonlar (Faz 3). Tüm süreler hız çarpanına bölünür; her animasyon
# isimli bir tween kullanır ve yenisi başlamadan öncekini kill() eder (hızlı mod/Durdur/Sıfırla güvenli).
func _kill_tw(key: String) -> void:
	var t = _tw.get(key)
	if t != null and is_instance_valid(t):
		t.kill()
	_tw.erase(key)

func _new_tw(key: String, node: Node) -> Tween:
	_kill_tw(key)
	var t := node.create_tween()
	_tw[key] = t
	return t

func _kill_all_tweens() -> void:
	for k in _tw.keys():
		_kill_tw(k)
	_deleting = false

## Robotun Tween katmanını (vis) temizler ve nötr pozisyona döndürür.
func _robot_reset() -> void:
	for k in ["robot", "robot_spin", "robot_shake"]:
		_kill_tw(k)
	if objs.has("player"):
		var vis: Node3D = objs["player"].get_meta("vis")
		vis.transform = Transform3D.IDENTITY

## Bölüm açılışı: bloklar alttan üste, ızgara sırasıyla kısa gecikmelerle yaylanarak yerine oturur (≤ 0,8 sn).
func _cascade_in() -> void:
	var items := []
	for p in cell_nodes:
		items.append({"n": cell_nodes[p], "k": p.y * 1000 + p.x + p.z, "slide": true})
	for c in objs["crumbles"]:
		items.append({"n": c, "k": int(c.position.y) * 1000 + int(c.position.x + c.position.z), "slide": true})
	for rg in objs["rotators"]:
		items.append({"n": rg, "k": 999999, "slide": false})
	for sg in objs["sliders"]:
		items.append({"n": sg, "k": 999999, "slide": false})
	items.sort_custom(func(a, b): return a["k"] < b["k"])
	var n := items.size()
	if n == 0:
		return
	var stagger := clampf(0.45 / n, 0.006, 0.035)
	var tw := _new_tw("cascade", level_root).set_parallel(true)
	for i in n:
		var nd: Node3D = items[i]["n"]
		var d := i * stagger
		var target_s := nd.scale
		nd.scale = Vector3.ONE * 0.01
		tw.tween_property(nd, "scale", target_s, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		if items[i]["slide"]:
			var y := nd.position.y
			nd.position.y = y - 0.6
			tw.tween_property(nd, "position:y", y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
	# robot ve kristal en son belirir
	var vis: Node3D = objs["player"].get_meta("vis")
	vis.scale = Vector3.ONE * 0.01
	var end := minf(0.5, (n - 1) * stagger) + 0.12
	tw.tween_property(vis, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(end)
	var gem: Node3D = objs["gem"]
	var gs := gem.scale
	gem.scale = Vector3.ONE * 0.01
	tw.tween_property(gem, "scale", gs, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(end + 0.05)

## İniş ezilmesi + basılan bloğun yaylanması
func _robot_land(at: Vector3i) -> void:
	if instant or not objs.has("player"):
		return
	var sp := _speed()
	var vis: Node3D = objs["player"].get_meta("vis")
	var tw := _new_tw("robot", vis)
	tw.tween_property(vis, "scale", Vector3(1.12, 0.88, 1.12), 0.08 / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(vis, "scale", Vector3.ONE, 0.2 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tile_bounce(at + Vector3i.DOWN)
	_comp_flash(at + Vector3i.DOWN)
	if objs.has("pcb"):
		var pm: ShaderMaterial = objs["pcb"]
		pm.set_shader_parameter("pulse_pos", Vector3(at))
		var ptw := _new_tw("pcb_pulse", level_root)
		ptw.tween_method(func(v: float): pm.set_shader_parameter("pulse", v), 1.0, 0.0, 0.9)
	if theme_app:
		theme_app.pulse_step()

func _tile_bounce(p: Vector3i) -> void:
	var cell = cell_nodes.get(p)
	if cell == null or not is_instance_valid(cell):
		return
	var sp := _speed()
	var base := float(p.y)
	var tw := _new_tw("tile:%s" % p, cell)
	tw.tween_property(cell, "position:y", base - 0.05, 0.06 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cell, "position:y", base, 0.12 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Çarpma / hata: yanlara kısa titreme (öne sekme _apply_visual'da yapılır)
func _robot_shake() -> void:
	if instant or not objs.has("player"):
		return
	var sp := _speed()
	var vis: Node3D = objs["player"].get_meta("vis")
	vis.position.x = 0.0
	var tw := _new_tw("robot_shake", vis)
	for k in [0.07, -0.06, 0.04, -0.02, 0.0]:
		tw.tween_property(vis, "position:x", k, 0.045 / sp).set_trans(Tween.TRANS_SINE)

## Zafer: 360° sevinç dönüşü ve iki zıplama
func _robot_victory() -> void:
	if instant or not objs.has("player"):
		return
	_robot_reset()
	objs["player"].set_meta("victory_until", time + 1.2)
	var vis: Node3D = objs["player"].get_meta("vis")
	var spin := _new_tw("robot_spin", vis)
	spin.tween_property(vis, "rotation:y", TAU, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var hop := _new_tw("robot", vis)
	hop.tween_property(vis, "position:y", 0.42, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(vis, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_property(vis, "scale", Vector3(1.12, 0.88, 1.12), 0.06)
	hop.tween_property(vis, "scale", Vector3.ONE, 0.1)
	hop.tween_property(vis, "position:y", 0.26, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(vis, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_property(vis, "scale", Vector3(1.08, 0.92, 1.08), 0.05)
	hop.tween_property(vis, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hop.tween_callback(func(): vis.rotation.y = 0.0)

## Kristal toplanır: büyüyüp parlar, küçülüp kaybolur, parçacık patlaması
func _gem_collect() -> void:
	if instant:
		return
	objs["gem_taken"] = true
	var gem: Node3D = objs["gem"]
	var gs := Vector3(1, 1.35, 1)
	var tw := _new_tw("gem", gem)
	tw.tween_property(gem, "scale", gs * 1.5, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gem, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var gl: OmniLight3D = objs["gem_light"]
	var lt := _new_tw("gem_light", gl)
	lt.tween_property(gl, "light_energy", 5.0, 0.14)
	lt.tween_property(gl, "light_energy", 0.0, 0.5)
	var ring: MeshInstance3D = objs["goal_ring"]
	var rt := _new_tw("gem_ring", ring)
	rt.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.4)
	var pm := CPUParticles3D.new()
	pm.one_shot = true
	pm.explosiveness = 1.0
	pm.amount = 36
	pm.lifetime = 0.9
	pm.position = Vector3(L.goal) + Vector3(0, 0.15, 0)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -5.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	pm.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	pm.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(pal["accent"]))
	pm.color_initial_ramp = grad
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(pm)
	pm.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(pm): pm.queue_free())

## Tekrar denemede kristali geri getirir
func _gem_restore() -> void:
	if not objs.get("gem_taken", false):
		return
	objs["gem_taken"] = false
	for k in ["gem", "gem_light", "gem_ring"]:
		_kill_tw(k)
	objs["gem"].scale = Vector3(1, 1.35, 1)
	objs["goal_ring"].material_override.albedo_color.a = 0.8

## Robotun her karede hesaplanan pozu: hareket sırasında esneme / dönüşte zıplama, boşta nefes.
func _robot_pose() -> void:
	var pl: Node3D = objs["player"]
	var pose: Node3D = pl.get_meta("pose")
	var st := Vector3.ONE
	var hop := 0.0
	if anim != null and anim.get("first", false) and not anim["bump"]:
		var t := clampf(anim["t"], 0.0, 1.0)
		match String(anim.get("kind", "")):
			"F", "J":
				var a = anim["from"]["p"]
				var b = anim["to"]["p"]
				if a != b and not anim["to"]["dead"]:
					st = Vector3.ONE.lerp(Vector3(0.92, 1.12, 0.92), sin(PI * t))
			"L", "R":
				hop = 0.18 * 4.0 * t * (1.0 - t)
	elif anim == null and queue.is_empty():
		var br := (sin(time * 2.4) + 1.0) * 0.5
		st = Vector3(1.0 - 0.02 * br, 1.0 + 0.04 * br, 1.0 - 0.02 * br)
	pose.scale = st
	pose.position.y = hop
	_robot_clip(pl)
	var bm: StandardMaterial3D = pl.get_meta("bulb")
	bm.emission_energy_multiplier = 3.2 + sin(time * 3.2) * 1.4

## İskeletli robot modelinin klibi komut / duruma göre: yürü (F/J), dön (L/R), düş (ölüm), zafer, boşta nefes +
## ara sıra etrafa bakınma. Model yoksa (prosedürel robot) hiçbir şey yapmaz.
func _robot_clip(pl: Node3D) -> void:
	var ap: AnimationPlayer = pl.get_meta("anim", null)
	if ap == null:
		return
	var want := "idle"
	var spd := _speed()
	if pl.get_meta("victory_until", 0.0) > time:
		want = "victory"
		spd = 1.0
	elif anim != null:
		match String(anim.get("kind", "")):
			"F", "J":
				want = "fall" if anim["to"]["dead"] else "walk"
			"L", "R":
				want = "turn"
			_:
				want = "idle"
	elif queue.is_empty() and fmod(time, 9.0) > 6.5:
		want = "look"
	if ap.current_animation != want:
		ap.play(want, 0.12, spd)
	else:
		ap.speed_scale = spd

# =====================================================================
# Bilgisayar toplama: parçalar, montaj sahnesi ve vitrin
func _parts() -> Array:
	return progress["unlocked_parts"]

func _unlock_part(id: int) -> bool:
	if id < 1 or id > PCPartLibrary.COUNT or id in _parts():
		return false
	progress["unlocked_parts"].append(id)
	return true

func _update_pc_buttons() -> void:
	var txt := "Bilgisayarım (%d/%d)" % [_parts().size(), PCPartLibrary.COUNT]
	for b in [btn_pc_title, btn_pc_pause]:
		if b != null:
			UIKit.set_text(b, txt)

## mode: "assembly" (yeni parçanın 8 sn montajı) ya da "showcase" (Bilgisayarım)
func _open_assembly(m: String, pid := 0) -> void:
	if assembly != null:
		return
	if asm_layer == null:
		asm_layer = CanvasLayer.new()
		asm_layer.layer = 40
		add_child(asm_layer)
	_asm_return = _current
	assembly = ASSEMBLY_SCENE.instantiate()
	asm_layer.add_child(assembly)
	if m == "final":
		var all := []
		for i in range(1, PCPartLibrary.COUNT + 1):
			all.append(i)
		assembly.real_parts = _parts().duplicate()
		assembly.setup("assembly", all, 100)
		assembly.start_final(true)
	else:
		assembly.real_parts = _parts().duplicate()
		assembly.setup(m, _parts(), pid)
	assembly.next_level.connect(_assembly_next)
	assembly.closed.connect(_close_assembly)
	assembly.test_requested.connect(_assembly_test)
	assembly.main_menu.connect(func():
		_close_assembly()
		win_shown = false
		_show_title())
	# arkadaki oyun dünyası görünmezken çizilmesin
	get_viewport().disable_3d = true
	if hud:
		hud.visible = false
	assembly.modulate.a = 0.0
	assembly.create_tween().tween_property(assembly, "modulate:a", 1.0, 0.35)
	audio.play("whoosh")

func _close_assembly() -> void:
	if assembly == null:
		return
	assembly.queue_free()
	assembly = null
	get_viewport().disable_3d = false
	_update_pc_buttons()
	if win_shown:
		_show("win")
	else:
		_show(_asm_return)

## Montaj bitti: oyundan gelindiyse sonraki seviye, vitrinden test edildiyse vitrine dönüş
func _assembly_next() -> void:
	if assembly == null:
		return
	if assembly.from_showcase:
		assembly.from_showcase = false
		assembly.setup("showcase", _parts())
		return
	var nxt := mini(levels.size() - 1, level_idx + 1)
	assembly.queue_free()
	assembly = null
	get_viewport().disable_3d = false
	win_shown = false
	_start_level(nxt)

## Geliştirici kısayolu: sıradaki parçayı aç ve montajını hemen oynat
func _assembly_test() -> void:
	var nid := 0
	for i in range(1, PCPartLibrary.COUNT + 1):
		if not (i in _parts()):
			nid = i
			break
	if nid == 0:
		_toast("Bütün parçalar zaten takılı")
		return
	_unlock_part(nid)
	_save_progress()
	assembly.from_showcase = true
	assembly.setup("assembly", _parts(), nid)

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
	var part_id := level_idx + 1
	var new_part := _unlock_part(part_id)
	_save_progress()
	if not instant:
		_confetti(Vector3(L.goal))
		_gem_collect()
		_robot_victory()
		audio.play("win")
	_prepare_win(stars, blocks, par)
	if instant:
		_show("win")
	elif new_part:
		# yeni parça kazanıldı: zafer anından sonra 8 saniyelik montaj sahnesi
		get_tree().create_timer(1.4).timeout.connect(func(): if win_shown: _open_assembly("assembly", part_id))
	else:
		get_tree().create_timer(1.2).timeout.connect(func(): if win_shown: _show("win"))

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
	if theme_app:
		theme_app.tick(dt)
	if cam_spin:
		cam_az += dt * 7.0
	cam_az_cur += (cam_az - cam_az_cur) * minf(1.0, dt * 8.0)
	var a := deg_to_rad(cam_az_cur)
	cam.position = cam_target + Vector3(cos(EL) * cos(a), sin(EL), cos(EL) * sin(a)) * 60.0
	cam.look_at(cam_target, Vector3.UP)
	var vsz := get_viewport().get_visible_rect().size
	weather.set_view(deg_to_rad(cam_az_cur), vsz.x / maxf(vsz.y, 1.0), Vector2(get_viewport().size))
	var want_size := cam_size / cam_zoom * (1.02 if portrait else 1.0)
	cam.size = lerpf(cam.size, want_size, minf(1.0, dt * 8.0))
	_update_offset()
	if hud != null and hud.visible:
		var safe_now := _safe_margins()
		if safe_now != _safe_applied:
			_layout()
		else:
			_fit_panel()
	if L != null and objs.has("player"):
		_update_queue(dt)
		var gem: MeshInstance3D = objs["gem"]
		gem.rotation.y = time * (1.6 if not objs.get("gem_taken", false) else 9.0)
		gem.position.y = L.goal.y + 0.1 + sin(time * 2.4) * 0.07
		objs["goal_ring"].scale = Vector3(1, 0.1, 1) * (1.0 + sin(time * 3.0) * 0.08)
		_robot_pose()
		var pl: Node3D = objs["player"]
		pl.get_meta("body").position.y = 0.33 + sin(time * 4.0) * 0.012
		pl.get_meta("eyes").scale.y = 0.15 if fmod(time, 3.7) < 0.12 else 1.0
		(pl.get_meta("wait_ring") as Node3D).rotation.y = time * 6.0
		for p in objs["portals"]:
			p["ring"].rotation.y = time * 1.4
		if not objs.get("gem_taken", false):
			var gl: OmniLight3D = objs["gem_light"]
			gl.light_energy = 1.3 + sin(time * 2.4) * 0.25

## Sahne, program panelinin kaplamadığı alana ortalanır (yatayda sağ panel, dikeyde alt panel).
func _update_offset() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0:
		return
	if portrait:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		var ph := (vs.y - panel.position.y) if hud.visible and panel != null else 0.0
		var top_h := (top_bar.position.y + top_bar.size.y + 12.0) if hud.visible and top_bar != null else 0.0
		cam.h_offset = 0.0
		cam.v_offset = -(ph - top_h) * 0.5 * cam.size / vs.x
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		var px := (vs.x - panel.position.x) * 0.5 if hud.visible and panel != null else 0.0
		cam.v_offset = 0.0
		cam.h_offset = px * cam.size / vs.y

func _on_resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.x < vs.y * 0.95
	if ui_root != null:
		_layout()

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
			KEY_S: _reset_to_setup()
			KEY_ESCAPE: _on_back()
			KEY_Q: _rotate_view(-1)
			KEY_E: _rotate_view(1)
			KEY_UP: _insert("F")
			KEY_LEFT: _insert("L")
			KEY_RIGHT: _insert("R")
			KEY_BACKSPACE:
				if sel != null:
					_delete_sel()
			KEY_BRACKETLEFT:
				if _current == "":
					_cycle_theme(-1)
			KEY_BRACKETRIGHT:
				if _current == "":
					_cycle_theme(1)

## Android geri tuşu: açık kart / ipucu / seçim kapanır → oyun duraklatılır → seviyeler → başlık → çıkış
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

func _on_back() -> void:
	if assembly != null:
		if assembly.mode == "assembly" and not assembly.finished:
			assembly._skip()
		elif assembly.mode == "assembly" and not assembly.from_showcase:
			_assembly_next()
		else:
			_close_assembly()
		return
	if _current in ["intro", "backup", "settings"]:
		if _current == "settings":
			_close_settings()
		elif _current == "backup":
			_show("settings")
		else:
			_show("")
	elif hint_card.visible:
		_hide_hint()
	elif nova_card.visible:
		_hide_nova()
	elif sel != null and _current == "":
		sel = null
		_render_rows()
	elif _current == "":
		_open_pause()
	elif _current == "pause":
		_show("")
	elif _current in ["win", "levels"]:
		if _current == "levels":
			_show_title()
		else:
			_open_levels()
	else:
		get_tree().quit()

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
# Arayüz — modern mobil oyun tasarım dili: kalın "basılabilir" butonlar, cam kartlar,
# vektör ikonlar, yaylı animasyonlar. Dikey ve yatay ekrana uyumlu (_layout).
func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 1
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UIKit.make_theme()
	ui.add_child(ui_root)
	# hafif vinyet (kenarlar yumuşakça koyulaşır)
	var vig := TextureRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	var vt := GradientTexture2D.new()
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.45)
	vt.fill_to = Vector2(1.15, 1.1)
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0))
	vg.set_color(1, Color(0.12, 0.05, 0.25, 0.1))
	vt.gradient = vg
	vig.texture = vt
	ui_root.add_child(vig)
	_build_hud()
	_build_screens()
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)
	var fx_root := Control.new()
	fx_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_root.theme = ui_root.theme
	fx_layer.add_child(fx_root)
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(1, 1, 1, 0)
	fx_root.add_child(veil)
	lbl_toast = UIKit.label("", 20, Color.WHITE, UIKit.font_bold)
	toast_pill = UIKit.pill(lbl_toast, Color("#3a3152e8"), 16)
	toast_pill.visible = false
	fx_root.add_child(toast_pill)


# ---------- oyun içi ekran ----------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)
	# üst şerit: yalnızca okunan başlık ve yıldızlar (dokunulan düğmeler alt panelde)
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.position = Vector2(16, 14)
	hud.add_child(top_bar)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	lbl_chap = UIKit.label("", 14, UIKit.INK_SOFT, UIKit.font_black)
	lbl_name = UIKit.label("", 28, UIKit.INK, UIKit.font_black)
	lbl_chap.clip_text = true
	lbl_name.clip_text = true
	lbl_chap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for l in [lbl_chap, lbl_name]:
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.75))
		l.add_theme_constant_override("outline_size", 6)
	tv.add_child(lbl_chap)
	tv.add_child(lbl_name)
	top_bar.add_child(tv)
	var sc := HBoxContainer.new()
	sc.add_theme_constant_override("separation", 6)
	lbl_blocks = UIKit.label("", 20, UIKit.INK, UIKit.font_black)
	sc.add_child(lbl_blocks)
	mini_stars = HBoxContainer.new()
	mini_stars.add_theme_constant_override("separation", 1)
	for k in 3:
		var st := UIKit.Icon.new()
		st.kind = "star"
		st.color = UIKit.GOLD
		st.custom_minimum_size = Vector2(22, 22)
		mini_stars.add_child(st)
	sc.add_child(mini_stars)
	top_bar.add_child(UIKit.pill(sc))
	# durum bandı (mola / hata)
	lbl_status = UIKit.label("", 19, Color.WHITE, UIKit.font_bold)
	status_pill = UIKit.pill(lbl_status, Color("#e8648aee"), 16)
	status_pill.visible = false
	hud.add_child(status_pill)
	# ipucu balonu
	hint_card = UIKit.card(0.96, 24, 18)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 12)
	var hb := UIKit.Icon.new()
	hb.kind = "bulb"
	hb.color = Color("#e0a21a")
	hb.custom_minimum_size = Vector2(34, 34)
	hh.add_child(hb)
	lbl_hint = UIKit.label("", 19)
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.custom_minimum_size = Vector2(380, 0)
	hh.add_child(lbl_hint)
	hint_card.add_child(hh)
	hint_card.visible = false
	hint_card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _hide_hint())
	hud.add_child(hint_card)
	# Nova: yapay zekâ öğretmeninin analiz balonu
	nova_card = UIKit.card(0.97, 24, 16)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 12)
	nh.add_child(UIKit.nova_avatar(48))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 2)
	lbl_nova_title = UIKit.label("", 14, Color("#6a4cff"), UIKit.font_black)
	nv.add_child(lbl_nova_title)
	lbl_nova = UIKit.label("", 18)
	lbl_nova.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_nova.custom_minimum_size = Vector2(360, 0)
	nv.add_child(lbl_nova)
	nh.add_child(nv)
	nova_card.add_child(nh)
	nova_card.visible = false
	nova_card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _hide_nova())
	hud.add_child(nova_card)
	# bakış açısı göstergesi (yalnızca hayalet bloklu seviyelerde)
	view_dots = HBoxContainer.new()
	view_dots.add_theme_constant_override("separation", 6)
	for k in 4:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		view_dots.add_child(d)
	var vp := UIKit.pill(view_dots, Color(1, 1, 1, 0.85), 10)
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vp)
	view_dots.set_meta("pill", vp)
	_build_panel()

func _build_panel() -> void:
	panel = UIKit.frosted_panel(20, 14)
	hud.add_child(panel)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)
	var pv := panel_box
	# Fonksiyon sekmeleri kaydırmanın DIŞINDA: satır taşınca da kesilmez ve her biri seçilebilir.
	row_tabs = HBoxContainer.new()
	row_tabs.add_theme_constant_override("separation", 8)
	row_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(row_tabs)
	rows_scroll = ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.clip_contents = true
	pv.add_child(rows_scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 8)
	rows_scroll.add_child(rows_box)
	# satırlar değişince panel yüksekliği içeriğe göre yeniden hesaplanır
	rows_box.minimum_size_changed.connect(func(): _layout.call_deferred())
	palette_scroll = ScrollContainer.new()
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	palette_scroll.custom_minimum_size = Vector2(0, 64)
	palette_box = HBoxContainer.new()
	palette_box.alignment = BoxContainer.ALIGNMENT_CENTER
	palette_box.add_theme_constant_override("separation", 8)
	palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.add_child(palette_box)
	# seçili blok araçları
	sel_bar = HBoxContainer.new()
	sel_bar.add_theme_constant_override("separation", 8)
	sel_bar.add_child(UIKit.round_button("back", func(): _move_sel(-1), 50, Color("#f1ecfb")))
	btn_cond = UIKit.button("Her zaman", Color("#f1ecfb"), _cycle_cond, 17, "", UIKit.INK, 50)
	btn_cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cond.clip_text = true
	btn_cond.custom_minimum_size = Vector2(80, 50)
	(btn_cond.get_meta("label") as Label).clip_text = true
	(btn_cond.get_meta("label") as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sel_bar.add_child(btn_cond)
	var fwd := UIKit.round_button("back", func(): _move_sel(1), 50, Color("#f1ecfb"))
	var fic: Control = fwd.get_meta("icon")
	fic.scale = Vector2(-1, 1)
	fic.resized.connect(func(): fic.pivot_offset = fic.size / 2)
	sel_bar.add_child(fwd)
	sel_bar.add_child(UIKit.round_button("trash", _delete_sel, 50, Color("#ffe1e6"), Color("#d8435c")))
	sel_bar.visible = false
	pv.add_child(sel_bar)
	panel_sep = ColorRect.new()
	panel_sep.color = Color(UIKit.INK, 0.08)
	panel_sep.custom_minimum_size = Vector2(0, 2)
	pv.add_child(panel_sep)
	pv.add_child(palette_scroll)
	# sık kullanılanlar: başparmak hizası, panelin içinde (çentikten uzak)
	tool_row = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(tool_row)
	btn_menu = UIKit.round_button("menu", _open_pause, 50)
	tool_row.add_child(btn_menu)
	btn_hint = UIKit.round_button("bulb", _toggle_hint, 50, Color("#fff4cf"), Color("#b5820f"))
	tool_row.add_child(btn_hint)
	btn_cam = UIKit.round_button("cam_r", _reset_camera, 50)
	tool_row.add_child(btn_cam)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_row.add_child(spacer)
	_build_theme_bar()
	# çalıştırma kontrolleri
	run_row = HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 8)
	pv.add_child(run_row)
	btn_clear = UIKit.round_button("trash", _clear_prog, 54)
	run_row.add_child(btn_clear)
	btn_stop = UIKit.round_button("stop", _reset_to_setup, 54)
	run_row.add_child(btn_stop)
	btn_step = UIKit.round_button("step", _step_btn, 54)
	run_row.add_child(btn_step)
	btn_run = _make_run_button()
	btn_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_row.add_child(btn_run)
	btn_speed = UIKit.button("1×", Color.WHITE, _cycle_speed, 19, "", UIKit.INK, 54)
	btn_speed.custom_minimum_size = Vector2(58, 54)
	run_row.add_child(btn_speed)

func _make_run_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(136, 62)
	UIKit.style_chunky(b, UIKit.GREEN, 31, 4)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_bottom = -4
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.Icon.new()
	ic.kind = "play"
	ic.color = Color.WHITE
	ic.custom_minimum_size = Vector2(26, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var lb := UIKit.label("Çalıştır", 22, Color.WHITE, UIKit.font_black)
	hb.add_child(lb)
	b.add_child(hb)
	b.set_meta("icon", ic)
	b.set_meta("label", lb)
	b.pressed.connect(_run_toggle)
	UIKit.juicy(b)
	return b

func _ui_mode_changed(m: String, quiet: bool) -> void:
	var ic: UIKit.Icon = btn_run.get_meta("icon")
	var lb: Label = btn_run.get_meta("label")
	ic.kind = "pause" if m == "running" else "play"
	ic.queue_redraw()
	lb.text = {"running": "Duraklat", "paused": "Devam"}.get(m, "Çalıştır")
	UIKit.style_chunky(btn_run, Color("#f5a524") if m == "running" else UIKit.GREEN, 31, 4)
	var show_status := m == "paused" or m == "ended"
	if show_status:
		var col := Color("#e8648aee") if m == "paused" else Color("#d8435cee")
		(status_pill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = col
		if m == "paused":
			lbl_status.text = "Adım adım: sonraki komut için ⏭, devam için ▶" if quiet else "Mola — platformları çevir, kamerayı döndür, sonra Devam"
		else:
			lbl_status.text = {
				"end": "Program bitti ama Robo kristale ulaşmadı",
				"dead": "Robo düştü! Programı düzenle ve tekrar dene",
				"limit": "Robo yoruldu: %d komut sınırı aşıldı" % Program.MAX_STEPS,
				"depth": "Çok fazla iç içe fonksiyon çağrısı",
				"loop": "Program boş bir döngüde dönüp duruyor",
			}.get(end_reason, "Program durdu")
		if not status_pill.visible and not instant:
			status_pill.visible = true
			_layout()
			UIKit.slide_in(status_pill, Vector2(0, -30))
	status_pill.visible = show_status
	if m == "paused" and not quiet and not instant:
		audio.play("pause")
	var editing := m == "edit" or m == "ended"
	palette_box.modulate.a = 1.0 if editing else 0.45
	btn_clear.disabled = not editing
	btn_stop.disabled = m == "edit"
	if not instant:
		_render_rows()
	_layout()


# ---------- ekranlar ----------
func _overlay(dim := 0.35) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = Color(0.12, 0.06, 0.22, dim)
	c.add_child(d)
	c.visible = false
	ui_root.add_child(c)
	return c

func _center_box(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	cc.add_child(child)

func _logo_label(text: String, size: int) -> Label:
	var l := UIKit.label(text, size, Color.WHITE, UIKit.font_black)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color("#8a5ce0"))
	l.add_theme_constant_override("outline_size", int(size * 0.22))
	l.add_theme_color_override("font_shadow_color", Color("#4a2b9a"))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.09))
	l.add_theme_constant_override("shadow_outline_size", int(size * 0.22))
	return l

func _build_screens() -> void:
	# --- başlık ---
	var t := Control.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(t)
	screens["title"] = t
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 8)
	t.add_child(tv)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -26)
	logo.add_child(_logo_label("KAYIP", 92))
	logo.add_child(_logo_label("KULELER", 112))
	title_logo = logo
	tv.add_child(logo)
	var sub := UIKit.label("Robo'yu programla · Dünyayı döndür", 22, Color.WHITE, UIKit.font_black)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("#6a4bc4cc"))
	sub.add_theme_constant_override("outline_size", 8)
	tv.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 180)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(spacer)
	var play := UIKit.button("OYNA", UIKit.GREEN, _play, 40, "play", Color.WHITE, 92)
	play.custom_minimum_size = Vector2(320, 92)
	UIKit.style_chunky(play, UIKit.GREEN, 46, 8)
	title_play = play
	var pc := CenterContainer.new()
	pc.add_child(play)
	tv.add_child(pc)
	var tr := HBoxContainer.new()
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	tr.add_theme_constant_override("separation", 18)
	tr.add_child(UIKit.round_button("grid", _open_levels, 66, Color.WHITE, UIKit.PURPLE))
	tr.add_child(UIKit.round_button("gear", _open_settings, 66, Color.WHITE, UIKit.INK))
	tv.add_child(tr)
	btn_pc_title = UIKit.button("Bilgisayarım", Color("#ffb84d"), func(): _open_assembly("showcase"), 22, "sparkle", UIKit.INK, 60)
	var pcc := CenterContainer.new()
	pcc.add_child(btn_pc_title)
	tv.add_child(pcc)
	lbl_title_stars = UIKit.label("", 22, UIKit.INK, UIKit.font_black)
	var tsp := HBoxContainer.new()
	tsp.add_theme_constant_override("separation", 6)
	var tsi := UIKit.Icon.new()
	tsi.kind = "star"
	tsi.color = UIKit.GOLD
	tsi.custom_minimum_size = Vector2(26, 26)
	tsp.add_child(tsi)
	tsp.add_child(lbl_title_stars)
	var tpill := UIKit.pill(tsp)
	tpill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tpill.position = Vector2(-150, 18)
	tpill.set_meta("anchor_right", true)
	t.add_child(tpill)
	t.set_meta("star_pill", tpill)

	# --- seviye haritası ---
	var lv := Control.new()
	lv.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(lv)
	screens["levels"] = lv
	var lbg := ColorRect.new()
	lbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbg.color = Color(1, 1, 1, 0.18)
	lv.add_child(lbg)
	var lscroll := ScrollContainer.new()
	lscroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	lscroll.offset_top = 96
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(lscroll)
	var lcenter := CenterContainer.new()
	lcenter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lscroll.add_child(lcenter)
	levels_list = VBoxContainer.new()
	levels_list.add_theme_constant_override("separation", 14)
	lcenter.add_child(levels_list)
	var lhead := HBoxContainer.new()
	lhead.position = Vector2(16, 16)
	lhead.add_theme_constant_override("separation", 16)
	lhead.add_child(UIKit.round_button("back", _show_title, 62))
	var lt := _logo_label("KULELER", 46)
	lhead.add_child(lt)
	lv.add_child(lhead)
	lv.set_meta("scroll", lscroll)

	# --- kazanma ---
	var w := _overlay(0.28)
	screens["win"] = w
	win_card = UIKit.card(0.97, 36, 30)
	win_card.custom_minimum_size = Vector2(480, 0)
	var wv := VBoxContainer.new()
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 14)
	win_card.add_child(wv)
	lbl_win_title = _logo_label("HARİKA!", 54)
	wv.add_child(lbl_win_title)
	var sr := HBoxContainer.new()
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	sr.add_theme_constant_override("separation", 10)
	win_stars = []
	for k in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(96, 96) if k != 1 else Vector2(118, 118)
		var st := UIKit.Icon.new()
		st.kind = "star"
		st.color = UIKit.GOLD
		st.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(st)
		sr.add_child(holder)
		win_stars.append(st)
	wv.add_child(sr)
	lbl_win = UIKit.label("", 20, UIKit.INK_SOFT, UIKit.font_bold)
	lbl_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_win.custom_minimum_size = Vector2(420, 0)
	wv.add_child(lbl_win)
	var wr := HBoxContainer.new()
	wr.alignment = BoxContainer.ALIGNMENT_CENTER
	wr.add_theme_constant_override("separation", 14)
	wr.add_child(UIKit.round_button("reset", _retry, 66))
	wr.add_child(UIKit.round_button("grid", _open_levels, 66, Color.WHITE, UIKit.PURPLE))
	btn_next = UIKit.button("Sonraki", UIKit.GREEN, func(): _start_level(mini(levels.size() - 1, level_idx + 1)), 28, "play", Color.WHITE, 72)
	btn_next.custom_minimum_size = Vector2(220, 72)
	wr.add_child(btn_next)
	wv.add_child(wr)
	_center_box(w, win_card)

	# --- duraklatma menüsü ---
	var pz := _overlay(0.4)
	screens["pause"] = pz
	var pcard := UIKit.card(0.97, 36, 30)
	pcard.custom_minimum_size = Vector2(400, 0)
	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 14)
	pcard.add_child(pvb)
	var ptitle := _logo_label("DURAKLATILDI", 40)
	pvb.add_child(ptitle)
	pvb.add_child(UIKit.button("Devam et", UIKit.GREEN, func(): _show(""), 26, "play", Color.WHITE, 70))
	pvb.add_child(UIKit.button("Dünyayı başa al", Color.WHITE, func():
		_reset_world()
		audio.play("mech")
		_show(""), 24, "reset", UIKit.INK, 64))
	pvb.add_child(UIKit.button("Seviyeler", UIKit.PURPLE, _open_levels, 26, "grid", Color.WHITE, 70))
	btn_pc_pause = UIKit.button("Bilgisayarım", Color("#ffb84d"), func(): _open_assembly("showcase"), 24, "sparkle", UIKit.INK, 64)
	pvb.add_child(btn_pc_pause)
	pvb.add_child(UIKit.button("Ayarlar", Color.WHITE, _open_settings, 24, "gear", UIKit.INK, 64))
	pvb.add_child(UIKit.button("Ana menü", UIKit.CORAL, _show_title, 24, "home", Color.WHITE, 64))
	_center_box(pz, pcard)

	# --- ayarlar ---
	var st_o := _overlay(0.4)
	screens["settings"] = st_o
	var scard := UIKit.card(0.97, 36, 30)
	scard.custom_minimum_size = Vector2(420, 0)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 16)
	scard.add_child(svb)
	svb.add_child(_logo_label("AYARLAR", 42))
	var tg := HBoxContainer.new()
	tg.alignment = BoxContainer.ALIGNMENT_CENTER
	tg.add_theme_constant_override("separation", 22)
	btn_sound = UIKit.round_button("sound", _toggle_sound, 78, UIKit.PURPLE, Color.WHITE)
	btn_music = UIKit.round_button("music", _toggle_music, 78, UIKit.PURPLE, Color.WHITE)
	tg.add_child(btn_sound)
	tg.add_child(btn_music)
	svb.add_child(tg)
	btn_gfx = UIKit.button("Grafik: Orta", Color.WHITE, _cycle_gfx, 22, "sparkle", UIKit.INK, 62)
	svb.add_child(btn_gfx)
	btn_vib = UIKit.button("Titreşim: Açık", Color.WHITE, _toggle_vib, 22, "sparkle", UIKit.INK, 62)
	svb.add_child(btn_vib)
	# geliştirici / test paneli
	var dev := HBoxContainer.new()
	dev.alignment = BoxContainer.ALIGNMENT_CENTER
	dev.add_theme_constant_override("separation", 10)
	dev_jump = SpinBox.new()
	dev_jump.min_value = 1
	dev_jump.max_value = 100
	dev_jump.value = 1
	dev_jump.custom_minimum_size = Vector2(110, 54)
	dev.add_child(dev_jump)
	dev.add_child(UIKit.button("Seviyeye Atla (1–100)", Color("#d9f2ff"), func(): _dev_jump(int(dev_jump.value)), 18, "play", UIKit.INK, 54))
	svb.add_child(dev)
	svb.add_child(UIKit.button("Finali Test Et (100/100)", Color("#ffb84d"), _final_test, 20, "sparkle", UIKit.INK, 58))
	svb.add_child(UIKit.button("İlerleme yedeği", Color.WHITE, _open_backup, 22, "save", UIKit.INK, 62))
	svb.add_child(UIKit.button("Kapat", UIKit.CORAL, _close_settings, 24, "close", Color.WHITE, 64))
	_center_box(st_o, scard)

	# --- yeni kavram kartı ---
	var io := _overlay(0.3)
	screens["intro"] = io
	var icard := UIKit.card(0.98, 34, 28)
	icard.custom_minimum_size = Vector2(500, 0)
	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 12)
	icard.add_child(ivb)
	var badge := UIKit.pill(UIKit.label("YENİ", 15, Color.WHITE, UIKit.font_black), UIKit.CORAL, 10)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ivb.add_child(badge)
	intro_badge = badge
	# Nova'nın sunduğu kartlarda avatar + isim
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 12)
	nrow.add_child(UIKit.nova_avatar(58))
	var ncol := VBoxContainer.new()
	ncol.alignment = BoxContainer.ALIGNMENT_CENTER
	ncol.add_theme_constant_override("separation", -4)
	ncol.add_child(UIKit.label("NOVA", 22, Color("#6a4cff"), UIKit.font_black))
	ncol.add_child(UIKit.label("Yapay zekâ öğretmenin", 15, UIKit.INK_SOFT, UIKit.font_bold))
	nrow.add_child(ncol)
	nrow.visible = false
	ivb.add_child(nrow)
	intro_nova = nrow
	lbl_intro_title = UIKit.label("", 32, UIKit.INK, UIKit.font_black)
	ivb.add_child(lbl_intro_title)
	lbl_intro_text = RichTextLabel.new()
	lbl_intro_text.bbcode_enabled = true
	lbl_intro_text.fit_content = true
	lbl_intro_text.custom_minimum_size = Vector2(444, 0)
	lbl_intro_text.add_theme_font_size_override("normal_font_size", 20)
	lbl_intro_text.add_theme_font_size_override("bold_font_size", 20)
	lbl_intro_text.add_theme_constant_override("line_separation", 4)
	ivb.add_child(lbl_intro_text)
	ivb.add_child(UIKit.button("Anladım", UIKit.CORAL, func():
		progress["seen"][str(level_idx)] = 1
		_save_progress()
		_show(""), 24, "check", Color.WHITE, 64))
	_center_box(io, icard)

	# --- yedek ---
	var bo := _overlay(0.4)
	screens["backup"] = bo
	var bcard := UIKit.card(0.98, 34, 26)
	bcard.custom_minimum_size = Vector2(560, 0)
	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 12)
	bcard.add_child(bvb)
	bvb.add_child(UIKit.label("İlerleme yedeği", 32, UIKit.INK, UIKit.font_black))
	var bl := UIKit.label("Bu kod tüm ilerlemeni içerir. Başka bir cihazda ya da yeniden kurulumdan sonra buraya yapıştırıp Geri yükle'ye bas.", 17, UIKit.INK_SOFT)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(508, 0)
	bvb.add_child(bl)
	backup_edit = TextEdit.new()
	backup_edit.custom_minimum_size = Vector2(508, 120)
	backup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	bvb.add_child(backup_edit)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	var b1 := UIKit.button("Kopyala", Color.WHITE, func():
		DisplayServer.clipboard_set(_export_code())
		_toast("Yedek kodu kopyalandı"), 20, "", UIKit.INK, 58)
	var b2 := UIKit.button("Geri yükle", UIKit.CORAL, func():
		if _import_code(backup_edit.text):
			_toast("İlerleme geri yüklendi")
			_open_levels()
		else:
			_toast("Geçersiz yedek kodu")
			UIKit.shake(bcard), 20, "", Color.WHITE, 58)
	var b3 := UIKit.button("Kapat", Color.WHITE, func(): _show(screens.get("_back", "settings")), 20, "", UIKit.INK_SOFT, 58)
	for b in [b1, b2, b3]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(b)
	bvb.add_child(br)
	_center_box(bo, bcard)


# ---------- ekran geçişleri ----------
var _current := "title"
var _settings_from := ""

func _show(which: String) -> void:
	var overlays := ["pause", "intro", "settings", "backup"]
	var prev := _current
	_current = which
	for k in screens:
		if typeof(screens[k]) != TYPE_OBJECT:
			continue
		var sc: Control = screens[k]
		var on: bool = k == which
		if on and not sc.visible:
			sc.visible = true
			sc.modulate.a = 0.0
			var tw := sc.create_tween()
			tw.tween_property(sc, "modulate:a", 1.0, 0.22)
			_animate_enter(k)
		elif not on and sc.visible:
			if instant:
				sc.visible = false
			else:
				var tw2 := sc.create_tween()
				tw2.tween_property(sc, "modulate:a", 0.0, 0.16)
				tw2.tween_callback(func(): if _current != k: sc.visible = false)
	hud.visible = which == "" or which in overlays and prev in ["", "pause", "intro", "settings", "backup"] and L != null and not preview
	cam_spin = which == "title"
	if which != "" and which not in overlays:
		_hide_hint()
	_layout()

func _animate_enter(k: String) -> void:
	if instant:
		return
	match k:
		"title":
			UIKit.pop_in(title_logo, 0.05, 0.6)
			if _play_tw:
				_play_tw.kill()
			title_play.scale = Vector2.ONE
			_play_tw = UIKit.pulse(title_play, 1.05, 1.4)
			var tw := title_logo.create_tween().set_loops()
			tw.tween_property(title_logo, "position:y", title_logo.position.y - 10, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(title_logo, "position:y", title_logo.position.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"win":
			win_card.pivot_offset = win_card.size / 2
			win_card.scale = Vector2(0.6, 0.6)
			var tw := win_card.create_tween()
			tw.tween_property(win_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var n: int = win_card.get_meta("stars", 0)
			for i in 3:
				var st: UIKit.Icon = win_stars[i]
				st.color = UIKit.GOLD if i < n else Color("#e6e0f0")
				st.pivot_offset = st.size / 2
				st.scale = Vector2.ZERO
				st.rotation = -0.6
				var stw := st.create_tween().set_parallel(true)
				var d := 0.45 + i * 0.2
				stw.tween_property(st, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(d)
				stw.tween_property(st, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
				if i < n:
					get_tree().create_timer(d).timeout.connect(func(): audio.play("star", 1.0 + i * 0.12))
		"levels":
			var k2 := 0
			for ch in levels_list.get_children():
				UIKit.pop_in(ch, minf(0.6, k2 * 0.05), 0.85)
				k2 += 1
		"pause", "intro", "settings", "backup":
			var box: Control = screens[k].get_child(1).get_child(0)
			box.pivot_offset = box.size / 2
			box.scale = Vector2(0.85, 0.85)
			var tw := box.create_tween()
			tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_veil() -> void:
	if instant:
		return
	veil.color = weather.veil_color()
	veil.color.a = 1.0
	var tw := veil.create_tween()
	tw.tween_property(veil, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_delay(0.05)

## Ekran pikseli cinsinden güvenli kenar boşluğu: çentik, ön kamera ve sistem çubukları.
func _safe_margins() -> Vector4:
	if safe_override.x >= 0.0:
		return safe_override
	var win := DisplayServer.window_get_size()
	if win.x <= 1 or win.y <= 1:
		return Vector4.ZERO
	var vs := get_viewport().get_visible_rect().size
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	var safe := DisplayServer.get_display_safe_area()
	var left := float(safe.position.x) * sx
	var top := float(safe.position.y) * sy
	var right := (float(win.x) - safe.position.x - safe.size.x) * sx
	var bottom := (float(win.y) - safe.position.y - safe.size.y) * sy
	for cut in DisplayServer.get_display_cutouts():
		var c: Rect2 = cut
		if c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		var cx := c.position.x * sx
		var cy := c.position.y * sy
		var cw := c.size.x * sx
		var ch := c.size.y * sy
		if cy <= top + 2.0:
			top = maxf(top, cy + ch)
		if cx <= left + 2.0:
			left = maxf(left, cx + cw)
		if cx + cw >= vs.x - right - 2.0:
			right = maxf(right, vs.x - cx)
		if cy + ch >= vs.y - bottom - 2.0:
			bottom = maxf(bottom, vs.y - cy)
	return Vector4(left, top, right, bottom)

## Dar ekranda sabit düğme genişlikleri paneli ekrandan taşırıp sağdaki sekmeleri
## tıklanamaz bırakıyordu. İç genişliğe sığacak şekilde küçültülür.
func _fit_chrome(inner: float) -> void:
	if run_row == null:
		return
	var sep := 8
	var side := 52
	var speed_w := 58
	var run_w := 136.0
	var need := float(side * 3 + speed_w) + run_w + sep * 4
	if need > inner:
		sep = 4
		side = 44
		speed_w = 46
		run_w = maxf(84.0, inner - side * 3 - speed_w - sep * 4)
	run_row.add_theme_constant_override("separation", sep)
	for b in [btn_clear, btn_stop, btn_step]:
		b.custom_minimum_size = Vector2(side, side)
	btn_speed.custom_minimum_size = Vector2(speed_w, side)
	btn_run.custom_minimum_size = Vector2(run_w, maxf(56, side + 4))
	var tool_side := mini(50, side)
	for b in [btn_menu, btn_hint, btn_cam]:
		b.custom_minimum_size = Vector2(tool_side, tool_side)
	var theme_btn := 40
	var theme_lbl := 96.0
	if inner < 440.0:
		theme_btn = 36
		theme_lbl = 48.0
		tool_row.add_theme_constant_override("separation", 6)
	else:
		tool_row.add_theme_constant_override("separation", 8)
	for c in theme_bar.get_children():
		if c is Button:
			(c as Button).custom_minimum_size = Vector2(theme_btn, 44)
	var compact := inner < 460.0
	lbl_theme.clip_text = compact
	lbl_theme.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact else TextServer.OVERRUN_NO_TRIMMING
	lbl_theme.custom_minimum_size.x = theme_lbl if compact else 0.0
	if compact != theme_compact:
		theme_compact = compact
		_update_theme_label()

## Panel yüksekliği = içeriğin en küçük yüksekliği; alt kenar güvenli alanın üstünde.
## Satırlar bir sonraki karede büyüyebildiği için her karede ucuz bir kontrolle hizalanır.
func _fit_panel() -> void:
	if panel == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var safe := _safe_margins()
	var top_limit := safe.y + 8.0
	var bottom_limit := vs.y - (safe.w + 8.0)
	var max_h := maxf(120.0, bottom_limit - top_limit)
	var ph := panel.get_combined_minimum_size().y
	if ph > max_h and rows_scroll != null:
		var shrink := ph - max_h
		rows_scroll.custom_minimum_size.y = maxf(48.0, rows_scroll.custom_minimum_size.y - shrink)
		ph = panel.get_combined_minimum_size().y
	var y := bottom_limit - minf(ph, max_h)
	if y < top_limit:
		y = top_limit
	var h := minf(ph, bottom_limit - y)
	if absf(panel.size.y - h) > 0.5 or absf(panel.position.y - y) > 0.5:
		panel.size.y = h
		panel.position.y = y

func _layout() -> void:
	if ui_root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.x < vs.y * 0.95
	var safe := _safe_margins()
	_safe_applied = safe
	var m := 12.0
	var left := safe.x + m
	var right := safe.z + m
	var top := safe.y + 8.0
	var avail_w := maxf(160.0, vs.x - left - right)
	var rows_h := rows_box.get_combined_minimum_size().y if rows_box != null else 0.0
	var max_rows := vs.y * (0.36 if portrait else 0.5)
	if rows_scroll != null:
		rows_scroll.custom_minimum_size.y = minf(rows_h, max_rows)
	var pw := avail_w if portrait else clampf(vs.x * 0.36, 340.0, minf(520.0, avail_w))
	_fit_chrome(pw - 28.0)
	panel.size.x = pw
	panel.position.x = left if portrait else vs.x - right - pw
	_fit_panel()
	# başlık: çentiğin altında, oyun alanını kaplamadan
	top_bar.position = Vector2(left, top)
	var pill: Control = view_dots.get_meta("pill")
	pill.reset_size()
	top_bar.reset_size()
	var dots_x := vs.x - right - pill.size.x
	var title_right := panel.position.x - 10.0 if not portrait else dots_x - 8.0
	var text_w := maxf(72.0, title_right - left - 150.0)
	lbl_chap.custom_minimum_size.x = text_w
	lbl_name.custom_minimum_size.x = text_w
	top_bar.reset_size()
	if top_bar.position.x + top_bar.size.x + 8.0 > dots_x:
		pill.position = Vector2(left, top + top_bar.size.y + 6.0)
	else:
		pill.position = Vector2(dots_x, top + maxf(0.0, (top_bar.size.y - pill.size.y) * 0.5))
	var band := maxf(top_bar.position.y + top_bar.size.y, pill.position.y + pill.size.y) + 8.0
	var free_left := left
	var free_right := panel.position.x - 8.0 if not portrait else vs.x - right
	var free_w := maxf(80.0, free_right - free_left)
	lbl_hint.custom_minimum_size = Vector2(minf(520, free_w - 70), 0)
	status_pill.reset_size()
	status_pill.position = Vector2(free_left + maxf(0.0, (free_w - status_pill.size.x) / 2.0), band)
	hint_card.position = Vector2(free_left, band)
	lbl_nova.custom_minimum_size = Vector2(minf(460, free_w - 90), 0)
	nova_card.reset_size()
	nova_card.position = Vector2(free_left, status_pill.position.y + status_pill.size.y + 8.0 if status_pill.visible else band)
	toast_pill.reset_size()
	toast_pill.position.x = (vs.x - toast_pill.size.x) / 2.0
	var tp: Control = screens["title"].get_meta("star_pill")
	tp.reset_size()
	tp.position = Vector2(vs.x - safe.z - tp.size.x - 12, safe.y + 12)
	levels_list.custom_minimum_size.x = minf(820, vs.x - left - right)


# ---------- seviye haritası ----------
func _show_title() -> void:
	if L != null and not preview:
		_fade_veil()
	build_level(5, true)
	cam_az = 20.0
	cam_az_cur = 20.0
	cam_zoom = 0.85
	_title_diorama()
	var got := 0
	for k in progress["best"]:
		got += int(progress["best"][k]["stars"])
	lbl_title_stars.text = "%d / %d" % [got, levels.size() * 3]
	_update_pc_buttons()
	_show("title")

## Başlık ekranında seviye önizlemesi yerine Blender dioraması + selam veren iskeletli robot (varsa)
func _title_diorama() -> void:
	if title_dio != null or not ComponentFactory.use_models:
		return
	var d := AssetLoader.scene_model("title_diorama")
	if d == null:
		return
	level_root.visible = false
	d.position = Vector3(cam_target.x, float(L.min_y) - 0.5, cam_target.z)
	world.add_child(d)
	title_dio = d
	var spot := d.find_child("RobotSpot", true, false) as Node3D
	var rb := AssetLoader.robot_model()
	if rb != null:
		rb.position = spot.position if spot != null else Vector3(2.7, 0, 0)
		rb.rotation.y = 0.5
		d.add_child(rb)
		var ap := AssetLoader.anim_player(rb, [])
		if ap != null:
			ap.play("wave")
			# animasyon kaynakları örnekler arasında paylaşılır (idle döngüde): klip değişimi zamanlayıcıyla
			var tm := Timer.new()
			tm.wait_time = 3.2
			tm.autostart = true
			d.add_child(tm)
			tm.timeout.connect(func(): ap.play(["idle", "look", "wave", "idle"][randi() % 4], 0.2))
	cam_target = d.position + Vector3(0, 2.4, 0)
	cam_size = 13.5

func _play() -> void:
	audio.play("tap")
	var n := int(progress["unlocked"]) - 1
	if not progress["best"].has(str(n)) and n < levels.size():
		_start_level(n)
	else:
		_open_levels()

func _open_levels() -> void:
	if mode == "running":
		_set_mode("paused", true)
	if L == null or not preview:
		build_level(5, true)
		cam_az = 20.0
		cam_zoom = 0.85
	for c in levels_list.get_children():
		c.queue_free()
	var chapter := ""
	var flow: HFlowContainer
	var ch_i := 0
	var cur := int(progress["unlocked"]) - 1
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var p: Dictionary = PALETTES[int(lv.get("palette", i)) % PALETTES.size()]
		if lv["chapter"] != chapter:
			chapter = lv["chapter"]
			ch_i += 1
			var got := 0
			var tot := 0
			for j in levels.size():
				if levels[j]["chapter"] == chapter:
					tot += 3
					if progress["best"].has(str(j)):
						got += int(progress["best"][str(j)]["stars"])
			var banner := PanelContainer.new()
			var bsb := UIKit.box(Color(p["accent"]), 22, 10)
			bsb.border_color = Color(p["accent"]).darkened(0.2)
			bsb.border_width_bottom = 6
			bsb.content_margin_left = 22
			bsb.content_margin_right = 22
			bsb.content_margin_top = 10
			bsb.content_margin_bottom = 12
			banner.add_theme_stylebox_override("panel", bsb)
			var bh := HBoxContainer.new()
			bh.add_theme_constant_override("separation", 10)
			# faz adası ikonu (Blender render: assets/ui/phase_XX.png), yoksa atlanır
			var pip := "res://assets/ui/phase_%02d.png" % ch_i
			if ResourceLoader.exists(pip):
				var pi_tex := TextureRect.new()
				pi_tex.texture = load(pip)
				pi_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pi_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pi_tex.custom_minimum_size = Vector2(64, 64)
				pi_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				bh.add_child(pi_tex)
			var bn := UIKit.label("FAZ %d" % ch_i, 16, Color(1, 1, 1, 0.8), UIKit.font_black)
			bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bh.add_child(bn)
			var bt := UIKit.label(chapter, 28, Color.WHITE, UIKit.font_black)
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bh.add_child(bt)
			var si := UIKit.Icon.new()
			si.kind = "star"
			si.color = Color.WHITE
			si.custom_minimum_size = Vector2(24, 24)
			si.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bh.add_child(si)
			bh.add_child(UIKit.label("%d/%d" % [got, tot], 20, Color.WHITE, UIKit.font_black))
			# faz kartı: donanım adı, toplanan parça ve açık seviye sayısı
			var ph := LevelProgressionManager.phase(ch_i - 1)
			var pc := LevelProgressionManager.parts_in_phase(ch_i - 1, _parts())
			var open_n := 0
			for j in LevelProgressionManager.level_range(ch_i - 1):
				if j < int(progress["unlocked"]):
					open_n += 1
			var bv := VBoxContainer.new()
			bv.add_theme_constant_override("separation", 2)
			bv.add_child(bh)
			bv.add_child(UIKit.label("%s  ·  Parça %d/10  ·  Açık seviye %d/10" % [ph.get("hardware", chapter), pc, open_n], 15, Color(1, 1, 1, 0.92), UIKit.font_bold))
			banner.add_child(bv)
			levels_list.add_child(banner)
			flow = HFlowContainer.new()
			flow.alignment = FlowContainer.ALIGNMENT_CENTER
			flow.add_theme_constant_override("h_separation", 14)
			flow.add_theme_constant_override("v_separation", 14)
			levels_list.add_child(flow)
		flow.add_child(_level_bubble(i, p, i >= int(progress["unlocked"]), i == cur and not progress["best"].has(str(i))))
	_show("levels")
	var lsc: ScrollContainer = screens["levels"].get_meta("scroll")
	# geçerli seviyeye kaydır
	await get_tree().process_frame
	await get_tree().process_frame
	for ch in levels_list.get_children():
		if ch is HFlowContainer:
			for b in ch.get_children():
				if b.has_meta("current"):
					lsc.scroll_vertical = int(maxf(0.0, ch.position.y + b.position.y - 200))

func _level_bubble(i: int, p: Dictionary, locked: bool, current: bool) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(100, 100)
	var base := Color("#d8d2e4") if locked else Color(p["accent"]).lerp(Color.WHITE, 0.3)
	UIKit.style_chunky(b, base, 50, 7, Color.WHITE)
	if current:
		for st in ["normal", "hover"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.border_color = UIKit.GOLD
			sb.border_width_left = 5
			sb.border_width_right = 5
			sb.border_width_top = 5
		b.set_meta("current", true)
	if locked:
		var ic := UIKit.Icon.new()
		ic.kind = "lock"
		ic.color = Color("#9a92ad")
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 32
		ic.offset_right = -32
		ic.offset_top = 28
		ic.offset_bottom = -36
		b.add_child(ic)
		b.disabled = true
	else:
		b.text = str(i + 1)
		b.add_theme_font_override("font", UIKit.font_black)
		b.add_theme_font_size_override("font_size", 38)
		b.add_theme_color_override("font_outline_color", Color(p["accent"]).darkened(0.35))
		b.add_theme_constant_override("outline_size", 10)
		b.pressed.connect(func(): audio.play("tap"); _start_level(i))
	UIKit.juicy(b)
	holder.add_child(b)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 0)
	var best = progress["best"].get(str(i))
	var n := int(best["stars"]) if best != null else 0
	for k in 3:
		var st := UIKit.Icon.new()
		st.kind = "star"
		st.color = UIKit.GOLD if k < n else Color(1, 1, 1, 0.55 if not locked else 0.0)
		st.custom_minimum_size = Vector2(26, 26)
		stars.add_child(st)
	holder.add_child(stars)
	var name := UIKit.label(levels[i]["name"], 13, UIKit.INK, UIKit.font_bold)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(100, 0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	name.add_theme_constant_override("outline_size", 5)
	name.modulate.a = 0.4 if locked else 1.0
	holder.add_child(name)
	if current:
		get_tree().process_frame.connect(func(): UIKit.pulse(b, 1.06, 1.1), CONNECT_ONE_SHOT)
	return holder

func _start_level(i: int) -> void:
	build_level(i)
	var saved = progress["progs"].get(str(i))
	var starter = levels[i].get("starter")
	if saved is Dictionary:
		prog = Program.parse_program(saved)
	elif starter is Dictionary:
		prog = Program.parse_program(starter)   # hata ayıklama seviyesi: hazır (hatalı) program
	else:
		prog = {"main": [], "p1": [], "p2": []}
	var slots: Dictionary = levels[i]["slots"]
	for r in ROWS:
		var cap := int(slots.get(r, 0))
		if prog[r].size() > cap:
			prog[r] = prog[r].slice(0, cap)
	active_row = "main"
	sel = null
	lbl_hint.text = levels[i].get("hint", "")
	_hide_hint()
	_hide_nova()
	_render_palette()
	_set_mode("edit")
	_show("")
	_fade_veil()
	if not instant:
		_animate_hud_in()
	var intro = levels[i].get("intro")
	if intro is Dictionary and not progress["seen"].has(str(i)) and not instant:
		lbl_intro_title.text = intro["title"]
		lbl_intro_text.text = _html_to_bb(intro["text"])
		var ai: bool = intro.get("ai", false)
		intro_badge.visible = not ai
		intro_nova.visible = ai
		get_tree().create_timer(0.35).timeout.connect(func(): if _current == "": _show("intro"))

func _animate_hud_in() -> void:
	_layout()
	var vs := get_viewport().get_visible_rect().size
	UIKit.slide_in(panel, Vector2(0, 260) if portrait else Vector2(260, 0), 0.05, 0.55)
	UIKit.slide_in(top_bar, Vector2(0, -40), 0.1)
	UIKit.slide_in(view_dots.get_meta("pill"), Vector2(0, -40), 0.15)
	var k := 0
	for t in palette_box.get_children():
		UIKit.pop_in(t, 0.25 + k * 0.04)
		k += 1

func _html_to_bb(s: String) -> String:
	var re := RegEx.new()
	re.compile("<span class=\"cond o\">(.*?)</span>")
	var out := re.sub(s, "[color=#2fc37a][b]$1[/b][/color]", true)
	re.compile("<span class=\"cond x\">(.*?)</span>")
	out = re.sub(out, "[color=#ff7a45][b]$1[/b][/color]", true)
	return out.replace("<b>", "[b]").replace("</b>", "[/b]").replace("<i>", "[i]").replace("</i>", "[/i]")

func _retry() -> void:
	win_shown = false
	_show("")
	_reset_to_setup()
	_set_mode("edit")

func _open_pause() -> void:
	audio.play("tap")
	_update_pc_buttons()
	if mode == "running":
		_set_mode("paused", true)
	_show("pause")

func _open_settings() -> void:
	_settings_from = _current
	_update_settings_buttons()
	_show("settings")

func _close_settings() -> void:
	_show(_settings_from if _settings_from in ["pause", "title", "levels"] else ("pause" if L != null and not preview else "title"))

func _open_backup() -> void:
	backup_edit.text = _export_code()
	screens["_back"] = "settings"
	_show("backup")

func _update_settings_buttons() -> void:
	UIKit.set_icon(btn_sound, "sound" if audio.sound_on else "sound_off")
	UIKit.set_icon(btn_music, "music" if audio.music_on else "music_off")
	UIKit.style_chunky(btn_sound, UIKit.PURPLE if audio.sound_on else Color("#bdb5cf"), 39, 5)
	UIKit.style_chunky(btn_music, UIKit.PURPLE if audio.music_on else Color("#bdb5cf"), 39, 5)
	UIKit.set_text(btn_gfx, "Grafik: " + ["Düşük", "Orta", "Yüksek"][gfx])
	UIKit.set_text(btn_vib, "Titreşim: " + ("Açık" if progress.get("haptics", true) else "Kapalı"))

func _toggle_vib() -> void:
	progress["haptics"] = not progress.get("haptics", true)
	var ah := Sfx.ah()
	if ah != null:
		ah.haptics_on = progress["haptics"]
		if ah.haptics_on:
			ah.vibrate(30)
	_save_progress()
	_update_settings_buttons()

## Geliştirici: kilitten bağımsız seviyeye atla
func _dev_jump(n: int) -> void:
	audio.play("tap")
	win_shown = false
	_start_level(clampi(n, 1, levels.size()) - 1)

## Geliştirici: bütün parçaları geçici olarak görünür kılıp büyük final sekansını başlat (kayda yazılmaz)
func _final_test() -> void:
	_open_assembly("final", 100)

func _toggle_sound() -> void:
	audio.sound_on = not audio.sound_on
	var ah := Sfx.ah()
	if ah != null:
		ah.sound_on = audio.sound_on
		if not audio.sound_on:
			ah.fan(0.0)
	progress["sound"] = audio.sound_on
	_save_progress()
	audio.play("tap")
	_update_settings_buttons()

func _toggle_music() -> void:
	audio.set_music(not audio.music_on)
	progress["music"] = audio.music_on
	_save_progress()
	_update_settings_buttons()

func _cycle_gfx() -> void:
	gfx = (gfx + 1) % 3
	progress["gfx"] = gfx
	_save_progress()
	_apply_gfx()
	_update_settings_buttons()
	audio.play("tap")

func _build_theme_bar() -> void:
	theme_bar = HBoxContainer.new()
	theme_bar.add_theme_constant_override("separation", 6)
	theme_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	theme_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	theme_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_child(theme_bar)
	var prev := Button.new()
	prev.text = "<"
	prev.focus_mode = Control.FOCUS_NONE
	prev.custom_minimum_size = Vector2(40, 44)
	prev.tooltip_text = "Önceki tema  ["
	UIKit.style_chunky(prev, Color.WHITE, 12, 3, UIKit.INK)
	prev.add_theme_font_size_override("font_size", 18)
	prev.pressed.connect(func(): _cycle_theme(-1))
	theme_bar.add_child(prev)
	lbl_theme = UIKit.label("Tema Değiştir (1/15)", 15, UIKit.INK, UIKit.font_black)
	lbl_theme.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_theme.clip_text = true
	lbl_theme.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_theme.custom_minimum_size = Vector2(72, 0)
	theme_bar.add_child(lbl_theme)
	var nxt := Button.new()
	nxt.text = ">"
	nxt.focus_mode = Control.FOCUS_NONE
	nxt.custom_minimum_size = Vector2(40, 44)
	nxt.tooltip_text = "Sonraki tema  ]"
	UIKit.style_chunky(nxt, Color.WHITE, 12, 3, UIKit.INK)
	nxt.add_theme_font_size_override("font_size", 18)
	nxt.pressed.connect(func(): _cycle_theme(1))
	theme_bar.add_child(nxt)


func _cycle_theme(dir: int) -> void:
	if theme_app == null or theme_app.theme == null or L == null or preview:
		return
	var n := ThemeLibrary.COUNT
	var id := theme_app.theme.chapter_id
	var next := ((id - 1 + dir) % n + n) % n + 1
	_apply_theme_id(next)
	audio.play("tap")


func _apply_theme_id(id: int) -> void:
	if theme_app == null:
		return
	theme_app.prepare(ThemeLibrary.theme(id))
	theme_app.refresh_props()
	theme_app.paint_robot()
	_update_theme_label()


func _update_theme_label() -> void:
	if lbl_theme == null or theme_app == null or theme_app.theme == null:
		return
	var t := theme_app.theme
	lbl_theme.text = ("Tema %d/15" if theme_compact else "Tema Değiştir (%d/15)") % t.chapter_id
	var tip := "%s · %s" % [t.theme_name, t.concept_name]
	lbl_theme.tooltip_text = tip
	if theme_bar:
		theme_bar.tooltip_text = tip


## Anten ucu moda göre (çalışıyor / mola / hata), gözler her zaman temanın LED renginde.
## Gövde silüeti değişmez.
func _apply_led_color() -> void:
	if not objs.has("player"):
		return
	var pl: Node3D = objs["player"]
	var led := Color("#6ff6ff")
	if theme_app != null and theme_app.theme != null:
		led = theme_app.theme.robot_led_color
	var col: Color = {"running": Color("#57e39a"), "paused": Color("#ffd36e"), "ended": Color("#ff6b7a")}.get(mode, led)
	var bm: StandardMaterial3D = pl.get_meta("bulb")
	bm.albedo_color = col
	bm.emission = col
	for m in pl.get_meta("led_mats", []):
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = col
			(m as StandardMaterial3D).emission_enabled = true
			(m as StandardMaterial3D).emission = col
	if pl.has_meta("eye_mat"):
		var eye: StandardMaterial3D = pl.get_meta("eye_mat")
		eye.albedo_color = led
		eye.emission = led


## Grafik kalitesi: Düşük = hafif çözünürlük, Orta = doğal çözünürlük + 4x MSAA, Yüksek = 1,5x süper örnekleme + 8x MSAA
func _apply_gfx() -> void:
	var vp := get_viewport()
	env.glow_enabled = gfx >= 1
	env.fog_enabled = false
	sun.shadow_enabled = gfx >= 1
	sun.shadow_blur = 2.4 if gfx == 2 else 1.6
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_4X, Viewport.MSAA_8X][gfx]
	vp.scaling_3d_scale = [0.75, 1.0, 1.5][gfx]
	RenderingServer.directional_shadow_atlas_set_size([1024, 4096, 4096][gfx], true)
	weather.set_quality(gfx)
	ComponentFactory.use_models = gfx >= 1


# ---------- HUD ----------
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
	lbl_chap.text = ("FAZ %d · %s" % [ch, def["chapter"]]).to_upper()
	lbl_name.text = "%d. %s" % [level_idx + 1, def["name"]]
	var dark: bool = weather.is_dark()
	lbl_chap.add_theme_color_override("font_color", Color("#cfc6ee") if dark else UIKit.INK_SOFT)
	lbl_name.add_theme_color_override("font_color", Color("#f5efff") if dark else UIKit.INK)
	for l in [lbl_chap, lbl_name]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.25) if dark else Color(1, 1, 1, 0.75))
	var blocks := Program.block_count(prog)
	var st := _stars_for(blocks, int(def["par"])) if blocks > 0 else 3
	lbl_blocks.text = "%d / %d" % [blocks, int(def["par"])]
	for k in 3:
		var ic: UIKit.Icon = mini_stars.get_child(k)
		ic.color = UIKit.GOLD if k < st else Color("#d9d2e6")
		ic.queue_redraw()

## Kamerayı sıfırla: yakınlaştırmayı ve (program çalışmıyorsa) seviyenin başlangıç bakış açısını geri getirir.
func _reset_camera() -> void:
	audio.play("whoosh")
	cam_zoom = 1.0
	var want := int(levels[level_idx].get("view", 0))
	var d := ((want - int(state["view"])) % 4 + 4) % 4
	if d != 0 and mode != "running":
		var steps := d if d <= 2 else d - 4
		for k in absi(steps):
			_rotate_view(signi(steps))
	else:
		_sync_view()

func _toggle_hint() -> void:
	audio.play("tap")
	if hint_card.visible:
		_hide_hint()
	else:
		_hide_nova()
		var h := LevelProgressionManager.next_hint_step(levels[level_idx], prog)
		var base: String = levels[level_idx].get("hint", "")
		lbl_hint.text = base + ("\n\nSıradaki adım → " + String(h["text"]) if not h.is_empty() else "\n\nProgramın kayıtlı çözümle aynı — çalıştır!")
		hint_card.visible = true
		_layout()
		UIKit.pop_in(hint_card, 0.0, 0.7)

func _hide_hint() -> void:
	if hint_card != null:
		hint_card.visible = false

func _toast(msg: String) -> void:
	if instant:
		return
	lbl_toast.text = msg
	toast_pill.visible = true
	toast_pill.reset_size()
	var vs := get_viewport().get_visible_rect().size
	toast_pill.position = Vector2((vs.x - toast_pill.size.x) / 2, -80)
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = toast_pill.create_tween()
	var toast_y := _safe_margins().y + 8.0
	_toast_tw.tween_property(toast_pill, "position:y", toast_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(toast_pill, "position:y", -80.0, 0.25).set_trans(Tween.TRANS_SINE)
	_toast_tw.tween_callback(func(): toast_pill.visible = false)

func _prepare_win(stars: int, blocks: int, par: int) -> void:
	win_card.set_meta("stars", stars)
	lbl_win_title.text = ["İYİ İŞ!", "GÜZEL!", "HARİKA!"][stars - 1]
	var txt := "%d blokla çözdün · par %d" % [blocks, par]
	if blocks < par:
		txt += "\nPar'dan da kısa — usta programcı!"
	elif stars < 3:
		txt += "\n3 yıldız için en fazla %d blok kullan." % par
		var tip := Nova.suggest(levels[level_idx], prog)
		if tip != "":
			txt += "\n" + tip
	lbl_win.text = txt
	btn_next.visible = level_idx < levels.size() - 1


# ---------- program editörü ----------
func _tile(ins: Dictionary, size := 52.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_chunky(b, Color(CMD_COLOR.get(ins["c"], "#888888")), 16, 4)
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	var ic := UIKit.Icon.new()
	ic.kind = ins["c"]
	ic.color = Color.WHITE
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = size * 0.2
	ic.offset_right = -size * 0.2
	ic.offset_top = size * 0.16
	ic.offset_bottom = -size * 0.26
	b.add_child(ic)
	# seçim / çalışma halkası
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = -5
	ring.offset_top = -5
	ring.offset_right = 5
	ring.offset_bottom = 5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rsb := StyleBoxFlat.new()
	rsb.draw_center = false
	rsb.set_border_width_all(4)
	rsb.set_corner_radius_all(20)
	rsb.border_color = UIKit.GOLD
	rsb.shadow_color = Color(1, 0.76, 0.24, 0.5)
	rsb.shadow_size = 10
	ring.add_theme_stylebox_override("panel", rsb)
	ring.visible = false
	b.add_child(ring)
	b.set_meta("ring", ring)
	if ins["k"] != "":
		var dot := PanelContainer.new()
		var dsb := UIKit.box(Color(COND_COLOR[ins["k"]]), 12)
		dsb.border_color = Color.WHITE
		dsb.set_border_width_all(3)
		dot.add_theme_stylebox_override("panel", dsb)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var di := UIKit.Icon.new()
		di.kind = "check" if ins["k"] == "o" else "close"
		di.color = Color.WHITE
		di.custom_minimum_size = Vector2(14, 14)
		di.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(di)
		dot.position = Vector2(-8, -8)
		b.add_child(dot)
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_color = Color(COND_COLOR[ins["k"]])
	UIKit.juicy(b)
	return b

func _render_palette() -> void:
	for c in palette_box.get_children():
		c.queue_free()
	var prev_cmds: Array = levels[level_idx - 1]["cmds"] if level_idx > 0 else []
	for c in levels[level_idx]["cmds"]:
		var b := _tile({"c": c, "k": ""}, 60)
		b.tooltip_text = Program.COMMANDS[c]["name"] + " — " + Program.COMMANDS[c]["desc"]
		var cc: String = c
		b.pressed.connect(func(): _insert(cc))
		if level_idx > 0 and not (c in prev_cmds):
			# yeni komut: altın halka nabzı
			var ring: Panel = b.get_meta("ring")
			ring.visible = true
			UIKit.pulse(ring, 1.08, 1.0)
		palette_box.add_child(b)

var _exec := {"proc": "", "idx": -1}
var _skipped := []
var _run_tile: Button = null

func _mark_exec(n, skipped: Array) -> void:
	_exec = {"proc": n["proc"], "idx": n["idx"]} if n != null else {"proc": "", "idx": -1}
	_skipped = skipped
	if instant:
		return
	var sp := _speed()
	var prev_tile: Button = _run_tile if _run_tile != null and is_instance_valid(_run_tile) else null
	var cur_tile: Button = null
	if n != null and tile_nodes.has(n["proc"]) and n["idx"] < tile_nodes[n["proc"]].size():
		cur_tile = tile_nodes[n["proc"]][n["idx"]]
	if prev_tile != null and prev_tile != cur_tile:
		(prev_tile.get_meta("ring") as Panel).visible = false
		prev_tile.pivot_offset = prev_tile.size / 2
		var ptw := _new_tw("exec:%d" % prev_tile.get_instance_id(), prev_tile)
		ptw.tween_property(prev_tile, "scale", Vector2.ONE, 0.14 / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_run_tile = null
	for row in tile_nodes:
		for t in tile_nodes[row]:
			t.modulate.a = 1.0
	for row in tile_nodes:
		(rows_box.get_node_or_null(NodePath(row)) as Control)
	for sk in skipped:
		if tile_nodes.has(sk["proc"]) and sk["idx"] < tile_nodes[sk["proc"]].size():
			tile_nodes[sk["proc"]][sk["idx"]].modulate.a = 0.35
	if n != null and tile_nodes.has(n["proc"]) and n["idx"] < tile_nodes[n["proc"]].size():
		var t: Button = tile_nodes[n["proc"]][n["idx"]]
		(t.get_meta("ring") as Panel).visible = true
		t.pivot_offset = t.size / 2
		var tw := _new_tw("exec:%d" % t.get_instance_id(), t)
		tw.tween_property(t, "scale", Vector2(1.12, 1.12), 0.12 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_run_tile = t
		rows_scroll.ensure_control_visible(t)
	for row in ROWS:
		var rp = rows_box.get_node_or_null(row)
		if rp:
			_style_row(rp, row)

func _style_row(rp: PanelContainer, row: String) -> void:
	var rsb := UIKit.box(Color(1, 1, 1, 0), 18)
	rsb.set_content_margin_all(8)
	if _exec["proc"] == row:
		rsb.bg_color = Color("#ffc83c2e")
		rsb.border_color = Color("#ffc23d")
		rsb.set_border_width_all(2)
	elif row == active_row and mode == "edit":
		rsb.bg_color = Color("#8a6cf01c")
		rsb.border_color = Color("#8a6cf066")
		rsb.set_border_width_all(2)
	else:
		rsb.bg_color = Color(1, 1, 1, 0.35)
	rp.add_theme_stylebox_override("panel", rsb)

## Sekme şeridi: her fonksiyon kendi dikdörtgeninde, kaydırma kutusunun dışında.
func _make_row_tab(row: String) -> Button:
	var active := row == active_row
	var col := Color(ROW_COLOR[row])
	if not active:
		col = col.lerp(Color("#f4f1fb"), 0.72)
	var font_col := Color.WHITE if active else UIKit.INK
	var b := UIKit.button(ROW_LABEL[row], col, func(): pass, 20, "", font_col, 56)
	b.custom_minimum_size = Vector2(72, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("row", row)
	var lb: Label = b.get_meta("label")
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rr: String = row
	b.pressed.connect(func():
		active_row = rr
		sel = null
		audio.play("tap")
		_render_rows()
		var rp := rows_box.get_node_or_null(NodePath(rr))
		if rp is Control:
			rows_scroll.ensure_control_visible(rp))
	return b

func _render_rows() -> void:
	if rows_box == null or L == null or preview:
		return
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	tile_nodes = {}
	_run_tile = null
	for c in row_tabs.get_children():
		row_tabs.remove_child(c)
		c.queue_free()
	var slots: Dictionary = levels[level_idx]["slots"]
	for row in ROWS:
		var cap := int(slots.get(row, 0))
		if cap <= 0:
			continue
		row_tabs.add_child(_make_row_tab(row))
		var rp := PanelContainer.new()
		rp.name = row
		_style_row(rp, row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		rp.add_child(h)
		var tag := UIKit.label(ROW_LABEL[row], 13, Color(ROW_COLOR[row]), UIKit.font_black)
		tag.custom_minimum_size = Vector2(32, 52)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tag)
		var rr: String = row
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 7)
		flow.add_theme_constant_override("v_separation", 7)
		h.add_child(flow)
		tile_nodes[row] = []
		for idx in prog[row].size():
			var t := _tile(prog[row][idx], 52)
			var ii: int = idx
			t.pressed.connect(func(): _select(rr, ii))
			if sel != null and sel["row"] == row and sel["idx"] == idx:
				var ring: Panel = t.get_meta("ring")
				(ring.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UIKit.PURPLE
				(ring.get_theme_stylebox("panel") as StyleBoxFlat).shadow_color = Color(0.54, 0.42, 0.94, 0.4)
				ring.visible = true
			flow.add_child(t)
			tile_nodes[row].append(t)
			if _insert_anim != null and _insert_anim["row"] == row and _insert_anim["idx"] == idx and not instant:
				t.pivot_offset = t.custom_minimum_size / 2
				t.scale = Vector2(0.2, 0.2)
				var itw := _new_tw("slot_in:%d" % t.get_instance_id(), t)
				itw.tween_property(t, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for k in range(prog[row].size(), cap):
			var e := Panel.new()
			e.custom_minimum_size = Vector2(52, 52)
			# içeri göçük yuva: biraz daha koyu zemin, üstte kalın (iç gölge), diğer kenarlarda ince açık çizgi
			var esb := StyleBoxFlat.new()
			esb.bg_color = Color(0.36, 0.4, 0.52, 0.1)
			esb.border_color = Color(0.22, 0.25, 0.36, 0.16)
			esb.border_width_top = 3
			esb.border_width_left = 1
			esb.border_width_right = 1
			esb.border_width_bottom = 1
			esb.set_corner_radius_all(14)
			esb.corner_detail = 8
			e.add_theme_stylebox_override("panel", esb)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flow.add_child(e)
		rows_box.add_child(rp)
	_insert_anim = null
	_layout.call_deferred()
	var show_sel := sel != null and mode == "edit"
	if show_sel != sel_bar.visible:
		sel_bar.visible = show_sel
		if show_sel:
			UIKit.pop_in(sel_bar, 0.0, 0.8)
	if sel != null and sel["idx"] < prog[sel["row"]].size():
		var ins: Dictionary = prog[sel["row"]][sel["idx"]]
		var cname: String = COND_NAME[ins["k"]]
		var caption := "Koşul: " + cname
		btn_cond.disabled = not levels[level_idx].get("conds", false) or ins["c"] == "W"
		if btn_cond.disabled:
			caption = "Koşul yok"
		# Button.text ayrıca çizilir; etiketle üst üste binmesin.
		btn_cond.text = ""
		UIKit.set_text(btn_cond, caption)
	if _exec["proc"] != "" and tile_nodes.has(_exec["proc"]) and _exec["idx"] < tile_nodes[_exec["proc"]].size():
		var t: Button = tile_nodes[_exec["proc"]][_exec["idx"]]
		(t.get_meta("ring") as Panel).visible = true
		t.pivot_offset = t.custom_minimum_size / 2
		t.scale = Vector2(1.12, 1.12)
		_run_tile = t
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
		audio.play("bump")
		var rp = rows_box.get_node_or_null(active_row)
		if rp:
			UIKit.shake(rp)
		return
	prog[active_row].append({"c": c, "k": ""})
	_insert_anim = {"row": active_row, "idx": prog[active_row].size() - 1}
	sel = null
	audio.play("pop", randf_range(0.95, 1.1))
	Sfx.call_ah("ui_thock")
	_prog_changed()

func _select(row: String, idx: int) -> void:
	if not _editable():
		return
	if sel != null and sel["row"] == row and sel["idx"] == idx:
		sel = null
	else:
		sel = {"row": row, "idx": idx}
	active_row = row
	audio.play("tap")
	_render_rows()

var _deleting := false

func _delete_sel() -> void:
	if sel == null or not _editable() or _deleting:
		return
	var row: String = sel["row"]
	var idx: int = sel["idx"]
	audio.play("del")
	Sfx.call_ah("ui_thock")
	var tiles: Array = tile_nodes.get(row, [])
	if instant or idx >= tiles.size():
		_finish_delete(row, idx)
		return
	# slot küçülerek kaybolur, sonra program güncellenir
	_deleting = true
	var t: Button = tiles[idx]
	t.pivot_offset = t.size / 2
	t.disabled = true
	var tw := _new_tw("slot_out:%d" % t.get_instance_id(), t)
	tw.set_parallel(true)
	tw.tween_property(t, "scale", Vector2(0.05, 0.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "modulate:a", 0.0, 0.1)
	tw.chain().tween_callback(func(): _finish_delete(row, idx))

func _finish_delete(row: String, idx: int) -> void:
	_deleting = false
	if idx < prog[row].size():
		prog[row].remove_at(idx)
	sel = null
	_prog_changed()

func _move_sel(d: int) -> void:
	if sel == null or not _editable():
		return
	var row: Array = prog[sel["row"]]
	var j: int = sel["idx"] + d
	if j < 0 or j >= row.size():
		audio.play("bump")
		return
	var t = row[sel["idx"]]
	row[sel["idx"]] = row[j]
	row[j] = t
	sel["idx"] = j
	audio.play("tap")
	_prog_changed()

func _cycle_cond() -> void:
	if sel == null or not _editable():
		return
	var ins: Dictionary = prog[sel["row"]][sel["idx"]]
	ins["k"] = {"": "o", "o": "x", "x": ""}[ins["k"]]
	audio.play("pop")
	_prog_changed()

func _clear_prog() -> void:
	if not _editable() or Program.block_count(prog) == 0 or _deleting:
		return
	audio.play("del")
	var all := []
	for row in tile_nodes:
		all.append_array(tile_nodes[row])
	if instant or all.is_empty():
		_finish_clear()
		return
	_deleting = true
	var tw := _new_tw("slot_clear", rows_box).set_parallel(true)
	for k in all.size():
		var t: Button = all[k]
		t.pivot_offset = t.size / 2
		t.disabled = true
		tw.tween_property(t, "scale", Vector2(0.05, 0.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(minf(0.15, k * 0.012))
	tw.chain().tween_callback(_finish_clear)

func _finish_clear() -> void:
	_deleting = false
	prog = {"main": [], "p1": [], "p2": []}
	sel = null
	_prog_changed()

func _cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % SPEEDS.size()
	UIKit.set_text(btn_speed, "%d×" % int(SPEEDS[speed_idx]))
	audio.play("tap")

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
	# Nova: hatalı hazır programlar analiz edilmeli
	for i in levels.size():
		if not levels[i].has("starter"):
			continue
		_start_level(i)
		prog = Program.parse_program(levels[i]["starter"])
		_run_toggle()
		for guard in 400:
			_update_queue(0.0)
			if mode == "paused":
				_run_toggle()   # molada dünyaya dokunmadan devam et
			elif mode != "running":
				break
		var na: Dictionary = nova_card.get_meta("last", {})
		var nok: bool = mode == "ended" and String(na.get("text", "")) != ""
		print("autotest Nova #%d %s: %s [%s] %s" % [i + 1, levels[i]["name"], "TAMAM" if nok else "HATA", end_reason, na.get("text", "")])
	var tip := Nova.suggest(levels[3], {"main": Program.parse_program({"main": ["F", "L", "F", "R", "F", "L", "F", "R"]})["main"], "p1": [], "p2": []})
	print("autotest Nova öneri: ", tip)
	# WebView ilerleme taşıma: sahte bir LevelDB günlüğünden okuma
	var fake := PackedByteArray([0x01, 0x02])
	fake.append_array("_https://appassets.androidplatform.net".to_ascii_buffer())
	fake.append_array(PackedByteArray([0, 1]))
	fake.append_array("kayipKuleler.v2".to_ascii_buffer())
	fake.append(1)
	fake.append_array("{\"unlocked\":7,\"best\":{\"0\":{\"blocks\":4,\"stars\":3}},\"progs\":{},\"seen\":{}}".to_ascii_buffer())
	fake.append_array(PackedByteArray([0, 9, 9]))
	fake.append_array("{\"unlocked\":9,\"best\":{\"0\":{\"blocks\":4,\"stars\":3},\"3\":{\"blocks\":8,\"stars\":3}},\"progs\":{},\"seen\":{}}".to_utf16_buffer())
	var tmp := "user://_mig_test"
	DirAccess.make_dir_recursive_absolute(tmp)
	var fw := FileAccess.open(tmp + "/000003.log", FileAccess.WRITE)
	fw.store_buffer(fake)
	fw.close()
	var found := _scan_leveldb(ProjectSettings.globalize_path(tmp))
	var mig_ok := found != "" and int(JSON.parse_string(found)["unlocked"]) == 9
	print("autotest göç (WebView localStorage): %s" % ("TAMAM" if mig_ok else "HATA"))
	DirAccess.remove_absolute(tmp + "/000003.log")
	DirAccess.remove_absolute(tmp)
	print("autotest: %d/%d" % [ok, levels.size()])
	get_tree().quit(0 if ok == levels.size() and mig_ok else 1)

## 15 temayı aynı seviyede gezdirip ekran görüntüsü alır.
## godot --path godot-program -- --themecycle=/tmp/temalar
func _themecycle(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	progress["seen"]["2"] = 1
	_start_level(2)
	for f in 50:
		await get_tree().process_frame
	var bad := []
	for id in 15:
		_apply_theme_id(id + 1)
		for f in 20:
			await get_tree().process_frame
		if theme_app.block_mat == null or theme_app.block_mat.shader == null:
			bad.append("shader %d" % (id + 1))
		var img := get_viewport().get_texture().get_image()
		if img == null or img.get_width() < 2:
			bad.append("görüntü %d" % (id + 1))
		else:
			var path := dir.path_join("tema-%02d.png" % (id + 1))
			if img.save_png(path) != OK:
				bad.append("kayıt %d" % (id + 1))
	print("themecycle: ", "TAMAM" if bad.is_empty() else "HATA " + str(bad))
	get_tree().quit(0 if bad.is_empty() else 1)


## Telefon genişlikleri, yatay ekran ve üst çentik: sekmeler örtüşmez, her biri seçilir,
## panel güvenli alanın içinde kalır, menü/ipucu/kamera/tema başparmak hizasındadır.
## godot --headless --path godot-program -- --layouttest
func _layouttest() -> void:
	instant = true
	var fails: Array = []
	var cases := [
		{"win": Vector2i(1080, 2400), "logical": false, "safe": Vector4(0, 100, 0, 72), "levels": [0, 3, 17, 19]},
		{"win": Vector2i(360, 780), "logical": true, "safe": Vector4(0, 48, 0, 28), "levels": [0, 17, 19]},
		{"win": Vector2i(480, 960), "logical": true, "safe": Vector4(12, 56, 12, 32), "levels": [0, 17]},
		{"win": Vector2i(2400, 1080), "logical": false, "safe": Vector4(48, 24, 48, 0), "levels": [0, 17]},
		{"win": Vector2i(800, 360), "logical": true, "safe": Vector4(20, 12, 20, 0), "levels": [17]},
	]
	for c in cases:
		await _apply_test_view(c["win"], c["logical"], c["safe"])
		for idx in c["levels"]:
			await _check_play_layout(int(idx), str(c["win"]), fails)
	print("layouttest: ", "TAMAM" if fails.is_empty() else "HATA " + str(fails))
	get_tree().quit(0 if fails.is_empty() else 1)

func _apply_test_view(win: Vector2i, logical: bool, safe: Vector4) -> void:
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_factor = 1.0
	root.content_scale_size = win if logical else Vector2i(720, 720)
	root.size = win
	safe_override = safe
	_safe_applied = Vector4(-2, -2, -2, -2)
	for f in 2:
		await get_tree().process_frame
	_layout()

func _check_play_layout(idx: int, tag: String, fails: Array) -> void:
	progress["seen"][str(idx)] = 1
	_start_level(idx)
	prog = Program.parse_program(levels[idx]["solution"])
	_render_rows()
	_layout()
	for f in 2:
		await get_tree().process_frame
	_layout()
	var vs := get_viewport().get_visible_rect().size
	var safe := _safe_margins()
	var area := Rect2(safe.x, safe.y, vs.x - safe.x - safe.z, vs.y - safe.y - safe.w)
	var where := "%s L%d" % [tag, idx + 1]
	if not _rect_inside(Rect2(panel.position, panel.size), area, 2.0):
		fails.append("%s panel güvenli alan dışında %s" % [where, panel.get_global_rect()])
	if panel.position.x < -1.0 or panel.position.y < -1.0 or panel.position.x + panel.size.x > vs.x + 1.0 or panel.position.y + panel.size.y > vs.y + 1.0:
		fails.append("%s panel ekran dışında" % where)
	var expect: Array = []
	for row in ROWS:
		if int(levels[idx]["slots"].get(row, 0)) > 0:
			expect.append(row)
	if row_tabs.get_child_count() != expect.size():
		fails.append("%s sekme sayısı %d" % [where, row_tabs.get_child_count()])
	var tab_rects: Array = []
	for k in row_tabs.get_child_count():
		var tab: Button = row_tabs.get_child(k)
		var rr: String = str(tab.get_meta("row"))
		if rr != expect[k]:
			fails.append("%s sekme sırası %s" % [where, rr])
		var tr: Rect2 = tab.get_global_rect()
		tab_rects.append(tr)
		if tr.size.x < 40.0 or tr.size.y < 40.0:
			fails.append("%s sekme küçük %s" % [where, tr])
		if not _rect_inside(tr, area, 1.0):
			fails.append("%s sekme güvenli alan dışında %s" % [where, tr])
		if _ancestor_clips(tab, tr.get_center()):
			fails.append("%s sekme kırpılmış %s" % [where, rr])
		var hit := _top_control_at(tr.get_center())
		if hit != tab:
			fails.append("%s sekme isabeti %s -> %s" % [where, rr, hit])
	for a in tab_rects.size():
		for b in range(a + 1, tab_rects.size()):
			if _rects_overlap(tab_rects[a], tab_rects[b]):
				fails.append("%s sekmeler örtüşüyor" % where)
	for row in expect:
		var tab: Button = _tab_named(row)
		tab.pressed.emit()
		if active_row != row:
			fails.append("%s seçilemedi %s" % [where, row])
	# görünen bloklar birbirinin ve paletin üstüne binmesin; merkezi kendi düğmesine gelsin
	var buttons: Array = []
	for row in expect:
		var rp := rows_box.get_node_or_null(NodePath(row))
		if rp is Control:
			rows_scroll.ensure_control_visible(rp)
	for f in 1:
		await get_tree().process_frame
	var scroll_r: Rect2 = rows_scroll.get_global_rect()
	for row in expect:
		var rp2 := rows_box.get_node_or_null(NodePath(row))
		if rp2 == null:
			continue
		var flow: Node = rp2.get_child(0).get_child(1)
		for t in flow.get_children():
			if not (t is BaseButton):
				continue
			var br: Rect2 = (t as Control).get_global_rect()
			buttons.append(br)
			if scroll_r.encloses(br) and not _ancestor_clips(t, br.get_center()):
				var hit2 := _top_control_at(br.get_center())
				if hit2 != t:
					fails.append("%s blok isabeti %s" % [where, row])
					break
	for a in buttons.size():
		for b in range(a + 1, buttons.size()):
			if _rects_overlap(buttons[a], buttons[b]):
				fails.append("%s bloklar örtüşüyor" % where)
				break
		if fails.size() > 0 and str(fails.back()).begins_with(where + " bloklar"):
			break
	var pals: Array = []
	for t in palette_box.get_children():
		if t is BaseButton:
			pals.append((t as Control).get_global_rect())
	for a in pals.size():
		for b in range(a + 1, pals.size()):
			if _rects_overlap(pals[a], pals[b]):
				fails.append("%s palet örtüşüyor" % where)
				break
	for b in [btn_menu, btn_hint, btn_cam]:
		var gr: Rect2 = b.get_global_rect()
		if not _rect_inside(gr, area, 1.0):
			fails.append("%s araç güvenli alan dışında" % where)
		if not Rect2(panel.position, panel.size).encloses(gr):
			fails.append("%s araç panel dışında" % where)
		if portrait and gr.get_center().y < vs.y * 0.45:
			fails.append("%s araç üstte kaldı" % where)
		if _top_control_at(gr.get_center()) != b:
			fails.append("%s araç isabeti" % where)
	if _rects_overlap(top_bar.get_global_rect(), theme_bar.get_global_rect()):
		fails.append("%s tema başlığın üstünde" % where)
	if idx == 0:
		_select("main", 0)
		var shown: String = (btn_cond.get_meta("label") as Label).text
		if btn_cond.text != "" or shown.find("\n") >= 0 or (shown.find("Her zaman") >= 0 and shown.find("Koşul yok") >= 0):
			fails.append("%s koşul yazısı üst üste '%s' / '%s'" % [where, btn_cond.text, shown])

func _tab_named(row: String) -> Button:
	for t in row_tabs.get_children():
		if str(t.get_meta("row")) == row:
			return t
	return null

func _rect_inside(inner: Rect2, outer: Rect2, slack: float) -> bool:
	return inner.position.x >= outer.position.x - slack and inner.position.y >= outer.position.y - slack \
			and inner.end.x <= outer.end.x + slack and inner.end.y <= outer.end.y + slack

func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	var inter := a.intersection(b)
	return inter.size.x > 0.6 and inter.size.y > 0.6

func _ancestor_clips(n: Node, pos: Vector2) -> bool:
	var p := n.get_parent()
	while p is Control:
		var c: Control = p
		if c.clip_contents and not c.get_global_rect().has_point(pos):
			return true
		p = c.get_parent()
	return false

func _top_control_at(pos: Vector2) -> Control:
	var box := {"ctl": null, "area": 1.0e20}
	_top_walk(ui_root, pos, box)
	return box["ctl"]

func _top_walk(n: Node, pos: Vector2, box: Dictionary) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			var ctl: Control = c
			var r: Rect2 = ctl.get_global_rect()
			if r.has_point(pos) and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and not _ancestor_clips(ctl, pos):
				var area := r.size.x * r.size.y
				if area < float(box["area"]):
					box["area"] = area
					box["ctl"] = ctl
			_top_walk(ctl, pos, box)

## Ekran görüntüsü: godot --path godot-program -- --shot=<seviye>:<dosya>[:<kare>]
## seviye 0 = başlık, -1 = seviye haritası, -2 = kazanma ekranı (seviye 12), -3 = duraklatma menüsü
func _shot(spec: String) -> void:
	var parts := spec.split(":")
	# montaj/vitrin: --shot=asm,14,5.0:dosya.png  ya da  --shot=pc,60:dosya.png
	# büyük final: --shot=fin,17.0:dosya.png
	if parts[0].begins_with("fin"):
		_open_assembly("final", 100)
		assembly.modulate.a = 1.0
		for f in 20:
			await get_tree().process_frame
		assembly.final_seq.set_process(false)
		assembly.final_seq.advance(float(parts[0].split(",")[1]))
		for f in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(parts[1])
		get_tree().quit()
		return
	if parts[0].begins_with("asm") or parts[0].begins_with("pc"):
		var a := parts[0].split(",")
		var n := int(a[1])
		var ids := []
		for i in range(1, n + 1):
			ids.append(i)
		progress["unlocked_parts"] = ids
		_open_assembly("assembly" if a[0] == "asm" else "showcase", n)
		assembly.modulate.a = 1.0
		for f in 20:
			await get_tree().process_frame
		if a[0] == "asm":
			assembly.t = 0.0
			assembly._snapped = false
			assembly.advance(float(a[2]))
			assembly.set_process(false)
		for f in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(parts[1])
		get_tree().quit()
		return
	var i := int(parts[0]) - 1
	var flags: PackedStringArray = parts[3].split(",") if parts.size() > 3 else PackedStringArray()
	# cutout: üst kamera çentiği + alt hareket çubuğu (görünür alan pikseli)
	if "cutout" in flags:
		safe_override = Vector4(18, 108, 18, 64)
	if i == -1:
		_show_title()
	elif i == -2:
		progress["unlocked"] = 19
		for j in 18:
			progress["best"][str(j)] = {"blocks": 1, "stars": 3 - int(j % 4 == 3)}
		_open_levels()
	elif i == -3 or i == -4:
		_start_level(11)
		_show("")
		prog = Program.parse_program(levels[11]["solution"])
		_render_rows()
		if i == -3:
			for f in 30:
				await get_tree().process_frame
			win_shown = true
			_prepare_win(3, 4, 4)
			_show("win")
		else:
			for f in 30:
				await get_tree().process_frame
			_open_pause()
	else:
		# 4. parça: virgüllü bayraklar — vN (kamerayı N kez çevir), intro (kavram kartı), starter (hazır program), cutout
		if not "intro" in flags:
			progress["seen"][str(i)] = 1
		else:
			progress["seen"].erase(str(i))
		_start_level(i)
		var sol: Dictionary = levels[i]["solution"]
		prog = Program.parse_program(levels[i]["starter"] if "starter" in flags else sol)
		_render_rows()
		for fl in flags:
			if fl.begins_with("v"):
				for k in int(fl.substr(1)):
					_rotate_view(1)
	var wait := 90
	if parts.size() > 3:
		for fl in parts[3].split(","):
			if fl.begins_with("f"):
				wait = int(fl.substr(1))   # fN: ilk görüntü için bekleme karesi (açılış animasyonunu yakalamak için)
	for f in wait:
		await get_tree().process_frame
	if parts.size() > 3 and "bolt" in parts[3].split(","):
		weather.strike(1.0)
		for f in 1:
			await get_tree().process_frame
	if i >= 0 and parts.size() > 2 and int(parts[2]) > 0:
		_run_toggle()
		for f in int(parts[2]):
			await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(parts[1])
	get_tree().quit()


# godot --headless --path godot-program -- --feeltest
## Gerçek zamanlı (instant olmayan) animasyon testi: açılış, koşu (1x ve hızlı), zafer, silme, durdurma.
func _feeltest() -> void:
	var fails := []
	var wait := func(sec: float) -> void:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < sec * 1000.0:
			await get_tree().process_frame
	progress["seen"]["1"] = 1
	_start_level(1)
	await get_tree().process_frame
	var small := 0
	for p in cell_nodes:
		if cell_nodes[p].scale.x < 0.99:
			small += 1
	if small == 0:
		fails.append("açılışta bloklar küçük başlamadı")
	await wait.call(1.0)
	for p in cell_nodes:
		var c: Node3D = cell_nodes[p]
		if not c.scale.is_equal_approx(Vector3.ONE) or absf(c.position.y - p.y) > 0.001:
			fails.append("açılış bitmedi: %s" % p)
			break
	if not objs["player"].get_meta("vis").scale.is_equal_approx(Vector3.ONE):
		fails.append("robot görünmedi")
	for spd in [0, speed_idx_max()]:
		_reset_world_hard()
		speed_idx = spd
		prog = Program.parse_program(levels[1]["solution"])
		_render_rows()
		_run_toggle()
		var t0 := Time.get_ticks_msec()
		var saw_stretch := false
		var saw_hop := false
		while not win_shown and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().process_frame
			var pose: Node3D = objs["player"].get_meta("pose")
			saw_stretch = saw_stretch or pose.scale.y > 1.05
			saw_hop = saw_hop or pose.position.y > 0.1
		if not win_shown:
			fails.append("hız %d: kazanılamadı" % spd)
		if not saw_stretch:
			fails.append("hız %d: adım esnemesi yok" % spd)
		if not saw_hop:
			fails.append("hız %d: dönüş zıplaması yok" % spd)
		await wait.call(1.5)
		var vis: Node3D = objs["player"].get_meta("vis")
		if not vis.scale.is_equal_approx(Vector3.ONE) or absf(vis.position.y) > 0.001:
			fails.append("hız %d: zafer sonrası robot nötre dönmedi" % spd)
		if objs["gem"].scale.x > 0.05:
			fails.append("kristal kaybolmadı")
		_retry()
		await wait.call(0.2)
		if objs["gem"].scale.x < 0.9:
			fails.append("tekrar denemede kristal geri gelmedi")
	# silme animasyonu: blok küçülür, sonra programdan çıkar
	_reset_world_hard()
	var n0: int = prog["main"].size()
	_select("main", 0)
	_delete_sel()
	await get_tree().process_frame
	if prog["main"].size() != n0:
		fails.append("silme animasyonu beklenmeden blok silindi")
	await wait.call(0.3)
	if prog["main"].size() != n0 - 1:
		fails.append("blok silinmedi")
	# çalışırken durdurma: robot tween'leri temizlenir
	_run_toggle()
	await wait.call(0.5)
	_reset_to_setup()
	await wait.call(0.4)
	var v2: Node3D = objs["player"].get_meta("vis")
	if not v2.transform.is_equal_approx(Transform3D.IDENTITY):
		fails.append("durdurunca robot katmanı sıfırlanmadı")
	# montaj sahnesi: 8 sn zaman çizelgesi, basılı tutma 2x, bitişte "Sonraki Seviye"; vitrin modu
	var asm: Control = ASSEMBLY_SCENE.instantiate()
	add_child(asm)
	var pre := []
	for i in range(1, 14):
		pre.append(i)
	pre.append(14)
	asm.setup("assembly", pre, 14)
	var tgt: Vector3 = PCPartLibrary.part(14).assembly_position
	asm.advance(3.0)
	if asm.new_node.position.distance_to(tgt) < 0.05:
		fails.append("montaj: parça 3. saniyede zaten yerindeydi")
	asm.holding = true
	for k in 30:
		asm._process(0.1)
	if not asm.finished:
		fails.append("montaj: 2x hızda 8 sn içinde bitmedi (t=%.2f)" % asm.t)
	if asm.new_node.position.distance_to(tgt) > 0.001 or not asm.btn_next.visible:
		fails.append("montaj: parça yerine oturmadı ya da Sonraki görünmüyor")
	if not ("Parça 14/100" in asm.lbl_caption.text and "Takıldı" in asm.lbl_caption.text):
		fails.append("montaj yazısı: " + asm.lbl_caption.text)
	asm.setup("assembly", pre, 14)
	asm._skip()
	if not asm.finished:
		fails.append("montaj: Geç çalışmadı")
	asm.setup("showcase", pre)
	if asm.nodes.size() != pre.size() or not asm.btn_test.visible:
		fails.append("vitrin: parça sayısı ya da test butonu")
	asm.queue_free()
	# büyük final: 30 sn zaman çizelgesi (güç tuşu, BIOS satırları, masaüstü, butonlar)
	var asm2: Control = ASSEMBLY_SCENE.instantiate()
	add_child(asm2)
	var all100 := []
	for i in range(1, 101):
		all100.append(i)
	asm2.setup("assembly", all100, 100)
	asm2.start_final(true)
	var fs = asm2.final_seq
	if fs == null:
		fails.append("final başlamadı")
	else:
		fs.advance(4.0)
		if not fs._power_pressed:
			fails.append("final: güç tuşuna basılmadı")
		fs.advance(17.0)
		if fs._lines_shown < 15 or not (fs.screen_quad.visible or fs._glb_screen_on):
			fails.append("final: BIOS satırları eksik (%d)" % fs._lines_shown)
		fs.skip()
		if not fs.done or not fs.desk_root.visible or not fs._btns.visible:
			fails.append("final: masaüstü ya da butonlar görünmüyor")
	if fs != null and fs._glb_screen_node == null and AssetLoader.exists("res://assets/models/pc_parts/part_094.glb"):
		fails.append("final: monitör modelinin MonitorScreen yuvası bağlanmadı")
	asm2.queue_free()
	# ses/haptik motoru: bütün sesler önceden üretilmiş olmalı
	var ah := Sfx.ah()
	if ah == null:
		fails.append("AudioHaptics autoload yok")
	else:
		for nm in ["step0", "step5", "cap", "error", "relay", "thock", "snap", "power", "fan", "post", "chord"]:
			if not ah.has_sound(nm):
				fails.append("ses yok: " + nm)
	# devre kampanyası: klon + AND, direnç, kondansatör içeren seviyeler oyun döngüsünde de kazanılmalı
	for li in [41, 61, 71, 81, 99]:
		_reset_world_hard()
		instant = true
		_start_level(li)
		prog = Program.parse_program(levels[li]["solution"])
		_run_toggle()
		for guard in 300:
			_update_queue(0.0)
			if mode != "running":
				break
		instant = false
		if not win_shown:
			fails.append("kampanya #%d kazanılamadı (%s)" % [li + 1, mode])
	# hava durumu: her ön ayar uygulanır, şimşek gökte ve sahne ışığında görünür
	for k in Weather.PRESETS:
		weather.apply(k, 3.0)
		var base_sun := sun.light_energy
		weather.strike(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		if weather.flash <= 0.0 or sun.light_energy <= base_sun:
			fails.append("şimşek çalışmadı: " + k)
		await wait.call(0.6)
		if weather.flash > 0.0:
			fails.append("şimşek sönmedi: " + k)
	for ch in 9:
		if not Weather.PRESETS.has(Weather.for_chapter(ch)):
			fails.append("bölüm %d için hava yok" % ch)
	# 15 tema: shader, dekor ve hava sistemi ayakta kalır
	for id in 15:
		_apply_theme_id(id + 1)
		if theme_app.block_mat == null or theme_app.block_mat.shader == null:
			fails.append("shader %d" % (id + 1))
		elif int(theme_app.block_mat.get_shader_parameter("visual_style")) != id:
			fails.append("stil %d" % (id + 1))
		if theme_app.props == null or not is_instance_valid(theme_app.props) or theme_app.props.get_child_count() < 1:
			fails.append("dekor %d" % (id + 1))
		if weather.mat == null or weather.mat.shader == null:
			fails.append("hava shader %d" % (id + 1))
	print("feeltest: ", "TAMAM" if fails.is_empty() else "HATA " + str(fails))
	get_tree().quit(0 if fails.is_empty() else 1)

func speed_idx_max() -> int:
	return SPEEDS.size() - 1

func _reset_world_hard() -> void:
	win_shown = false
	_show("")
	if mode != "edit":
		_reset_to_setup()

