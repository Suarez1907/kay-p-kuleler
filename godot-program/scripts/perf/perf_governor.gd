## Akıcılık yöneticisi:
##  1) Varlık önbelleği + shader ısıtma: bütün devre elemanı, bulmaca, robot, tema ve sinematik modelleri ilk
##     ekranda arka arkaya (kare başına birkaç tane) yüklenir ve gizli küçük bir SubViewport'ta birkaç kare çizilir.
##     Böylece seviyede ilk kez görünen malzeme/mesh için disk okuması ve boru hattı derlemesi oyun sırasında olmaz.
##  2) Otomatik kalite: ilk açılışta (kayıtta grafik ayarı yoksa) başlık ekranında kare süresi ölçülür, Düşük/Orta/
##     Yüksek seçilir.
##  3) Dinamik çözünürlük: kare süresi hedefi (ekran yenileme hızı) aşılırsa 3D çözünürlük ölçeği kademeli düşer,
##     rahatlayınca geri çıkar. Arayüz her zaman tam çözünürlükte kalır.
##  4) Kare hızı: varsayılan 60 FPS sınırı (Ayarlar'dan 120). Sahne durağanken (dokunma yok, Robo çalışmıyor,
##     kamera/animasyon yok) 30 FPS: görüntü aynı, GPU yükü ve ısı yarıya iner. Telefon ısınıp kareler uzun süre
##     hedefin altında kalırsa sınır geçici olarak 45'e iner (termal kısma → donma döngüsü kırılır).
class_name PerfGovernor
extends Node

signal quality_picked(level: int)

const WARM_DIRS := ["res://assets/models/components/", "res://assets/models/puzzle/", "res://assets/models/themes/",
	"res://assets/models/scenes/", "res://assets/animations/", "res://assets/models/backdrops/"]
const WARM_FILES := ["res://assets/models/robot.glb"]

var cache: Array = []                # yüklenen kaynaklar burada tutulur (önbellekten düşmesin)
var warm_done := false
var vp: Viewport
var base_scale := 1.0                # grafik ayarının ölçeği
var dyn_scale := 1.0
var target_ms := 16.67
var enabled := true
var _ft: Array = []
var _over := 0.0
var _under := 0.0
var _bench := {}
var _queue: Array = []
var _warm_vp: SubViewport
var _warm_frames := 0

var hz := 60.0
var fps_cap := 60                    # Ayarlar: 60 (varsayılan) ya da 120
var busy := false                    # main her kare bildirir: Robo çalışıyor, kamera/animasyon hareketli…
var smart_protection := true         # Akıllı Pil & Isı Koruma (varsayılan açık)
var gpu_family := "unknown"
var profile_name := "BALANCED"
var _idle_t := 0.0
var _hot_t := 0.0
var _thermal_t := 0.0                # > 0 iken ısınma koruması: sınır 45
const IDLE_AFTER := 2.0
const IDLE_FPS := 30
const THERMAL_FPS := 45

const PROFILES := {
	"ULTRA": {"scale": 1.0, "shadow_atlas": 2048, "msaa": 2, "glow": true, "particle_mul": 1.0},
	"HIGH": {"scale": 0.9, "shadow_atlas": 2048, "msaa": 2, "glow": true, "particle_mul": 1.0},
	"BALANCED": {"scale": 0.8, "shadow_atlas": 1024, "msaa": 0, "glow": true, "particle_mul": 0.75},
	"BATTERY": {"scale": 0.72, "shadow_atlas": 1024, "msaa": 0, "glow": false, "particle_mul": 0.5},
}

func setup(viewport: Viewport) -> void:
	vp = viewport
	hz = DisplayServer.screen_get_refresh_rate()
	if is_nan(hz) or is_inf(hz) or hz <= 1.0:   # bazı sürücüler -1 ya da NaN döndürür
		hz = 60.0
	hz = clampf(hz, 30.0, 144.0)
	target_ms = 1000.0 / hz
	detect_gpu_profile()
	set_fps_cap(fps_cap)

func set_fps_cap(cap: int) -> void:
	fps_cap = cap
	res_target_ms = 1000.0 / float(mini(fps_cap, int(round(hz))))
	_apply_fps()

## Kullanıcı dokundu / bir şey değişti: hemen tam kare hızına dön
func touch() -> void:
	_idle_t = 0.0
	if Engine.max_fps != current_cap():
		_apply_fps()

