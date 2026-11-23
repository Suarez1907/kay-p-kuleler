## Montaj sahnesi (AssemblyScene.tscn) ve "Bilgisayarım" vitrini.
## Kendi 3B dünyası olan bir SubViewport'ta stüdyo ışığı altında toplanan bütün parçaları gösterir.
## Montaj modu — 8 saniyelik zaman çizelgesi (kendi saatiyle; basılı tutunca 2x, "Geç" ile sona atlar):
##   0.0–2.0  kamera genel görünümden yeni parçanın yuvasına yaklaşır
##   2.0–4.5  parça yukarıdan dönerek hizalanır ve yuvasına iner
##   4.5–5.5  oturma anı: kıvılcım (GPUParticles3D), mikro sarsıntı, komşu parçalara yayılan enerji
##   5.5–8.0  kamera geri çekilir, parçanın adı ve ilerleme belirir; sonunda "Sonraki Seviye"
## Vitrin modu — parmakla/fareyle 360° döndürme, iki parmak ya da tekerlekle yakınlaştırma.
extends Control

signal next_level
signal closed
signal test_requested
signal main_menu
signal style_changed(style: Dictionary)

## PC özelleştirme: kasa rengi, RGB ışık rengi, fan modu (main.gd ilerleme kaydında tutar)
const CASE_COLORS := [["SİYAH", "#1c1e24"], ["BEYAZ", "#e6e8ec"], ["LACİVERT", "#1d3a6e"], ["KIRMIZI", "#8e1f2a"], ["YEŞİL", "#1f5c40"]]
const RGB_COLORS := [["MOR", "#8a5cff"], ["CYAN", "#00E5FF"], ["AMBER", "#F59E0B"], ["YEŞİL", "#3cf08a"], ["KAPALI", "#000000"]]
const FAN_MODES := [["SESSİZ", 0.45], ["NORMAL", 1.0], ["TURBO", 1.9]]
var pc_style := {"case": 0, "rgb": 0, "fan": 1}
var _style_panel: PanelContainer
var _phase_cards: HBoxContainer
var _sys_bar: BP.Bar
var _sys_lbl: Label
var _badge: Label
var _btn_style: Button
var _bottom: VBoxContainer

const FINAL_SCRIPT := preload("res://scripts/pc/final_boot_sequence.gd")
var final_seq: Node = null       # 100. parçadan sonra büyük final (FinalBootSequence)
var fan_speed := 1.0             # fan dönüş çarpanı (final: 0 devirden hızlanır)
var real_parts: Array = []       # finalden "Atölyede İncele"ye dönerken gösterilecek gerçek parçalar
const DURATION := 8.0

var mode := "showcase"           # "assembly" | "showcase"
var unlocked: Array = []
var part_id := 0
var t := 0.0
var holding := false
var finished := false
var _snapped := false
var _shake := 0.0
var from_showcase := false       # test montajı bitince vitrine dönülür
var director: CinematicDirector = null   # Blender sinematiği (yoksa Tween akışı)
var duration := DURATION
var _whooshed := false

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var parts_root: Node3D
var nodes := {}                  # part_id -> Node3D
var sparks: GPUParticles3D
var new_node: Node3D
var target_pos := Vector3.ZERO

# kamera yörüngesi
var cam_target := Vector3.ZERO
var yaw := deg_to_rad(38.0)
var pitch := deg_to_rad(26.0)
var dist := 11.0
var _overview := {}
var _close := {}
var _mid := {}
var _drag = null
var _touches := {}
var _pinch0 := 0.0
var _idle := 0.0

# arayüz
var lbl_title: Label
var lbl_caption: Label
var lbl_sub: Label
var lbl_hint: Label
var btn_skip: Button
var btn_next: Button
var btn_back: Button
var btn_test: Button
var caption_box: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	# montaj için son işlem (kendi katmanında, arayüzün altında)
	var post := VisualFX.post_rect()
	add_child(post)
	VisualFX.apply_grade(post, 9, VisualFX.quality)
	_build_world()
	_build_ui()

