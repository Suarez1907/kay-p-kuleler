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
	_build_world()
	_build_ui()

# ---------------------------------------------------------------------------
# Kurulum
func setup(m: String, unlocked_ids: Array, pid := 0) -> void:
	if final_seq != null:
		final_seq.cleanup()
		final_seq.queue_free()
		final_seq = null
	fan_speed = 1.0
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
		caption_box.modulate.a = 0.0
		_apply_cam(_overview)
		advance(0.0)
	else:
		var b := PCPartLibrary.bounds(unlocked) if not unlocked.is_empty() else AABB(Vector3(-1, 0, -1), Vector3(2, 1, 2))
		var f := _frame(b, 1.05)
		cam_target = f["target"]
		dist = f["dist"]
		lbl_title.text = "BİLGİSAYARIM  %d/%d" % [unlocked.size(), PCPartLibrary.COUNT]
		lbl_caption.text = "Parçaları incelemek için sürükle, yakınlaştırmak için iki parmakla sıkıştır"
		lbl_sub.text = _phase_summary()
		caption_box.modulate.a = 1.0
		_update_cam()
	btn_skip.visible = mode == "assembly"
	btn_next.visible = false
	btn_back.visible = mode == "showcase"
	btn_test.visible = mode == "showcase" and unlocked.size() < PCPartLibrary.COUNT
	lbl_hint.visible = mode == "assembly"
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
	parts_root.add_child(n)
	nodes[id] = n
	return n

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
	we.environment = env
	world.add_child(we)
	# stüdyo ışıkları: sıcak ana ışık, soğuk kenar ışığı, yumuşak dolgu
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe9d2")
	key.light_energy = 2.1
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	world.add_child(key)
	key.look_at_from_position(Vector3(5, 9, 6), Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#7fb4ff")
	rim.light_energy = 1.1
	world.add_child(rim)
	rim.look_at_from_position(Vector3(-6, 4, -7), Vector3.ZERO, Vector3.UP)
	var spot := SpotLight3D.new()
	spot.light_color = Color("#ffd9a8")
	spot.light_energy = 3.0
	spot.spot_range = 16.0
	spot.spot_angle = 34.0
	spot.position = Vector3(0.5, 8.5, 2.5)
	world.add_child(spot)
	spot.look_at(Vector3(0.6, 0.8, 0), Vector3.UP)
	# masa yüzeyi ve arka plan perdesi
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

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 14
	top.offset_right = -18
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	btn_back = UIKit.round_button("back", func(): closed.emit(), 56)
	top.add_child(btn_back)
	lbl_title = UIKit.label("", 26, Color.WHITE, UIKit.font_black)
	lbl_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	lbl_title.add_theme_constant_override("outline_size", 6)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lbl_title)
	btn_test = UIKit.button("Montajı Test Et (+1 Parça)", Color("#ffb84d"), func(): test_requested.emit(), 18, "sparkle", UIKit.INK, 54)
	top.add_child(btn_test)
	btn_skip = UIKit.button("Geç", Color(1, 1, 1, 0.9), _skip, 20, "step", UIKit.INK, 54)
	top.add_child(btn_skip)
	# alt yazı kartı
	var cb := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.72)
	sb.border_color = Color(1.0, 0.72, 0.3, 0.55)
	sb.border_width_top = 2
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	cb.add_theme_stylebox_override("panel", sb)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	lbl_caption = UIKit.label("", 24, Color.WHITE, UIKit.font_black)
	lbl_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub = UIKit.label("", 16, Color("#ffd9a8"), UIKit.font_bold)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(lbl_caption)
	cv.add_child(lbl_sub)
	cb.add_child(cv)
	add_child(cb)
	caption_box = cb
	btn_next = UIKit.button("Sonraki Seviye", UIKit.GREEN, func(): next_level.emit(), 26, "play", Color.WHITE, 70)
	add_child(btn_next)
	lbl_hint = UIKit.label("Basılı tut: 2x hız", 15, Color(1, 1, 1, 0.65), UIKit.font_bold)
	add_child(lbl_hint)
	resized.connect(_layout)

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

# ---------------------------------------------------------------------------
# Zaman çizelgesi
func _process(dt: float) -> void:
	if final_seq != null:
		pass   # final kendi saatiyle ilerler
	elif mode == "assembly" and not finished:
		advance(dt * (2.0 if holding else 1.0))
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
		advance(DURATION - t + 0.001)

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## Zamanı ilerletir (testler de doğrudan çağırır). Bütün durum t'den hesaplanır.
func advance(dt: float) -> void:
	t = minf(t + dt, DURATION)
	if new_node == null:
		return
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
	if t >= DURATION and not finished and part_id == PCPartLibrary.COUNT:
		finished = true
		for id in nodes:
			PartBuilder.set_glow(nodes[id], 0.0)
		start_final(false)
		return
	if t >= DURATION and not finished:
		finished = true
		btn_skip.visible = false
		lbl_hint.visible = false
		btn_next.visible = true
		UIKit.set_text(btn_next, "Bilgisayarıma dön" if from_showcase else "Sonraki Seviye")
		_layout()
		UIKit.pop_in(btn_next, 0.0, 0.5)
		for id in nodes:
			PartBuilder.set_glow(nodes[id], 0.0)

## Büyük final: 100. parçanın montajı bittiğinde ya da test butonundan
func start_final(skip_assembly: bool) -> void:
	if final_seq != null:
		return
	if skip_assembly and not finished:
		advance(DURATION - t + 0.001)
		if final_seq != null:
			return
	finished = true
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