func current_cap() -> int:
	var c := mini(fps_cap, int(round(hz)))
	if smart_protection:
		if _thermal_t > 0.0:
			c = mini(c, THERMAL_FPS)
		if _idle_t > IDLE_AFTER and not busy:
			c = mini(c, IDLE_FPS)
	return c

func set_smart_protection(on: bool) -> void:
	smart_protection = on
	if not on:
		_idle_t = 0.0
		_thermal_t = 0.0
	_apply_fps()

func detect_gpu_profile() -> String:
	var adapter := ""
	var rs_name = RenderingServer.get_video_adapter_name()
	if rs_name != null:
		adapter = str(rs_name).to_lower()
	if adapter.contains("mali") or adapter.contains("immortalis"):
		gpu_family = "mali"
		profile_name = "HIGH"
	elif adapter.contains("adreno"):
		gpu_family = "adreno"
		profile_name = "HIGH"
	elif adapter.contains("apple"):
		gpu_family = "apple"
		profile_name = "ULTRA"
	else:
		gpu_family = "unknown"
		profile_name = "BALANCED"
	return profile_name

func apply_profile(name: String) -> void:
	if not PROFILES.has(name):
		name = "BALANCED"
	var p: Dictionary = PROFILES[name]
	profile_name = name
	set_base_scale(float(p["scale"]))
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_2X if int(p["msaa"]) == 2 else Viewport.MSAA_DISABLED
	var atlas := int(p["shadow_atlas"])
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)

func _apply_fps() -> void:
	var c := current_cap()
	if Engine.max_fps != c:
		Engine.max_fps = c
		_ft.clear()

func set_base_scale(s: float) -> void:
	base_scale = s
	dyn_scale = s
	_ft.clear()
	_apply()

var res_target_ms := 1000.0 / 60.0

func _apply() -> void:
	if vp != null:
		vp.scaling_3d_scale = clampf(dyn_scale, 0.5, 2.0)
		# ölçek 1'in altına inmek zorunda kalırsa FSR 1.0 (kenar duyarlı keskinleştirmeli büyütme): aynı maliyette
		# bilinear'dan çok daha net; tam çözünürlükte ölçekleme yapılmaz
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if vp.scaling_3d_scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.fsr_sharpness = 0.2

# ---------------------------------------------------------------------------
# varlık önbelleği + shader ısıtma
## extra: önceden yüklenecek ek kaynaklar (ör. oyuncunun açacağı seviyenin fırınlanmış sahnesi + ışık haritası)
func start_warmup(extra: Array = []) -> void:
	_queue = []
	for f in extra:
		if ResourceLoader.exists(f):
			_queue.append(f)
	for f in WARM_FILES:
		if ResourceLoader.exists(f):
			_queue.append(f)
	for d in WARM_DIRS:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for fn in da.get_files():
			var f := fn.trim_suffix(".remap").trim_suffix(".import")
			if f.ends_with(".glb") and not (d + f) in _queue and ResourceLoader.exists(d + f):
				_queue.append(d + f)
	# dokular (PBR setleri, PCB, arayüz ikonları) de önceden yüklenir
	for d in ["res://assets/textures/pbr/", "res://assets/ui/"]:
		_add_textures(d)
	_warm_vp = SubViewport.new()
	_warm_vp.size = Vector2i(96, 96)
	_warm_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_warm_vp.own_world_3d = true
	add_child(_warm_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4.0)
	_warm_vp.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	_warm_vp.add_child(sun)
	sun.rotation = Vector3(-0.9, 0.6, 0)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# oyunun gerçek ortamı (HDRI ortam/yansıma ışığı, AgX, parlama): aynı shader/pipeline varyantları ısınır
	StudioLighting.apply(env, StudioLighting.STUDIO, 1.0, 0.65, 1.0)
	we.environment = env
	_warm_vp.add_child(we)

func _add_textures(d: String) -> void:
	var da := DirAccess.open(d)
	if da == null:
		return
	for sub in da.get_directories():
		_add_textures(d + sub + "/")
	for fn in da.get_files():
		var f := fn.trim_suffix(".import").trim_suffix(".remap")
		if (f.ends_with(".png") or f.ends_with(".jpg")) and not (d + f) in _queue and ResourceLoader.exists(d + f):
			_queue.append(d + f)

func _process(dt: float) -> void:
	if not warm_done and _warm_vp != null:
		_warm_step()
	_idle_t = 0.0 if busy else _idle_t + dt
	if _thermal_t > 0.0:
		_thermal_t = maxf(0.0, _thermal_t - dt)
	_apply_fps()
	_track(dt)