# ---------------------------------------------------------------------------
# Kurulum
func setup(m: String, unlocked_ids: Array, pid := 0) -> void:
	if final_seq != null:
		final_seq.cleanup()
		final_seq.queue_free()
		final_seq = null
	_end_director()
	_unbatch()
	duration = DURATION
	_whooshed = false
	fan_speed = float(FAN_MODES[int(pc_style.get("fan", 1)) % FAN_MODES.size()][1])
	mode = m
	unlocked = unlocked_ids.duplicate()
	part_id = pid
	t = 0.0
	finished = false
	_snapped = false
	for c in parts_root.get_children():
		c.queue_free()
	nodes = {}
	new_node = null
	for id in unlocked:
		if mode == "assembly" and int(id) == part_id:
			continue
		_spawn(int(id))
	if mode == "assembly":
		new_node = _spawn(part_id)
		target_pos = new_node.position
		var p := PCPartLibrary.part(part_id)
		var all_ids := unlocked.duplicate()
		if not (part_id in all_ids):
			all_ids.append(part_id)
		_overview = _frame(PCPartLibrary.bounds(all_ids), 1.0)
		var sz := p.assembly_scale
		var mx := maxf(sz.x, maxf(sz.y, sz.z))
		_close = {"target": p.assembly_position, "dist": clampf(mx * 3.2 + 0.8, 1.6, 6.5), "yaw": yaw, "pitch": deg_to_rad(30.0)}
		_mid = {"target": _overview["target"].lerp(p.assembly_position, 0.45), "dist": lerpf(_overview["dist"], _close["dist"], 0.5), "yaw": yaw - 0.25, "pitch": deg_to_rad(28.0)}
		lbl_caption.text = "Parça %d/%d: %s — Takıldı" % [part_id, PCPartLibrary.COUNT, p.part_name]
		lbl_sub.text = "Faz %d · %s   ·   Toplanan: %d/%d" % [p.phase_index + 1, p.phase_name, all_ids.size(), PCPartLibrary.COUNT]
		lbl_title.text = "MONTAJ"
		_badge.text = "%d/%d" % [all_ids.size(), PCPartLibrary.COUNT]
		caption_box.modulate.a = 0.0
		_apply_cam(_overview)
		# Blender sinematiği: faza uygun arketip / faz finali; yüklenemezse eski Tween akışı
		var d := CinematicDirector.new()
		add_child(d)
		new_node.visible = true
		if d.begin(world, part_id, new_node, p.assembly_scale):
			director = d
			duration = d.duration
			d.cue.connect(_on_cue)
		else:
			d.queue_free()
		advance(0.0)
	else:
		var b := PCPartLibrary.bounds(unlocked) if not unlocked.is_empty() else AABB(Vector3(-1, 0, -1), Vector3(2, 1, 2))
		var f := _frame(b, 1.05)
		cam_target = f["target"]
		dist = f["dist"]
		lbl_title.text = "BİLGİSAYARIM"
		_batch_static.call_deferred()
		lbl_caption.text = "Sürükle: döndür · iki parmak: yakınlaştır"
		lbl_sub.text = _phase_summary()
		caption_box.modulate.a = 1.0
		_update_cam()
	btn_skip.visible = mode == "assembly"
	btn_next.visible = false
	btn_back.visible = mode == "showcase"
	btn_test.visible = mode == "showcase" and unlocked.size() < PCPartLibrary.COUNT and OS.is_debug_build()
	lbl_hint.visible = mode == "assembly"
	_bottom.visible = mode == "showcase"
	_btn_style.visible = mode == "showcase"
	_style_panel.visible = false
	if mode == "showcase":
		_badge.text = "%d/%d" % [unlocked.size(), PCPartLibrary.COUNT]
		_render_bottom()
	_layout()
	_layout.call_deferred()

func _phase_summary() -> String:
	var per := []
	for ph in 10:
		var n := 0
		for id in unlocked:
			if (int(id) - 1) / 10 == ph:
				n += 1
		per.append(n)
	var done := 0
	for n in per:
		if n == 10:
			done += 1
	return "Tamamlanan faz: %d/10   ·   Sıradaki parça: %s" % [done, _next_name()]

func _next_name() -> String:
	for i in range(1, PCPartLibrary.COUNT + 1):
		if not (i in unlocked):
			return PCPartLibrary.part(i).part_name
	return "— bilgisayar tamamlandı!"

func _spawn(id: int) -> Node3D:
	var n := PartBuilder.build(PCPartLibrary.part(id))
	AssetLoader.set_gi_dynamic(n)   # takılı parçalar oyuncuya göre değişir: fırınlanmaz, problardan ışık alır
	parts_root.add_child(n)
	nodes[id] = n
	_style_node(id, n)
	return n

## Kasa parçalarının (faz 9) koyu yüzeyleri kasa rengine, tüm RGB/Accent yüzeyleri seçili ışık rengine boyanır
## Performans (vitrin): parlamayan, dönmeyen bütün parça yüzeyleri malzemeye göre birkaç birleşik meshte toplanır
## (~1000 çizim çağrısı → malzeme sayısı kadar). Montaj/final animasyonları için _unbatch() orijinallere döner.
var _batch_root: Node3D = null

