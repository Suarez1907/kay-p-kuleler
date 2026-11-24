## Kayıp Kuleler — bölüm başına hava durumu: prosedürel gökyüzü shader'ı, 3B yağış parçacıkları,
## şimşek/yıldırım zamanlaması (gök + sahne ışığı + gök gürültüsü) ve ortam sesi.
class_name Weather
extends Node

## Bölüm sırasına göre hava (9 bölüm; fazlası başa döner)
const BY_CHAPTER := ["clear", "cumulus", "rain", "sunset", "storm", "snow", "night", "tornado", "electric",
	"sunset", "night", "cumulus", "rain", "clear", "tornado"]

const NAMES := {
	"clear": "Güneşli sabah", "cumulus": "Parçalı bulutlu", "rain": "Yağmurlu", "sunset": "Gün batımı",
	"storm": "Fırtına", "snow": "Kar yağışı", "night": "Yıldızlı gece", "tornado": "Hortum", "electric": "Yıldırım gecesi",
}

## Her ön ayar: shader parametreleri + sahne ışığı + yağış + şimşek sıklığı + ses.
## sky: [tepe, orta, ufuk, pus, dağ, zemin]; cloud: [aydınlık, gölge]; light: [güneş rengi, enerji, ortam rengi, enerji]
const PRESETS := {
	"clear": {
		"sky": ["#2a6cc4", "#6aa4de", "#dbe8f2", "#c8d9e8", "#6f88a6", "#7c9a6c"],
		"sun": [0.78, 0.13], "sun_color": "#fff2d8", "sun_size": 0.03, "sun_glow": 0.75,
		"cover": 0.3, "density": 0.9, "cloud": ["#ffffff", "#9aabc4"], "speed": 0.008, "cirrus": 0.35, "scale": 1.0,
		"light": ["#ffecd2", 0.38, "#a6b4e6", 0.36], "dark_ui": false,
	},
	"cumulus": {
		"sky": ["#336fbf", "#79acdf", "#e1ebf3", "#cfdcea", "#7890aa", "#78955f"],
		"sun": [0.22, 0.12], "sun_color": "#fff5e2", "sun_size": 0.028, "sun_glow": 0.6,
		"cover": 0.56, "density": 1.05, "cloud": ["#ffffff", "#8e9fb8"], "speed": 0.02, "cirrus": 0.15, "scale": 1.25,
		"light": ["#fff0dc", 0.36, "#a9b6e2", 0.38], "dark_ui": false, "wind_snd": 0.25,
	},
	"rain": {
		"sky": ["#566376", "#7b8696", "#a8b0ba", "#98a1ac", "#58626d", "#4c5a4c"],
		"sun": [0.7, 0.1], "sun_color": "#dfe3ea", "sun_size": 0.0, "sun_glow": 0.08,
		"cover": 0.93, "density": 1.25, "cloud": ["#c1c8d2", "#5a6371"], "speed": 0.018, "cirrus": 0.0, "scale": 0.9, "scud": 0.45,
		"rain": 0.75, "wind": 0.08, "light": ["#dfe6f0", 0.22, "#a6b0c4", 0.5], "dark_ui": false,
		"rain_snd": 0.7, "wind_snd": 0.2,
	},
	"sunset": {
		"sky": ["#33457f", "#e08e7e", "#ffd09a", "#efb08a", "#6a5576", "#4f4049"],
		"sun": [0.3, 0.55], "sun_color": "#ffb066", "sun_size": 0.045, "sun_glow": 1.1,
		"cover": 0.36, "density": 0.85, "cloud": ["#ffd0a0", "#8a6487"], "speed": 0.007, "cirrus": 0.65, "scale": 1.0,
		"light": ["#ffb47a", 0.44, "#b39ad2", 0.33], "dark_ui": false,
	},
	"storm": {
		"sky": ["#262d3b", "#3c4454", "#69707c", "#5a626e", "#363c46", "#323a33"],
		"sun": [0.6, 0.1], "sun_color": "#c8cfdc", "sun_size": 0.0, "sun_glow": 0.05,
		"cover": 0.98, "density": 1.45, "cloud": ["#8a92a1", "#2b313b"], "speed": 0.03, "cirrus": 0.0, "scale": 0.85, "scud": 0.85,
		"rain": 1.0, "wind": 0.24, "light": ["#c9d2e6", 0.17, "#8f9ab8", 0.55], "dark_ui": true,
		"flash_every": [2.5, 6.5], "ground_bolt": 0.35, "rain_snd": 1.0, "wind_snd": 0.55,
	},
	"snow": {
		"sky": ["#8b9bb0", "#b4c0cd", "#e0e6eb", "#d6dde4", "#9aa8b8", "#e9edf2"],
		"sun": [0.72, 0.16], "sun_color": "#eef2fa", "sun_size": 0.022, "sun_glow": 0.18,
		"cover": 0.84, "density": 1.0, "cloud": ["#f0f3f7", "#a2acb9"], "speed": 0.006, "cirrus": 0.0, "scale": 1.1,
		"snow": 0.85, "snow_ground": 1.0, "wind": 0.05, "light": ["#eef3ff", 0.28, "#c4cde2", 0.5], "dark_ui": false,
		"wind_snd": 0.3,
	},
	"night": {
		"sky": ["#03060f", "#0a1430", "#1c2a4a", "#18233c", "#0b1322", "#0d151e"],
		"sun": [0.8, 0.13], "sun_color": "#dfe6ff", "sun_size": 0.03, "sun_glow": 0.35, "moon": 1.0,
		"stars": 1.0, "aurora": 1.0,
		"cover": 0.2, "density": 0.8, "cloud": ["#4a5878", "#121a2c"], "speed": 0.005, "cirrus": 0.0, "scale": 1.0,
		"light": ["#9fb4ff", 0.3, "#5866a8", 0.52], "dark_ui": true,
	},
	"tornado": {
		"sky": ["#29363a", "#4c5e56", "#aab48f", "#8e987f", "#47514a", "#4d583c"],
		"sun": [0.85, 0.5], "sun_color": "#e8e6c0", "sun_size": 0.0, "sun_glow": 0.25,
		"cover": 0.95, "density": 1.5, "cloud": ["#8c988a", "#283230"], "speed": 0.024, "cirrus": 0.0, "scale": 0.9, "scud": 0.6,
		"tornado": 1.0, "tornado_x": 0.5, "rain": 0.25, "wind": 0.3,
		"light": ["#dde2c4", 0.22, "#8e9c90", 0.5], "dark_ui": true,
		"flash_every": [4.0, 9.0], "ground_bolt": 0.5, "rain_snd": 0.3, "wind_snd": 1.0,
	},
	"electric": {
		"sky": ["#0b0d1c", "#1b1e38", "#3b3656", "#2e2a47", "#14152a", "#131523"],
		"sun": [0.5, 0.1], "sun_color": "#b9b4ff", "sun_size": 0.0, "sun_glow": 0.05, "stars": 0.25,
		"cover": 0.82, "density": 1.3, "cloud": ["#5c5e85", "#181a2d"], "speed": 0.014, "cirrus": 0.0, "scale": 1.0, "scud": 0.3,
		"light": ["#b7b0ff", 0.22, "#6a62a8", 0.52], "dark_ui": true,
		"flash_every": [1.6, 4.0], "ground_bolt": 0.85, "wind_snd": 0.35,
	},
}