func _warm_step() -> void:
	# kare başına iki dosya: yükle, gizli görünüme koy (bir kare çizilsin), sonra sil
	for c in _warm_vp.get_children():
		if c.has_meta("warm"):
			c.queue_free()
	if _queue.is_empty():
		_warm_frames += 1
		if _warm_frames > 2:
			warm_done = true
			_warm_vp.queue_free()
			_warm_vp = null
		return
	for k in 3:
		if _queue.is_empty():
			break
		var f: String = _queue.pop_front()
		var res = load(f)
		if res == null:
			continue
		cache.append(res)
		if res is PackedScene:
			var inst: Node = (res as PackedScene).instantiate()
			if inst is Node3D:
				inst.set_meta("warm", true)
				(inst as Node3D).scale = Vector3.ONE * 0.2
				_warm_vp.add_child(inst)
			else:
				inst.free()

func progress() -> float:
	return 1.0 if warm_done else 1.0 - float(_queue.size()) / maxf(1.0, float(_queue.size() + cache.size()))

# ---------------------------------------------------------------------------
# kare süresi izleme: dinamik çözünürlük + ilk açılış ölçümü
func _track(dt: float) -> void:
	var ms := dt * 1000.0
	_ft.append(ms)
	if _ft.size() > 60:
		_ft.pop_front()
	if not _bench.is_empty():
		_bench["sum"] = float(_bench["sum"]) + ms
		_bench["n"] = int(_bench["n"]) + 1
		if int(_bench["n"]) >= 120:
			var avg := float(_bench["sum"]) / float(_bench["n"])
			var lvl := 2
			if avg > res_target_ms * 2.0:
				lvl = 0
			elif avg > res_target_ms * 1.35:
				lvl = 1
			_bench = {}
			quality_picked.emit(lvl)
	if not enabled or not warm_done or _ft.size() < 30:
		return
	var avg2 := 0.0
	for v in _ft:
		avg2 += v
	avg2 /= _ft.size()
	var goal_ms := 1000.0 / float(maxi(1, Engine.max_fps if Engine.max_fps > 0 else 60))
	# ısınma: tam hızda kareler 8 sn boyunca hedefin belirgin altında → 90 sn boyunca 45 FPS sınırı
	if Engine.max_fps >= 55 and avg2 > goal_ms * 1.3:
		_hot_t += dt
		if _hot_t > 8.0 and _thermal_t <= 0.0:
			_thermal_t = 90.0
			_hot_t = 0.0
	else:
		_hot_t = maxf(0.0, _hot_t - dt)
	if avg2 > goal_ms * 1.18:
		_over += dt
		_under = 0.0
	elif avg2 < goal_ms * 0.85:
		_under += dt
		_over = 0.0
	else:
		_over = 0.0
		_under = 0.0
	if _over > 1.5 and dyn_scale > 0.6:
		dyn_scale = maxf(0.6, dyn_scale - 0.1)
		_over = 0.0
		_ft.clear()
		_apply()
	elif _under > 4.0 and dyn_scale < base_scale:
		dyn_scale = minf(base_scale, dyn_scale + 0.05)
		_under = 0.0
		_apply()

## İlk açılış ölçümü: ısıtma bittikten sonra 120 kare
func start_benchmark() -> void:
	_bench = {"sum": 0.0, "n": 0}

func fps() -> float:
	if _ft.is_empty():
		return 0.0
	var s := 0.0
	for v in _ft:
		s += v
	return 1000.0 / maxf(0.1, s / _ft.size())

func frame_ms() -> float:
	return 1000.0 / maxf(0.1, fps())

func avg_frame_ms() -> float:
	if _ft.is_empty():
		return 0.0
	var s := 0.0
	for v in _ft:
		s += v
	return s / _ft.size()

func stats() -> Dictionary:
	var adapter := ""
	var rs_name = RenderingServer.get_video_adapter_name()
	if rs_name != null:
		adapter = str(rs_name)
	var sc := 1.0
	if vp != null:
		sc = vp.scaling_3d_scale
	return {
		"fps": Engine.get_frames_per_second(),
		"avg_ms": avg_frame_ms(),
		"gpu": adapter,
		"family": gpu_family,
		"profile": profile_name,
		"scale": sc,
		"cap": current_cap(),
		"idle": _idle_t > IDLE_AFTER and not busy,
		"thermal": _thermal_t > 0.0,
	}