func _batch_static() -> void:
	_unbatch()
	if mode != "showcase" or final_seq != null:
		return
	var groups := {}
	var hidden := []
	for id in nodes:
		var n: Node3D = nodes[id]
		var spinner = n.get_meta("spinner") if n.has_meta("spinner") else null
		for mi in PartBuilder._meshes_in(n):
			var m: MeshInstance3D = mi
			if m.mesh == null or not m.visible or (spinner != null and (m == spinner or spinner.is_ancestor_of(m))):
				continue
			if m.material_override is ShaderMaterial:
				continue
			var xf := parts_root.global_transform.affine_inverse() * m.global_transform
			for si in m.mesh.get_surface_count():
				var mat: Material = m.get_active_material(si)
				var key = _mat_key(mat)
				if not groups.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[key] = {"st": st, "mat": mat, "shadow": false}
				var g: Dictionary = groups[key]
				(g["st"] as SurfaceTool).append_from(m.mesh, si, xf)
				if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					g["shadow"] = true
			hidden.append(m)
	if groups.is_empty():
		return
	_batch_root = Node3D.new()
	_batch_root.name = "StaticBatch"
	parts_root.add_child(_batch_root)
	for key in groups:
		var g: Dictionary = groups[key]
		var bm := MeshInstance3D.new()
		bm.mesh = (g["st"] as SurfaceTool).commit()
		bm.material_override = g["mat"]
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_batch_root.add_child(bm)
	for m in hidden:
		m.visible = false
	_batch_root.set_meta("hidden", hidden)

## Görsel olarak eş malzemeler aynı gruba düşer (glTF her dosyada aynı adlı malzemeyi ayrı kopyalar)
static func _mat_key(mat: Material):
	if mat is StandardMaterial3D:
		var m: StandardMaterial3D = mat
		return "%s|%s|%.2f|%.2f|%s|%s|%d|%s|%s" % [m.albedo_color.to_html(), m.albedo_texture.resource_path if m.albedo_texture else "",
			m.metallic, m.roughness, m.emission_enabled, m.emission.to_html(), m.transparency, m.emission_energy_multiplier, m.normal_texture != null]
	return mat.get_instance_id() if mat != null else 0

func _unbatch() -> void:
	if _batch_root == null or not is_instance_valid(_batch_root):
		_batch_root = null
		return
	for m in _batch_root.get_meta("hidden", []):
		if is_instance_valid(m):
			(m as MeshInstance3D).visible = true
	_batch_root.queue_free()
	_batch_root = null

func _style_node(id: int, n: Node3D) -> void:
	var cc := Color(CASE_COLORS[int(pc_style.get("case", 0)) % CASE_COLORS.size()][1])
	var rc := Color(RGB_COLORS[int(pc_style.get("rgb", 0)) % RGB_COLORS.size()][1])
	if (id - 1) / 10 == 8:
		for mn in ["DarkMetal", "BlackPlastic"]:
			for m in AssetLoader.unique_surfaces(n, mn):
				if m is StandardMaterial3D:
					(m as StandardMaterial3D).albedo_color = cc
	for mn in ["RGB", "Accent"]:
		for m in AssetLoader.unique_surfaces(n, mn):
			if m is StandardMaterial3D:
				var sm: StandardMaterial3D = m
				sm.albedo_color = rc if rc.v > 0.01 else Color("#202128")
				sm.emission_enabled = rc.v > 0.01
				sm.emission = rc
				sm.emission_energy_multiplier = 3.0

func _restyle() -> void:
	_unbatch()
	for id in nodes:
		_style_node(int(id), nodes[id])
	if mode == "showcase" and final_seq == null:
		_batch_static()
	if final_seq == null:
		fan_speed = float(FAN_MODES[int(pc_style.get("fan", 1)) % FAN_MODES.size()][1])
	_update_style_panel()
	style_changed.emit(pc_style.duplicate())

func _frame(b: AABB, k: float) -> Dictionary:
	var r := b.size.length() * 0.5
	return {"target": b.get_center(), "dist": clampf(r * 2.35 * k + 1.0, 3.0, 24.0), "yaw": yaw, "pitch": pitch}

