## Görsel kalite katmanı (Mobile renderer uyumlu): son işlem, alan derinliği, yansıma probu, ortam zerreleri.
## Hepsi grafik ayarına bağlıdır: Düşük'te kapalı, Orta'da hafif, Yüksek'te tam.
class_name VisualFX
extends RefCounted

static var quality := 2          # main._apply_gfx günceller (0 düşük, 1 orta, 2 yüksek)
static var _post_shader: Shader
static var _mote_tex: Texture2D

## Faz başına renk derecelendirmesi: [lift, gamma, gain, doygunluk, kontrast, sıcaklık]
const GRADES := [
	[Vector3(0.01, 0.015, 0.02), Vector3(1.0, 1.0, 1.0), Vector3(1.02, 1.0, 0.98), 1.08, 1.06, 0.15],   # anakart
	[Vector3(0.02, 0.01, 0.0), Vector3(1.0, 0.98, 0.96), Vector3(1.05, 1.0, 0.95), 1.06, 1.08, 0.4],     # PSU — sıcak
	[Vector3(0.0, 0.01, 0.03), Vector3(0.98, 1.0, 1.02), Vector3(0.98, 1.0, 1.05), 1.1, 1.08, -0.3],     # CPU — soğuk
	[Vector3(0.01, 0.0, 0.03), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.98, 1.04), 1.12, 1.05, -0.1],      # RAM
	[Vector3(0.0, 0.015, 0.02), Vector3(1.0, 1.0, 1.0), Vector3(0.98, 1.02, 1.02), 1.05, 1.1, -0.2],     # NVMe
	[Vector3(0.02, 0.0, 0.02), Vector3(1.0, 0.98, 1.0), Vector3(1.04, 0.98, 1.02), 1.14, 1.1, 0.1],      # GPU
	[Vector3(0.0, 0.01, 0.03), Vector3(1.0, 1.0, 1.02), Vector3(0.96, 1.0, 1.06), 1.04, 1.04, -0.5],     # soğutma
	[Vector3(0.015, 0.01, 0.0), Vector3(1.0, 1.0, 0.98), Vector3(1.04, 1.02, 0.96), 1.08, 1.08, 0.3],    # I/O
	[Vector3(0.01, 0.0, 0.02), Vector3(1.0, 1.0, 1.0), Vector3(1.03, 1.0, 1.03), 1.16, 1.12, 0.0],       # kasa
	[Vector3(0.02, 0.015, 0.03), Vector3(1.0, 1.0, 1.0), Vector3(1.05, 1.03, 1.05), 1.12, 1.1, 0.2],     # çekirdek
]

## Tam ekran son işlem dikdörtgeni (3D'nin üstünde, arayüzün altında bir CanvasLayer'a eklenir)
static func post_rect() -> ColorRect:
	if _post_shader == null:
		_post_shader = load("res://shaders/post_grade.gdshader")
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _post_shader
	r.material = m
	return r

static func apply_grade(r: ColorRect, phase: int, quality: int) -> void:
	if r == null:
		return
	r.visible = quality >= 1
	var m: ShaderMaterial = r.material
	var g: Array = GRADES[clampi(phase, 0, GRADES.size() - 1)]
	m.set_shader_parameter("lift", g[0])
	m.set_shader_parameter("gamma", g[1])
	m.set_shader_parameter("gain", g[2])
	m.set_shader_parameter("saturation", g[3])
	m.set_shader_parameter("contrast", g[4])
	m.set_shader_parameter("warmth", g[5])
	# film greni ve kromatik sapma oyun sırasında kapalı: ince ayrıntıyı titretip göz yoruyordu
	m.set_shader_parameter("grain", 0.0)
	m.set_shader_parameter("chroma", 0.0)
	m.set_shader_parameter("vignette", 0.18)

## Alan derinliği (montaj yakın çekimleri / sinematik kameralar)
static func dof(cam: Camera3D, focus_dist: float, quality: int, amount := 0.08) -> void:
	if cam == null:
		return
	if quality < 2:
		cam.attributes = null
		return
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = maxf(0.5, focus_dist * 1.25)
	a.dof_blur_far_transition = maxf(1.0, focus_dist * 1.5)
	a.dof_blur_near_enabled = focus_dist < 3.0
	a.dof_blur_near_distance = maxf(0.05, focus_dist * 0.45)
	a.dof_blur_near_transition = maxf(0.05, focus_dist * 0.3)
	a.dof_blur_amount = amount
	cam.attributes = a

## Sahneye yansıma probu (metallerde gerçek yansıma). Bir kez güncellenir.
static func probe(parent: Node3D, box: AABB, quality: int) -> ReflectionProbe:
	if quality < 1:
		return null
	var p := ReflectionProbe.new()
	p.size = box.size + Vector3(6, 6, 6)
	p.position = box.get_center()
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.intensity = 0.7
	p.box_projection = true
	p.enable_shadows = false
	p.max_distance = 60.0
	p.interior = false
	parent.add_child(p)
	return p

## Havada yavaşça süzülen ışık zerreleri (toz / enerji parçacıkları)
static func motes(parent: Node3D, box: AABB, col: Color, quality: int) -> GPUParticles3D:
	if quality < 1:
		return null
	if _mote_tex == null:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = gr
		gt.width = 32
		gt.height = 32
		_mote_tex = gt
	var p := GPUParticles3D.new()
	p.amount = 160 if quality >= 2 else 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(-box.size / 2.0 - Vector3(6, 4, 6), box.size + Vector3(12, 10, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box.size / 2.0 + Vector3(4, 2.5, 4)
	pm.direction = Vector3(0.2, 1, 0.1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.04
	pm.initial_velocity_max = 0.16
	pm.gravity = Vector3(0, 0.015, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.2, 1))
	fade.add_point(Vector2(0.8, 1))
	fade.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.alpha_curve = ct
	pm.color = Color(col, 0.55)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _mote_tex
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = box.get_center()
	parent.add_child(p)
	return p