var kind := "clear"
var preset: Dictionary = PRESETS["clear"]
var sky: ColorRect
var mat: ShaderMaterial
var env: Environment
var sun: DirectionalLight3D
var audio: GameAudio
var root3d: Node3D
var quality := 2
var flash := 0.0
var _flash_env := []          # [[zaman, şiddet], ...] çift çakma zarfı
var _flash_t := 0.0
var _bolt_age := 9.0
var _next_flash := 999.0
var _thunder_at := -1.0
var _thunder_vol := 0.0
var _base := {}
var rain_p: CPUParticles3D
var snow_p: CPUParticles3D
var enabled := true
var sky_base: Array = []
var light_base_color := Color.WHITE
var ambient_base_color := Color.WHITE
var weather_sun := 0.38
var weather_amb := 0.4
var vp: SubViewport           # gökyüzü ayrı bir görüntü alanında çizilir: çözünürlüğü grafik ayarına bağlı
var _screen := Vector2i.ZERO
## Okunabilirlik tabanı: hiçbir hava/tema sahneyi bu enerjilerin altına karartmaz
const SUN_MIN := 0.5
const AMB_MIN := 0.5
const RES_SCALE := [0.5, 0.7, 1.0]   # Düşük / Orta / Yüksek (Yüksek = ekranın tam çözünürlüğü)