func _build_world() -> void:
	world = Node3D.new()
	vp.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#232633")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4bcdc")
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = false
	# ADIM 7: sıcak atölye 2K HDRI'sı ortam + yansıma ışığı, AgX (arka plan rengi aynı kalır)
	StudioLighting.apply(env, StudioLighting.WORKSHOP, 1.0, 0.7, 1.3)
	env.glow_intensity = 0.6
	we.environment = env
	world.add_child(we)
	# fırınlanmış atölye (LightmapGI): varsa masa/raflar ve statik dolgu ışıkları ondan gelir
	var baked: Node3D = _load_baked_workshop()
	# stüdyo ışıkları: sıcak ana ışık, soğuk kenar ışığı, yumuşak dolgu
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe9d2")
	key.light_energy = 2.1
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.light_bake_mode = Light3D.BAKE_DYNAMIC   # dolaylı sıçrama fırında, parçaların keskin gölgesi gerçek zamanlı
	world.add_child(key)
	key.look_at_from_position(Vector3(5, 9, 6), Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#7fb4ff")
	rim.light_energy = 1.1
	rim.visible = baked == null                  # fırınlanmışta Fills/Rim (BAKE_STATIC) kullanılır
	world.add_child(rim)
	rim.look_at_from_position(Vector3(-6, 4, -7), Vector3.ZERO, Vector3.UP)
	var spot := SpotLight3D.new()
	spot.light_color = Color("#ffd9a8")
	spot.light_energy = 3.0
	spot.spot_range = 16.0
	spot.spot_angle = 34.0
	spot.position = Vector3(0.5, 8.5, 2.5)
	spot.visible = baked == null
	world.add_child(spot)
	spot.look_at(Vector3(0.6, 0.8, 0), Vector3.UP)
	# Blender atölye sahnesi (masa, raflar, havya istasyonu, alet çantası, softbox ışıklar); yoksa düz masa + perde
	var shop: Node3D = null
	if baked != null:
		world.add_child(baked)
		shop = baked.get_node_or_null("Workshop")
		AssetLoader.enhance_materials(shop)
	else:
		shop = AssetLoader.scene_model("workshop") if ComponentFactory.use_models else null
		if shop != null:
			world.add_child(shop)
	var desk := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(16, 0.2, 10)
	desk.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("#2a2420")
	dmat.roughness = 0.45
	dmat.metallic_specular = 0.6
	desk.material_override = dmat
	desk.position = Vector3(1.4, -0.1, 0)
	world.add_child(desk)
	var wall := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(40, 18)
	wall.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("#2b2f3d")
	wmat.roughness = 1.0
	wall.material_override = wmat
	wall.position = Vector3(1.4, 6, -6)
	world.add_child(wall)
	desk.visible = shop == null
	wall.visible = shop == null
	parts_root = Node3D.new()
	world.add_child(parts_root)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 120.0
	world.add_child(cam)
	cam.current = true
	# oturma kıvılcımları
	sparks = GPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 70
	sparks.lifetime = 0.7
	sparks.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -7.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var cr := Gradient.new()
	cr.set_color(0, Color(1.0, 0.95, 0.7))
	cr.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var ct := GradientTexture1D.new()
	ct.gradient = cr
	pm.color_ramp = ct
	sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	sparks.draw_pass_1 = q
	world.add_child(sparks)

const BAKED_WORKSHOP := "res://scenes/baked/assembly_workshop.tscn"

func _load_baked_workshop() -> Node3D:
	if not ComponentFactory.use_models or not ResourceLoader.exists(BAKED_WORKSHOP):
		return null
	var root: Node3D = (load(BAKED_WORKSHOP) as PackedScene).instantiate()
	var lm := root.get_node_or_null("LightmapGI") as LightmapGI
	if lm == null or lm.light_data == null:
		root.free()
		return null
	var bs := root.get_node_or_null("BakeSun")
	if bs != null:
		root.remove_child(bs)
		bs.free()
	return root

func _build_ui() -> void:
	theme = UIKit.make_theme()
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 14
	top.offset_right = -18
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	btn_back = UIKit.round_button("back", func(): closed.emit(), 48)
	top.add_child(btn_back)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", BP.chamfer(Color("#0B192EB8"), BP.R_STD, Color(BP.BORDER_STEEL, 0.8), BP.BORDER_W, 8))
	var tph := HBoxContainer.new()
	tph.add_theme_constant_override("separation", 12)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	tv.add_child(BP.tag("SYS // BİLGİSAYAR", 12, Color(BP.ACCENT_CYAN, 0.8)))
	lbl_title = UIKit.label("", 24, BP.TEXT_PRIMARY, UIKit.font_black)
	tv.add_child(lbl_title)
	tph.add_child(tv)
	_badge = UIKit.label("", 20, BP.ACCENT_AMBER, UIKit.font_black)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tph.add_child(_badge)
	tp.add_child(tph)
	top.add_child(tp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	_btn_style = UIKit.button("ÖZELLEŞTİR", Color.WHITE, _toggle_style, 18, "gear", UIKit.INK, 48)
	top.add_child(_btn_style)
	btn_test = UIKit.button("MONTAJI TEST ET (+1)", BP.ACCENT_AMBER, func(): test_requested.emit(), 18, "sparkle", UIKit.INK, 48)
	top.add_child(btn_test)
	btn_skip = UIKit.button("GEÇ", Color.WHITE, _skip, 20, "step", UIKit.INK, 48)
	top.add_child(btn_skip)
	# alt yazı kartı (montaj sırasında parça adı)
	var cb := PanelContainer.new()
	cb.add_theme_stylebox_override("panel", BP.chamfer(BP.SURFACE_MODAL, BP.R_STD, BP.BORDER_STEEL, BP.BORDER_W, 14))
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	lbl_caption = UIKit.label("", 20, BP.TEXT_PRIMARY, UIKit.font_black)
	lbl_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub = BP.tag("", 13, BP.ACCENT_AMBER)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(lbl_caption)
	cv.add_child(lbl_sub)
	cb.add_child(cv)
	add_child(cb)
	caption_box = cb
	# vitrin altı: SİSTEM MONTAJI // %X + faz kartları
	_bottom = VBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 8)
	add_child(_bottom)
	var sh := HBoxContainer.new()
	_sys_lbl = BP.tag("", 13, BP.ACCENT_AMBER)
	_sys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_sys_lbl)
	_bottom.add_child(sh)
	_sys_bar = BP.Bar.new(0.0, 4.0)
	_bottom.add_child(_sys_bar)
	var psc := ScrollContainer.new()
	psc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	psc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	psc.custom_minimum_size = Vector2(0, 66)
	_phase_cards = HBoxContainer.new()
	_phase_cards.add_theme_constant_override("separation", 8)
	psc.add_child(_phase_cards)
	_bottom.add_child(psc)
	# özelleştirme paneli
	_style_panel = PanelContainer.new()
	_style_panel.add_theme_stylebox_override("panel", BP.modal_box(16))
	_style_panel.visible = false
	add_child(_style_panel)
	btn_next = UIKit.button("SONRAKİ SEVİYE", UIKit.GREEN, func(): next_level.emit(), 22, "play", Color.WHITE, 60)
	add_child(btn_next)
	lbl_hint = BP.tag("BASILI TUT: 2× HIZ", 13)
	add_child(lbl_hint)
	resized.connect(_layout)

