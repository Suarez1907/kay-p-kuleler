## 100. parçadan sonra ~30 sn'lik büyük final: bilgisayarın açılışı. AssemblyScene'in dünyasını ve kamerasını kullanır.
##   A 0–5     kamera güç tuşuna odaklanır; Robo kasanın tepesinde belirir, tuşa zıplar; tuş göçer, LED yanar
##   B 5–12    kamera cam yan panele süzülür; fanlar 0 devirden hızlanır; enerji dalgası Faz 1 → Faz 10
##   C 12–22   monitörde SubViewport ile canlı BIOS/POST ekranı; kamera ekrana yaklaşır; satır satır doğrulama
##   D 22–30   işletim sistemi logosu, masaüstü, "SİSTEM ÇEVRİMİÇİ — TEBRİKLER", el sallayan Robo; butonlar
## Kendi saatiyle çalışır: basılı tutmak 2x, "Geç" sona atlar.
extends Node

const DURATION := 30.0
const POWER_ID := 90
const SCREEN_ID := 94

var asm: Control
var t := 0.0
var done := false
var robot: Node3D
var screen_vp: SubViewport
var screen_quad: MeshInstance3D
var bios_lines: VBoxContainer
var desk_root: Control
var os_logo: Control
var mini_robot: Control
var _beeped := {}
var _lines_shown := 0
var _power_pressed := false
var _btns: HBoxContainer
var _press_y := 0.0
var _screen_mat: Material
var _glb_screen_node: Node3D = null
var _glb_screen_on := false

const PHASE_SHORT := ["Anakart", "PSU", "CPU", "RAM", "NVMe", "GPU", "Soğutma", "I/O", "Kasa", "Çekirdek"]

func begin(owner_scene: Control) -> void:
	asm = owner_scene
	asm.fan_speed = 0.0
	Sfx.call_ah("fan", [0.0])
	_build_robot()
	_build_screen()
	_build_buttons()
	var pw: Node3D = asm.nodes.get(POWER_ID)
	if pw != null:
		_press_y = pw.position.y
	asm.lbl_title.text = "SİSTEM AÇILIŞI"
	asm.caption_box.modulate.a = 0.0
	asm.btn_skip.visible = true
	asm.lbl_hint.visible = true
	advance(0.0)

func _build_robot() -> void:
	robot = AssetLoader.robot_model()
	if robot == null:
		robot = Node3D.new()
		var k := MeshKit.new()
		k.box(Vector3(0, 0.2, 0), Vector3(0.34, 0.3, 0.3), MeshKit.col("#ff9a3c", MeshKit.DIELECTRIC))
		k.box(Vector3(0, 0.2, 0.152), Vector3(0.26, 0.15, 0.01), MeshKit.col("#1e1b27", MeshKit.DIELECTRIC))
		k.box(Vector3(-0.06, 0.21, 0.16), Vector3(0.05, 0.05, 0.01), MeshKit.col("#6ff6ff", MeshKit.GLOW))
		k.box(Vector3(0.06, 0.21, 0.16), Vector3(0.05, 0.05, 0.01), MeshKit.col("#6ff6ff", MeshKit.GLOW))
		k.box(Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.26), MeshKit.col("#2c2836", MeshKit.DIELECTRIC))
		k.cyl(Vector3(0, 0.42, 0), 0.012, 0.12, MeshKit.col("#2c2836", MeshKit.DIELECTRIC), 8)
		k.cyl(Vector3(0, 0.49, 0), 0.035, 0.05, MeshKit.col("#6ff6ff", MeshKit.GLOW), 10)
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.material_override = ComponentFactory.material()
		robot.add_child(mi)
	robot.visible = false
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 0.6
	holder.add_child(robot)
	asm.parts_root.add_child(holder)
	robot = holder