func setup(bg_layer: CanvasLayer, world: Node3D, e: Environment, s: DirectionalLight3D, a: GameAudio) -> void:
	env = e
	sun = s
	audio = a
	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	# çizim _process'te yönetilir (sky_rate): durgun havada iki karede bir, hareketli durumlarda her kare
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.size = Vector2i(64, 64)
	add_child(vp)
	sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/sky.gdshader")
	sky.material = mat
	vp.add_child(sky)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = vp.get_texture()
	bg_layer.add_child(tr)
	root3d = Node3D.new()
	world.add_child(root3d)
	rain_p = _make_rain()
	snow_p = _make_snow()
	root3d.add_child(rain_p)
	root3d.add_child(snow_p)

static func for_chapter(ch: int) -> String:
	return BY_CHAPTER[ch % BY_CHAPTER.size()]

func apply(k: String, seed: float) -> void:
	_sky_dirty = true
	kind = k
	preset = PRESETS[k]
	var P := preset
	var sk: Array = P["sky"]
	for pair in [["sky_top", 0], ["sky_mid", 1], ["sky_horizon", 2], ["haze", 3], ["mountain", 4], ["ground", 5]]:
		mat.set_shader_parameter(pair[0], Color(sk[pair[1]]))
	# güneş konumu seviyeye göre hafifçe oynar: aynı bölümde her seviye biraz farklı görünür
	var sp: Array = P["sun"]
	var jitter := (fmod(seed * 0.618, 1.0) - 0.5) * 0.08
	mat.set_shader_parameter("sun_pos", Vector2(clampf(sp[0] + jitter, 0.1, 0.9), sp[1]))
	mat.set_shader_parameter("sun_color", Color(P["sun_color"]))
	mat.set_shader_parameter("sun_size", P["sun_size"])
	mat.set_shader_parameter("sun_glow", P["sun_glow"])
	mat.set_shader_parameter("moon", P.get("moon", 0.0))
	mat.set_shader_parameter("stars", P.get("stars", 0.0))
	mat.set_shader_parameter("aurora", P.get("aurora", 0.0))
	mat.set_shader_parameter("cloud_cover", P["cover"])
	mat.set_shader_parameter("cloud_density", P["density"])
	mat.set_shader_parameter("cloud_lit", Color(P["cloud"][0]))
	mat.set_shader_parameter("cloud_shade", Color(P["cloud"][1]))
	mat.set_shader_parameter("cloud_speed", P["speed"])
	mat.set_shader_parameter("cloud_scale", P["scale"])
	mat.set_shader_parameter("cirrus", P["cirrus"])
	mat.set_shader_parameter("scud", P.get("scud", 0.0))
	mat.set_shader_parameter("rain", P.get("rain", 0.0))
	mat.set_shader_parameter("snow", P.get("snow", 0.0))
	mat.set_shader_parameter("snow_ground", P.get("snow_ground", 0.0))
	mat.set_shader_parameter("wind", P.get("wind", 0.1))
	mat.set_shader_parameter("tornado", P.get("tornado", 0.0))
	mat.set_shader_parameter("tornado_x", P.get("tornado_x", 0.3))
	mat.set_shader_parameter("seed", fmod(seed * 3.7, 50.0))
	mat.set_shader_parameter("quality", float(quality))
	# sahne ışığı
	var lt: Array = P["light"]
	sun.light_color = Color(lt[0])
	_base = {"sun": maxf(float(lt[1]), SUN_MIN), "amb": maxf(float(lt[3]), AMB_MIN)}
	sun.light_energy = _base["sun"]
	env.ambient_light_color = Color(lt[2])
	env.ambient_light_energy = _base["amb"]
	sky_base = []
	for hex in sk:
		sky_base.append(Color(hex))
	light_base_color = sun.light_color
	ambient_base_color = env.ambient_light_color
	weather_sun = float(lt[1])
	weather_amb = float(lt[3])
	# 3B yağış
	rain_p.emitting = P.get("rain", 0.0) > 0.0 and enabled
	rain_p.visible = rain_p.emitting
	snow_p.emitting = P.get("snow", 0.0) > 0.0 and enabled
	snow_p.visible = snow_p.emitting
	_apply_amounts()
	# şimşek
	flash = 0.0
	_flash_env = []
	_bolt_age = 9.0
	_thunder_at = -1.0
	_next_flash = _rand_gap() if P.has("flash_every") else 999.0
	mat.set_shader_parameter("flash", 0.0)
	mat.set_shader_parameter("bolt", Vector4(0.5, 0.0, 9.0, 0.0))
	if audio != null:
		audio.set_ambient(P.get("rain_snd", 0.0), P.get("wind_snd", 0.0))