func _render_bottom() -> void:
	for c in _phase_cards.get_children():
		c.queue_free()
	var total := unlocked.size()
	_sys_lbl.text = "SİSTEM MONTAJI // %%%d   ·   SIRADAKİ: %s" % [int(round(100.0 * total / PCPartLibrary.COUNT)), _next_name().to_upper()]
	_sys_bar.set_value(float(total) / PCPartLibrary.COUNT)
	var names := ["ANAKART", "PSU", "CPU", "RAM", "DEPOLAMA", "GPU", "SOĞUTMA", "I/O", "KASA", "ÇEKİRDEK"]
	for ph in 10:
		var n := 0
		for id in unlocked:
			if (int(id) - 1) / 10 == ph:
				n += 1
		var p := PanelContainer.new()
		var full := n == 10
		p.add_theme_stylebox_override("panel", BP.chamfer(BP.SURFACE_PANEL, BP.R_STD, BP.ACCENT_CYAN if full else (BP.BORDER_STEEL if n > 0 else Color(BP.TEXT_MUTED, 0.4)), BP.BORDER_W, 8))
		p.custom_minimum_size = Vector2(118, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.add_child(BP.tag("%02d // %s" % [ph + 1, names[ph]], 12, BP.ACCENT_CYAN if full else (BP.TEXT_PRIMARY if n > 0 else BP.TEXT_MUTED)))
		v.add_child(UIKit.label("%d/10" % n, 16, BP.ACCENT_AMBER if n > 0 else BP.TEXT_MUTED, UIKit.font_black))
		var bar := BP.Bar.new(n / 10.0, 3.0)
		v.add_child(bar)
		p.add_child(v)
		_phase_cards.add_child(p)

func _toggle_style() -> void:
	_style_panel.visible = not _style_panel.visible
	if _style_panel.visible:
		_update_style_panel()
	_layout()

func _update_style_panel() -> void:
	if _style_panel == null:
		return
	for c in _style_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(BP.tag("PC // ÖZELLEŞTİRME", 12))
	for grp in [["KASA RENGİ", "case", CASE_COLORS], ["RGB IŞIK", "rgb", RGB_COLORS], ["FAN", "fan", FAN_MODES]]:
		v.add_child(BP.tag(grp[0], 11, BP.TEXT_MUTED))
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 6)
		h.add_theme_constant_override("v_separation", 6)
		var opts: Array = grp[2]
		for k in opts.size():
			var b := Button.new()
			b.text = String(opts[k][0])
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 44)
			b.add_theme_font_override("font", UIKit.font_black)
			b.add_theme_font_size_override("font_size", 13)
			var key: String = grp[1]
			BP.style_button(b, BP.Variant.CYAN_OUTLINE if int(pc_style.get(key, 0)) == k else BP.Variant.DEFAULT, BP.R_SMALL)
			var kk := k
			b.pressed.connect(func():
				pc_style[key] = kk
				Sfx.call_ah("ui_thock")
				_restyle())
			h.add_child(b)
		v.add_child(h)
	_style_panel.add_child(v)

