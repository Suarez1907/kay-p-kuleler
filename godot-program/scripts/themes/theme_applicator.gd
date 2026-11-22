## Bölüm temasını sahneye uygular.
## Gökyüzü, yağış, şimşek ve ortam sesi Weather'da kalır; tema onların üstüne renk ve ışık bindirir.
## Ton eşleme doğrusal kalır (gökyüzü shader'ı bu moda göre ayarlı).
class_name ThemeApplicator
extends RefCounted

const BLOCK_SHADER := preload("res://shaders/chapter_block.gdshader")

var theme: ChapterTheme
var block_mat: ShaderMaterial
var stair_mat: ShaderMaterial
var crystal_mat: ShaderMaterial
var props: Node3D
var bounds := AABB()
var glow := 0.0
var _game
var _ui_tw: Tween


func bind(game) -> void:
	_game = game
	block_mat = _new_mat(0)
	stair_mat = _new_mat(1)
	crystal_mat = _new_mat(2)


func prepare(next: ChapterTheme) -> void:
	theme = next
	_push(block_mat, 0)
	_push(stair_mat, 1)
	_push(crystal_mat, 2)
	var weather: Weather = _game.weather
	if weather != null:
		weather.blend_theme(theme.bg_top_color, theme.bg_bottom_color, theme.light_color, theme.light_energy, theme.ambient_color, theme.ambient_energy)
	var sun: DirectionalLight3D = _game.sun
	if sun != null:
		sun.rotation_degrees = theme.light_rotation_deg
	var env: Environment = _game.env
	if env != null:
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = clampf(lerpf(1.0, 0.94 + theme.light_energy * 0.08, 0.65), 0.92, 1.08)
		env.fog_light_color = theme.bg_bottom_color
	var fill: DirectionalLight3D = _game.fill
	if fill != null:
		fill.light_color = theme.ambient_color.lerp(Color.WHITE, 0.4)
		fill.light_energy = clampf(theme.ambient_energy * 0.45, 0.12, 0.38)
	_apply_panel()


func refresh_props() -> void:
	var root: Node3D = _game.level_root
	if root == null or theme == null:
		return
	if props != null and is_instance_valid(props):
		props.queue_free()
		props = null
	props = ThemePropGenerator.spawn(root, theme, bounds)


func paint_robot() -> void:
	if theme == null or not _game.objs.has("player"):
		return
	var pl: Node3D = _game.objs["player"]
	if pl.has_meta("eye_mat"):
		var eye: StandardMaterial3D = pl.get_meta("eye_mat")
		eye.albedo_color = theme.robot_led_color
		eye.emission = theme.robot_led_color
	_game._apply_led_color()


func pulse_step() -> void:
	glow = 1.0
	if block_mat:
		block_mat.set_shader_parameter("stepped_glow", glow)
	if stair_mat:
		stair_mat.set_shader_parameter("stepped_glow", glow)


func tick(dt: float) -> void:
	if glow > 0.0:
		glow = move_toward(glow, 0.0, dt * 1.5)
		if block_mat:
			block_mat.set_shader_parameter("stepped_glow", glow)
		if stair_mat:
			stair_mat.set_shader_parameter("stepped_glow", glow)
	if props != null and is_instance_valid(props):
		_animate(props, dt)


func _new_mat(role: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BLOCK_SHADER
	m.set_shader_parameter("role", role)
	return m


func _push(mat: ShaderMaterial, role: int) -> void:
	if mat == null or theme == null:
		return
	var base := theme.block_base_color
	var top := theme.block_top_color
	if role == 1:
		base = theme.stair_color.darkened(0.12)
		top = theme.stair_color
	elif role == 2:
		base = theme.accent_color
		top = theme.accent_color
	mat.set_shader_parameter("visual_style", theme.visual_style)
	mat.set_shader_parameter("role", role)
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("accent_color", theme.accent_color)
	mat.set_shader_parameter("roughness_amt", theme.roughness)
	mat.set_shader_parameter("metallic_amt", theme.metallic)
	mat.set_shader_parameter("emission_strength", theme.emission_strength)
	mat.set_shader_parameter("stepped_glow", glow)


## Arayüz paneli Blueprint v2 paletinde sabit kalır (tema yalnızca 3D sahneyi boyar).
func _apply_panel() -> void:
	var panel: PanelContainer = _game.panel
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = BP.SURFACE_PANEL
		sb.border_color = BP.BORDER_STEEL
	var sep: ColorRect = _game.panel_sep
	if sep:
		sep.color = Color(BP.BORDER_STEEL, 0.55)


func _animate(n: Node, dt: float) -> void:
	for c in n.get_children():
		if c is Node3D:
			var body := c as Node3D
			if body.has_meta("spin"):
				body.rotate_y(float(body.get_meta("spin")) * dt)
			if body.has_meta("bob"):
				var phase := float(body.get_meta("phase"))
				body.position.y = float(body.get_meta("base_y")) + sin(_game.time * 1.3 + phase) * float(body.get_meta("bob"))
		if c.get_child_count() > 0:
			_animate(c, dt)