func _build_screen() -> void:
	screen_vp = SubViewport.new()
	screen_vp.size = Vector2i(960, 584)
	screen_vp.transparent_bg = false
	screen_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	asm.add_child(screen_vp)
	var bg := ColorRect.new()
	bg.color = Color("#020814")
	bg.size = Vector2(960, 584)
	screen_vp.add_child(bg)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Droid Sans Mono", "Courier New", "monospace"])
	bios_lines = VBoxContainer.new()
	bios_lines.position = Vector2(40, 30)
	bios_lines.add_theme_constant_override("separation", 4)
	screen_vp.add_child(bios_lines)
	bios_lines.set_meta("font", mono)
	# işletim sistemi logosu
	os_logo = Control.new()
	os_logo.size = Vector2(960, 584)
	os_logo.visible = false
	screen_vp.add_child(os_logo)
	var lg := Label.new()
	lg.text = "◆ KULE OS"
	lg.add_theme_font_override("font", UIKit.font_black)
	lg.add_theme_font_size_override("font_size", 72)
	lg.add_theme_color_override("font_color", Color("#7fd6ff"))
	lg.position = Vector2(300, 220)
	os_logo.add_child(lg)
	# masaüstü
	desk_root = Control.new()
	desk_root.size = Vector2(960, 584)
	desk_root.visible = false
	screen_vp.add_child(desk_root)
	var wall := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("#2b5876"))
	g.set_color(1, Color("#4e4376"))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	gt.width = 64
	gt.height = 64
	wall.texture = gt
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.size = Vector2(960, 584)
	desk_root.add_child(wall)
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.06, 0.1, 0.85)
	bar.position = Vector2(0, 540)
	bar.size = Vector2(960, 44)
	desk_root.add_child(bar)
	for i in 5:
		var ic := ColorRect.new()
		ic.color = [Color("#ff9a3c"), Color("#7fd6ff"), Color("#3cf08a"), Color("#c58bff"), Color("#ffd36e")][i]
		ic.position = Vector2(20 + i * 46, 548)
		ic.size = Vector2(30, 28)
		desk_root.add_child(ic)
	var title := Label.new()
	title.text = "KAYIP KULELER"
	title.add_theme_font_override("font", UIKit.font_black)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(60, 60)
	desk_root.add_child(title)
	var msg := Label.new()
	msg.text = "SİSTEM ÇEVRİMİÇİ — TEBRİKLER"
	msg.add_theme_font_override("font", UIKit.font_black)
	msg.add_theme_font_size_override("font_size", 38)
	msg.add_theme_color_override("font_color", Color("#3cf08a"))
	msg.position = Vector2(60, 150)
	desk_root.add_child(msg)
	var sub := Label.new()
	sub.text = "100/100 parça takıldı · Bütün devreler kapandı · Robo seni selamlıyor!"
	sub.add_theme_font_override("font", UIKit.font_bold)
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	sub.position = Vector2(60, 210)
	desk_root.add_child(sub)
	mini_robot = WavingRobot.new()
	mini_robot.position = Vector2(640, 260)
	mini_robot.size = Vector2(240, 260)
	desk_root.add_child(mini_robot)
	# ekran yüzeyi: monitörün IPS katmanının önüne SubViewport dokusu
	var sp := PCPartLibrary.part(SCREEN_ID)
	screen_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(sp.assembly_scale.x * 0.98, sp.assembly_scale.y * 0.98)
	screen_quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = screen_vp.get_texture()
	screen_quad.material_override = m
	screen_quad.position = sp.assembly_position + Vector3(0, 0, sp.assembly_scale.z / 2.0 + 0.004)
	screen_quad.visible = false
	asm.parts_root.add_child(screen_quad)
	# monitör modelinde "MonitorScreen" yuvası varsa BIOS dokusu doğrudan oraya bağlanır
	_screen_mat = m
	for id in [SCREEN_ID, 93]:
		if asm.nodes.has(id):
			var found := AssetLoader.unique_surfaces(asm.nodes[id], "MonitorScreen")
			if not found.is_empty():
				_glb_screen_node = asm.nodes[id]
				break

func _build_buttons() -> void:
	_btns = HBoxContainer.new()
	_btns.add_theme_constant_override("separation", 16)
	_btns.add_child(UIKit.button("Atölyede İncele (Bilgisayarım)", Color("#ffb84d"), func(): asm.end_final("showcase"), 22, "sparkle", UIKit.INK, 66))
	_btns.add_child(UIKit.button("Ana Menü", UIKit.CORAL, func(): asm.end_final("menu"), 22, "home", Color.WHITE, 66))
	_btns.visible = false
	asm.add_child(_btns)