func _layout() -> void:
	if caption_box == null:
		return
	var vs := size
	var w := minf(vs.x - 32.0, 720.0)
	lbl_caption.custom_minimum_size = Vector2(w - 32.0, 0)
	lbl_sub.custom_minimum_size = Vector2(w - 32.0, 0)
	caption_box.size = Vector2.ZERO
	caption_box.size = caption_box.get_combined_minimum_size()
	caption_box.position = Vector2((vs.x - caption_box.size.x) / 2.0, vs.y - caption_box.size.y - 110.0)
	btn_next.reset_size()
	btn_next.position = Vector2(vs.x - btn_next.size.x - 22.0, vs.y - btn_next.size.y - 22.0)
	lbl_hint.reset_size()
	lbl_hint.position = Vector2(22.0, vs.y - lbl_hint.size.y - 22.0)
	if _bottom != null:
		var bw := minf(vs.x - 36.0, 1240.0)
		_bottom.size = Vector2(bw, 0)
		_bottom.reset_size()
		_bottom.size.x = bw
		_bottom.position = Vector2((vs.x - bw) / 2.0, vs.y - _bottom.get_combined_minimum_size().y - 14.0)
		if mode == "showcase":
			caption_box.position.y = _bottom.position.y - caption_box.size.y - 10.0
	if _style_panel != null and _style_panel.visible:
		_style_panel.reset_size()
		_style_panel.custom_minimum_size.x = minf(420.0, vs.x - 36.0)
		_style_panel.reset_size()
		_style_panel.position = Vector2(vs.x - _style_panel.size.x - 18.0, 76.0)

# ---------------------------------------------------------------------------
# Zaman çizelgesi
func _process(dt: float) -> void:
	if final_seq != null:
		pass   # final kendi saatiyle ilerler
	elif mode == "assembly" and not finished:
		advance(dt * (2.5 if holding else 1.0))
	elif mode == "showcase":
		_idle += dt
		if _drag == null and _touches.is_empty() and _idle > 2.5:
			yaw += dt * 0.12
		_update_cam()
	_animate_parts(dt)

func _skip() -> void:
	if final_seq != null:
		final_seq.skip()
		return
	if mode == "assembly" and not finished:
		advance(duration - t + 0.001)

func _end_director() -> void:
	for id in nodes:
		(nodes[id] as Node3D).visible = true
	if director != null:
		director.end(cam)
		director.queue_free()
		director = null