## Tema renklerini gökyüzü ve sahne ışığının üstüne bindirir.
## Bulut, yağış, şimşek zarfı ve ortam sesi ön ayarda kalır; şimşek hâlâ _base enerjisinin üstüne biner.
func blend_theme(bg_top: Color, bg_bottom: Color, light_col: Color, light_e: float, amb_col: Color, amb_e: float) -> void:
	if mat == null or sky_base.size() < 6:
		return
	var k := 0.62
	mat.set_shader_parameter("sky_top", (sky_base[0] as Color).lerp(bg_top, k))
	mat.set_shader_parameter("sky_mid", (sky_base[1] as Color).lerp(bg_top.lerp(bg_bottom, 0.4), k * 0.75))
	mat.set_shader_parameter("sky_horizon", (sky_base[2] as Color).lerp(bg_bottom, k * 0.8))
	mat.set_shader_parameter("haze", (sky_base[3] as Color).lerp(bg_bottom.lightened(0.12), k * 0.4))
	mat.set_shader_parameter("ground", (sky_base[5] as Color).lerp(bg_bottom, k * 0.5))
	sun.light_color = light_base_color.lerp(light_col, 0.78)
	var se := lerpf(weather_sun, light_e, 0.78)
	var ae := lerpf(weather_amb, amb_e, 0.78)
	_base["sun"] = maxf(se, SUN_MIN)
	_base["amb"] = maxf(ae, AMB_MIN)
	sun.light_energy = _base["sun"] + flash * 0.45
	env.ambient_light_color = ambient_base_color.lerp(amb_col, 0.8)
	env.ambient_light_energy = _base["amb"] + flash * 0.35


func is_dark() -> bool:
	return preset.get("dark_ui", false)

## Ekranı kaplayan perdenin (geçiş) rengi: gökyüzünün orta tonu
func veil_color() -> Color:
	return Color(preset["sky"][1])

func set_quality(q: int) -> void:
	quality = q
	_screen = Vector2i.ZERO
	if mat:
		mat.set_shader_parameter("quality", float(q))
		_apply_amounts()

func _apply_amounts() -> void:
	rain_p.amount = [160, 380, 700][quality]
	snow_p.amount = [120, 260, 480][quality]

## Yağışı seviyenin çevresine yerleştirir (kamera hedefi ve seviye boyutu)
func place(center: Vector3, size: Vector3) -> void:
	var ext := Vector3(maxf(size.x, size.z) * 0.5 + 6.0, 0.5, maxf(size.x, size.z) * 0.5 + 6.0)
	for p in [rain_p, snow_p]:
		p.position = center + Vector3(0, size.y * 0.5 + 7.0, 0)
		p.emission_box_extents = ext
	rain_p.preprocess = 1.0
	snow_p.preprocess = 8.0
	rain_p.restart()
	snow_p.restart()

## Gökyüzü çizim hızı: bulutlar saniyede birkaç piksel kayar; durgun havada 2 karede bir çizmek gözle ayırt
## edilmez ve tam ekran gökyüzü shader'ının maliyetini yarıya indirir. Kamera dönerken, şimşek/yıldırımda ve
## hızlı katmanlarda (yağmur, kar, hortum) her kare çizilir.
var sky_every := 2
var _sky_frame := 0
var _sky_dirty := true
var _last_yaw := 999.0