func _line(text: String, col := Color("#c8d6e5"), size := 24) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bios_lines.get_meta("font"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	bios_lines.add_child(l)
	return l

func skip() -> void:
	advance(DURATION - t + 0.001)

static func _e(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _cam(target: Vector3, dist: float, yaw_deg: float, pitch_deg: float) -> Dictionary:
	return {"target": target, "dist": dist, "yaw": deg_to_rad(yaw_deg), "pitch": deg_to_rad(pitch_deg)}

func advance(dt: float) -> void:
	var prev := t
	t = minf(t + dt, DURATION)
	var pw: Node3D = asm.nodes.get(POWER_ID)
	var pwp: Vector3 = PCPartLibrary.part(POWER_ID).assembly_position
	var sp: Vector3 = PCPartLibrary.part(SCREEN_ID).assembly_position
	var cam_btn := _cam(pwp + Vector3(-0.2, 0.0, 0.0), 3.0, 40.0, 34.0)
	var cam_side := _cam(Vector3(-0.7, 1.6, 0.0), 7.4, 8.0, 14.0)
	var cam_scr := _cam(sp, 2.45, 0.0, 0.0)
	var cam_end := _cam(Vector3(1.8, 1.9, 0.0), 9.0, 22.0, 12.0)
	var start := {"target": asm.cam_target, "dist": asm.dist, "yaw": asm.yaw, "pitch": asm.pitch}
	# --- kamera ---
	if t < 2.0:
		asm._apply_cam(asm._blend(asm._overview if not asm._overview.is_empty() else cam_side, cam_btn, _e(t / 2.0)))
	elif t < 5.0:
		asm._apply_cam(cam_btn)
	elif t < 8.0:
		asm._apply_cam(asm._blend(cam_btn, cam_side, _e((t - 5.0) / 3.0)))
	elif t < 12.0:
		asm._apply_cam(cam_side)
	elif t < 14.0:
		asm._apply_cam(asm._blend(cam_side, cam_scr, _e((t - 12.0) / 2.0)))
	elif t < 24.0:
		asm._apply_cam(cam_scr)
	else:
		asm._apply_cam(asm._blend(cam_scr, cam_end, _e((t - 24.0) / 3.5)))
	# --- A: Robo güç tuşuna zıplar ---
	var top := pwp + Vector3(0, PCPartLibrary.part(POWER_ID).assembly_scale.y / 2.0, 0)
	var from := top + Vector3(-0.9, 0.0, -0.2)
	robot.visible = t >= 0.8
	if t < 0.8:
		robot.scale = Vector3.ONE * 0.01
	elif t < 1.4:
		robot.scale = Vector3.ONE * _e((t - 0.8) / 0.6)
		robot.position = from
	elif t < 2.4:
		robot.scale = Vector3.ONE
		robot.position = from + Vector3(0, absf(sin((t - 1.4) * TAU)) * 0.08, 0)
	elif t < 3.0:
		var k := (t - 2.4) / 0.6
		robot.position = from.lerp(top, k) + Vector3(0, sin(PI * k) * 0.55, 0)
		robot.rotation.y = lerpf(0.0, PI / 2, k)
	else:
		var press := clampf(1.0 - (t - 3.0) / 0.35, 0.0, 1.0)
		robot.position = top + Vector3(0, -0.03 * press + (0.15 * absf(sin((t - 3.2) * 6.0)) if t > 3.6 and t < 5.0 else 0.0), 0)
		if t >= 22.0:
			robot.position = top + Vector3(0, absf(sin(t * 5.0)) * 0.25, 0)
			robot.rotation.y = t * 2.0
	if pw != null:
		var depress := 0.03 if t >= 3.0 and t < 3.35 else 0.0
		pw.position.y = _press_y - depress
		PartBuilder.set_glow(pw, 1.0 if t >= 3.0 else 0.0)
	if t >= 3.0 and not _power_pressed:
		_power_pressed = true
		Sfx.call_ah("power_press")
	# --- B: fanlar ve enerji dalgası ---
	var fan := _e((t - 5.0) / 4.5)
	asm.fan_speed = fan
	Sfx.call_ah("fan", [fan * (1.0 - _e((t - 26.0) / 3.0) * 0.6)])
	for id in asm.nodes:
		if id == POWER_ID:
			continue
		var phase := (int(id) - 1) / 10
		var center := 5.5 + phase * 0.6
		var g := clampf(1.0 - absf(t - center) / 0.45, 0.0, 1.0)
		if t >= 20.4 and t < 21.2:
			g = maxf(g, 1.0 - absf(t - 20.8) / 0.4)
		PartBuilder.set_glow(asm.nodes[id], g * 1.3)
	# --- C: BIOS / POST ---
	if _glb_screen_node != null:
		screen_quad.visible = false
		if (t >= 12.0) != _glb_screen_on:
			_glb_screen_on = t >= 12.0
			if _glb_screen_on:
				AssetLoader.bind_surfaces(_glb_screen_node, "MonitorScreen", _screen_mat)
			else:
				AssetLoader.unique_surfaces(_glb_screen_node, "MonitorScreen")
	else:
		screen_quad.visible = t >= 12.0
	var lines := [[12.4, "BIOS v4.8 — ROBOTIC CORE SYSTEMS", Color("#7fd6ff"), 30], [12.9, "Copyright (C) Kayıp Kuleler Labs · Robo POST rev.100", Color("#8899aa"), 18],
		[13.3, "CPU: ROBO-CORE 100 @ 4.80 GHz    MEMORY: 64 GB DDR5 ...... OK", Color("#c8d6e5"), 22], [13.9, "CHECKING HARDWARE MODULES...", Color("#ffd36e"), 24]]
	for i in 10:
		lines.append([14.4 + i * 0.55, "  [%02d] %s %s [ OK ]" % [i + 1, PHASE_SHORT[i], ".".repeat(22 - PHASE_SHORT[i].length())], Color("#3cf08a"), 22])
	lines.append([20.4, "TOTAL PARTS VERIFIED: 100 / 100 — ALL SYSTEMS NOMINAL.", Color("#ffffff"), 24])
	while _lines_shown < lines.size() and t >= lines[_lines_shown][0]:
		var row: Array = lines[_lines_shown]
		_line(row[1], row[2], row[3])
		_lines_shown += 1
		if _lines_shown == 1 or _lines_shown == lines.size():
			Sfx.call_ah("post_beep")
		elif _lines_shown > 4:
			Sfx.call_ah("ui_thock")
	# --- D: masaüstü ---
	bios_lines.visible = t < 22.0
	os_logo.visible = t >= 22.0 and t < 24.0
	if os_logo.visible:
		os_logo.modulate.a = _e((t - 22.0) / 0.5)
	desk_root.visible = t >= 24.0
	if t >= 24.0 and prev < 24.0:
		Sfx.call_ah("desktop_chord")
	asm.caption_box.modulate.a = _e((t - 25.0) / 0.8)
	if t >= 25.0:
		asm.lbl_caption.text = "SİSTEM ÇEVRİMİÇİ — TEBRİKLER!"
		asm.lbl_sub.text = "100/100 parça · 10/10 faz · Kayıp kuleler yeniden çalışıyor"
	if t >= 26.5 and not _btns.visible:
		_btns.visible = true
		_layout()
		UIKit.pop_in(_btns, 0.0, 0.6)
	if t >= DURATION and not done:
		done = true
		asm.btn_skip.visible = false
		asm.lbl_hint.visible = false
		_btns.visible = true
		_layout()

func _layout() -> void:
	var vs: Vector2 = asm.size
	_btns.reset_size()
	_btns.position = Vector2((vs.x - _btns.size.x) / 2.0, vs.y - _btns.size.y - 22.0)

func _process(dt: float) -> void:
	if not done:
		advance(dt * (2.0 if asm.holding else 1.0))
	if mini_robot != null:
		mini_robot.queue_redraw()

func cleanup() -> void:
	Sfx.call_ah("fan", [0.0])
	if is_instance_valid(screen_quad):
		screen_quad.queue_free()
	if is_instance_valid(robot):
		robot.queue_free()
	if is_instance_valid(_btns):
		_btns.queue_free()
	if is_instance_valid(screen_vp):
		screen_vp.queue_free()

## Masaüstündeki el sallayan, zıplayan Robo (2B çizim)
class WavingRobot extends Control:
	func _draw() -> void:
		var tm := Time.get_ticks_msec() / 1000.0
		var hop := absf(sin(tm * 4.0)) * 18.0
		var o := Vector2(60, 60 - hop)
		draw_rect(Rect2(o + Vector2(20, 40), Vector2(120, 100)), Color("#ff9a3c"))
		draw_rect(Rect2(o + Vector2(35, 60), Vector2(90, 45)), Color("#1e1b27"))
		draw_circle(o + Vector2(62, 82), 9, Color("#6ff6ff"))
		draw_circle(o + Vector2(98, 82), 9, Color("#6ff6ff"))
		draw_line(o + Vector2(80, 40), o + Vector2(80, 14), Color("#2c2836"), 5)
		draw_circle(o + Vector2(80, 12), 8, Color("#6ff6ff"))
		draw_rect(Rect2(o + Vector2(30, 140), Vector2(28, 26)), Color("#2c2836"))
		draw_rect(Rect2(o + Vector2(102, 140), Vector2(28, 26)), Color("#2c2836"))
		var a := -0.6 + sin(tm * 9.0) * 0.6
		var sh := o + Vector2(140, 70)
		draw_line(sh, sh + Vector2(cos(a - 0.6), sin(a - 0.6)) * 55.0, Color("#2c2836"), 10)
		draw_line(o + Vector2(20, 75), o + Vector2(-5, 115), Color("#2c2836"), 10)