## Sinematik kare olayları: parça süzülmesi, tam oturma (kıvılcım + haptik), mekanik kilitler
func _on_cue(kind: String, pos: Vector3) -> void:
	match kind:
		"whoosh":
			Sfx.asmr().play_part_whoosh()
		"snap":
			_snapped = true
			sparks.global_position = pos
			sparks.restart()
			sparks.emitting = true
			Sfx.call_ah("snap")
		"lock":
			Sfx.asmr().play_part_snap()
			Sfx.call_ah("vibrate", [25])

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## Zamanı ilerletir (testler de doğrudan çağırır). Bütün durum t'den hesaplanır.
func advance(dt: float) -> void:
	t = minf(t + dt, duration)
	if new_node == null:
		return
	if director != null:
		_advance_cinematic()
		return
	if t >= 0.4 and not _whooshed:
		_whooshed = true
		Sfx.asmr().play_part_whoosh()
	# 1) kamera
	if t < 2.0:
		_apply_cam(_blend(_overview, _close, _ease(t / 2.0)))
	elif t < 5.5:
		_apply_cam(_close)
	else:
		_apply_cam(_blend(_close, _mid, _ease((t - 5.5) / 2.5)))
	# 2) parça inişi: yukarıdan, 90° dönmüş halde hizalanarak yuvasına iner
	var p := PCPartLibrary.part(part_id)
	var lift := 1.6 + p.assembly_scale.y * 1.5
	if t < 2.0:
		var a := _ease(t / 2.0)
		new_node.visible = true
		new_node.position = target_pos + Vector3(0.35, lift + 0.6 * (1.0 - a), 0.0)
		new_node.rotation = Vector3(0, PI / 2 * (1.0 - a * 0.25), 0)
		new_node.scale = Vector3.ONE * lerpf(0.6, 1.0, a)
		PartBuilder.set_glow(new_node, 0.6 + 0.4 * sin(t * 9.0))
	elif t < 4.5:
		var u := (t - 2.0) / 2.5
		var al := _ease(clampf(u / 0.55, 0.0, 1.0))      # önce hizalan (dönüş ve yatay kayma)
		var dn := _ease(clampf((u - 0.35) / 0.65, 0.0, 1.0))   # sonra in
		new_node.position = target_pos + Vector3(0.35 * (1.0 - al), lift * (1.0 - dn), 0.0)
		new_node.rotation = Vector3(0, PI / 2 * 0.75 * (1.0 - al), 0)
		new_node.scale = Vector3.ONE
		PartBuilder.set_glow(new_node, 0.5 + 0.5 * sin(t * 12.0))
	else:
		new_node.position = target_pos
		new_node.rotation = Vector3.ZERO
		new_node.scale = Vector3.ONE
	# 3) oturma anı
	if t >= 4.5 and not _snapped:
		_snapped = true
		_shake = 1.0
		sparks.position = target_pos + Vector3(0, p.assembly_scale.y * 0.5, 0)
		sparks.restart()
		sparks.emitting = true
		Sfx.call_ah("snap")
	if t >= 4.5:
		var k := t - 4.5
		_shake = maxf(0.0, 1.0 - k / 0.55)
		PartBuilder.set_glow(new_node, maxf(0.0, 1.6 - k * 1.2))
		# enerji dalgası: komşu parçalar uzaklıklarına göre sırayla parlar
		for id in nodes:
			if id == part_id:
				continue
			var n: Node3D = nodes[id]
			var d := n.position.distance_to(target_pos)
			var wave := 1.0 - absf(k * 4.0 - d) / 0.9
			PartBuilder.set_glow(n, clampf(wave, 0.0, 1.0) * 1.2 * clampf(1.0 - d / 6.0, 0.0, 1.0))
	if _shake > 0.0:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.035 * _shake * _shake
	# 4) yazı ve bitiş
	caption_box.modulate.a = clampf((t - 5.5) / 0.6, 0.0, 1.0)
	if t >= duration and not finished and part_id == PCPartLibrary.COUNT:
		finished = true
		for id in nodes:
			PartBuilder.set_glow(nodes[id], 0.0)
		start_final(false)
		return
	if t >= duration and not finished:
		finished = true
		btn_skip.visible = false
		lbl_hint.visible = false
		btn_next.visible = true
		UIKit.set_text(btn_next, "Bilgisayarıma dön" if from_showcase else "Sonraki Seviye")
		_layout()
		UIKit.pop_in(btn_next, 0.0, 0.5)
		for id in nodes:
			PartBuilder.set_glow(nodes[id], 0.0)

## Blender sinematiği akışı: zaman rig'e aktarılır, oturmadan sonra komşu parçalarda enerji dalgası
func _advance_cinematic() -> void:
	director.seek(t)
	_clear_view()
	var snap_t := float(CinematicDirector.SNAP.get(director.anim, CinematicDirector.PHASE_SNAP) if director.kind == "level" else CinematicDirector.PHASE_SNAP) / CinematicDirector.FPS
	if t < snap_t:
		PartBuilder.set_glow(new_node, 0.5 + 0.5 * sin(t * 10.0))
	else:
		var k := t - snap_t
		PartBuilder.set_glow(new_node, maxf(0.0, 1.6 - k * 1.2))
		var origin := PCPartLibrary.part(part_id).assembly_position
		for id in nodes:
			if id == part_id:
				continue
			var n: Node3D = nodes[id]
			var dd := n.position.distance_to(origin)
			var wave := 1.0 - absf(k * 4.0 - dd) / 0.9
			PartBuilder.set_glow(n, clampf(wave, 0.0, 1.0) * 1.2 * clampf(1.0 - dd / 6.0, 0.0, 1.0))
	caption_box.modulate.a = clampf((t - (duration - 2.5)) / 0.6, 0.0, 1.0)
	if t >= duration and not finished:
		for id in nodes:
			PartBuilder.set_glow(nodes[id], 0.0)
		if part_id == PCPartLibrary.COUNT:
			finished = true
			_end_director()
			start_final(false)
			return
		finished = true
		btn_skip.visible = false
		lbl_hint.visible = false
		btn_next.visible = true
		UIKit.set_text(btn_next, "BİLGİSAYARIMA DÖN" if from_showcase else "SONRAKİ SEVİYE")
		_layout()
		UIKit.pop_in(btn_next, 0.0, 0.5)

## Görüş açıcı: sinematik kameradan hedef parçaya giden doğruyu kesen (ya da kamerayı içine alan) parçalar
## o kare gizlenir — yakın çekim kamera başka parçaların içinde kalmaz.
var _aabbs := {}
func _part_aabb(id: int) -> AABB:
	if not _aabbs.has(id):
		var p := PCPartLibrary.part(id)
		_aabbs[id] = AABB(p.assembly_position - p.assembly_scale / 2.0, p.assembly_scale)
	return _aabbs[id]