func set_view(yaw_rad: float, aspect: float, screen := Vector2.ZERO) -> void:
	var want := Vector2i((screen * RES_SCALE[quality]).round())
	if screen != Vector2.ZERO and want != _screen:
		_screen = want
		vp.size = Vector2i(maxi(want.x, 16), maxi(want.y, 16))
		sky.size = Vector2(vp.size)
		_sky_dirty = true
	if absf(yaw_rad - _last_yaw) > 0.0005:
		_last_yaw = yaw_rad
		_sky_dirty = true
	if mat:
		mat.set_shader_parameter("yaw", yaw_rad)
		mat.set_shader_parameter("aspect", aspect)

func _sky_fast() -> bool:
	return flash > 0.0 or _bolt_age < 1.0 or float(preset.get("rain", 0.0)) > 0.0 or float(preset.get("snow", 0.0)) > 0.0 \
		or float(preset.get("tornado", 0.0)) > 0.0

func _update_sky_rate() -> void:
	_sky_frame += 1
	if _sky_dirty or _sky_fast() or sky_every <= 1 or _sky_frame % sky_every == 0:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_sky_dirty = false

func _rand_gap() -> float:
	var r: Array = preset.get("flash_every", [5.0, 9.0])
	return randf_range(r[0], r[1])

## Bir şimşek/yıldırım: göğü ve sahneyi çakarak aydınlatır, kısa süre sonra gök gürler.
func strike(ground := -1.0) -> void:
	var g: bool = randf() < float(preset.get("ground_bolt", 0.3)) if ground < 0.0 else ground > 0.5
	var bx := randf_range(0.08, 0.92)
	if absf(bx - 0.5) < 0.12:
		bx += 0.25 * signf(bx - 0.5 + 0.001)
	_bolt_age = 0.0 if g or randf() < 0.4 else 9.0
	mat.set_shader_parameter("bolt", Vector4(bx, randf() * 100.0, _bolt_age, 1.0 if g else 0.0))
	_flash_t = 0.0
	_flash_env = [[0.0, 1.0], [0.07, 0.25], [0.12, 0.85], [0.2, 0.3], [0.45, 0.0]]
	var dist := randf_range(0.15, 1.6)
	_thunder_at = dist
	_thunder_vol = clampf(1.2 - dist * 0.5, 0.35, 1.0) * (1.0 if g else 0.75)

func _process(dt: float) -> void:
	if mat == null:
		return
	_update_sky_rate()
	if preset.has("flash_every") and enabled:
		_next_flash -= dt
		if _next_flash <= 0.0:
			strike()
			_next_flash = _rand_gap()
	# çakma zarfı (doğrusal ara değer)
	if not _flash_env.is_empty():
		_flash_t += dt
		var f := 0.0
		for k in range(_flash_env.size() - 1):
			var a: Array = _flash_env[k]
			var b: Array = _flash_env[k + 1]
			if _flash_t >= a[0] and _flash_t <= b[0]:
				f = lerpf(a[1], b[1], (_flash_t - a[0]) / (b[0] - a[0]))
		if _flash_t > _flash_env[_flash_env.size() - 1][0]:
			_flash_env = []
			f = 0.0
		flash = f
		mat.set_shader_parameter("flash", flash)
		sun.light_energy = _base.get("sun", 0.3) + flash * 0.45
		env.ambient_light_energy = _base.get("amb", 0.4) + flash * 0.35
	if _bolt_age < 1.0:
		_bolt_age += dt
		var bv: Vector4 = mat.get_shader_parameter("bolt")
		bv.z = _bolt_age
		mat.set_shader_parameter("bolt", bv)
	if _thunder_at >= 0.0:
		_thunder_at -= dt
		if _thunder_at < 0.0 and audio != null:
			audio.thunder(_thunder_vol)

# ---------- 3B yağış ----------
func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3(0.12, -1, 0.05)
	p.spread = 2.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 18.0
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.9, 0.98, 0.42)
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	return p

func _make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.lifetime = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3(0.15, -1, 0.05)
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.1
	p.initial_velocity_max = 1.8
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gg
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	m.albedo_color = Color(1, 1, 1, 0.9)
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	return p