func _clear_view() -> void:
	if director == null or director.cam == null or new_node == null:
		return
	var from := director.cam.global_position
	var to := new_node.global_position
	for id in nodes:
		if id == part_id:
			continue
		var n: Node3D = nodes[id]
		var b := _part_aabb(int(id)).grow(0.05)
		var block := b.has_point(from) or b.intersects_segment(from, to.lerp(from, 0.08)) != null
		if n.visible == block:
			n.visible = not block

## Büyük final: 100. parçanın montajı bittiğinde ya da test butonundan
func start_final(skip_assembly: bool) -> void:
	if final_seq != null:
		return
	if skip_assembly and not finished:
		advance(duration - t + 0.001)
		if final_seq != null:
			return
	finished = true
	_end_director()
	_unbatch()
	btn_next.visible = false
	final_seq = FINAL_SCRIPT.new()
	add_child(final_seq)
	final_seq.begin(self)

## Final sonu butonları: "showcase" → Bilgisayarım, "menu" → ana menü
func end_final(kind: String) -> void:
	if kind == "menu":
		if final_seq != null:
			final_seq.cleanup()
		main_menu.emit()
		return
	setup("showcase", real_parts if not real_parts.is_empty() else unlocked)

func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"target": (a["target"] as Vector3).lerp(b["target"], k), "dist": lerpf(a["dist"], b["dist"], k),
		"yaw": lerp_angle(a["yaw"], b["yaw"], k), "pitch": lerpf(a["pitch"], b["pitch"], k)}

func _apply_cam(c: Dictionary) -> void:
	cam_target = c["target"]
	dist = c["dist"]
	yaw = c["yaw"]
	pitch = c["pitch"]
	_update_cam()

func _update_cam() -> void:
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	cam.position = cam_target + dir * dist
	cam.look_at(cam_target, Vector3.UP)
	# alan derinliği hedefe odaklı (yakın çekimde belirgin bokeh)
	if VisualFX.quality >= 2:
		if not (cam.attributes is CameraAttributesPractical):
			VisualFX.dof(cam, dist, 2, 0.06)
		var a: CameraAttributesPractical = cam.attributes
		a.dof_blur_far_distance = dist * 1.25
		a.dof_blur_far_transition = dist * 1.4
		a.dof_blur_near_enabled = dist < 3.0
		a.dof_blur_near_distance = dist * 0.45
		a.dof_blur_amount = 0.06 if mode == "assembly" else 0.03

func _animate_parts(dt: float) -> void:
	for id in nodes:
		var n: Node3D = nodes[id]
		if n.has_meta("spinner"):
			var sp: Node3D = n.get_meta("spinner")
			var ax: Vector3 = sp.get_meta("spin_axis")
			sp.rotate(ax.normalized(), dt * (9.0 * fan_speed if id != 100 else 1.2))

# ---------------------------------------------------------------------------
# Giriş: basılı tut = 2x, vitrinde döndür / yakınlaştır
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_LEFT:
			holding = mb.pressed
			_drag = mb.position if mb.pressed else null
			_idle = 0.0
		elif mb.pressed and mode == "showcase" and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			dist = clampf(dist * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.5, 30.0)
	elif ev is InputEventScreenTouch:
		var st: InputEventScreenTouch = ev
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		holding = not _touches.is_empty()
		_pinch0 = _pinch_len()
		_idle = 0.0
	elif ev is InputEventScreenDrag and mode == "showcase":
		var sd: InputEventScreenDrag = ev
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var l := _pinch_len()
			if _pinch0 > 0.0 and l > 0.0:
				dist = clampf(dist * _pinch0 / l, 1.5, 30.0)
			_pinch0 = l
		else:
			_orbit(sd.relative)
		_idle = 0.0
	elif ev is InputEventMouseMotion and _drag != null and mode == "showcase" and _touches.is_empty():
		_orbit((ev as InputEventMouseMotion).relative)
		_idle = 0.0
	elif ev is InputEventMagnifyGesture and mode == "showcase":
		dist = clampf(dist / (ev as InputEventMagnifyGesture).factor, 1.5, 30.0)

func _pinch_len() -> float:
	if _touches.size() < 2:
		return 0.0
	var v: Array = _touches.values()
	return (v[0] as Vector2).distance_to(v[1])

func _orbit(rel: Vector2) -> void:
	yaw -= rel.x * 0.008
	pitch = clampf(pitch + rel.y * 0.006, deg_to_rad(-5.0), deg_to_rad(80.0))
