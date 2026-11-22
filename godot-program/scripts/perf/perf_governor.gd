## Akıcılık yöneticisi:
##  1) Varlık önbelleği + shader ısıtma: bütün devre elemanı, bulmaca, robot, tema ve sinematik modelleri ilk
##     ekranda arka arkaya (kare başına birkaç tane) yüklenir ve gizli küçük bir SubViewport'ta birkaç kare çizilir.
##     Böylece seviyede ilk kez görünen malzeme/mesh için disk okuması ve boru hattı derlemesi oyun sırasında olmaz.
##  2) Otomatik kalite: ilk açılışta (kayıtta grafik ayarı yoksa) başlık ekranında kare süresi ölçülür, Düşük/Orta/
##     Yüksek seçilir.
##  3) Dinamik çözünürlük: kare süresi hedefi (ekran yenileme hızı) aşılırsa 3D çözünürlük ölçeği kademeli düşer,
##     rahatlayınca geri çıkar. Arayüz her zaman tam çözünürlükte kalır.
##  4) Kare hızı ekranın yenileme hızını izler (60/90/120 Hz).
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

func setup(viewport: Viewport) -> void:
	vp = viewport
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz <= 1.0:
		hz = 60.0
	hz = clampf(hz, 30.0, 144.0)
	target_ms = 1000.0 / hz
	Engine.max_fps = int(round(hz))

func set_base_scale(s: float) -> void:
	base_scale = s
	dyn_scale = s
	_ft.clear()
	_apply()

func _apply() -> void:
	if vp != null:
		vp.scaling_3d_scale = clampf(dyn_scale, 0.5, 2.0)

# ---------------------------------------------------------------------------
# varlık önbelleği + shader ısıtma
func start_warmup() -> void:
	_queue = []
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
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
		if f.ends_with(".png") and not (d + f) in _queue and ResourceLoader.exists(d + f):
			_queue.append(d + f)

func _process(dt: float) -> void:
	if not warm_done and _warm_vp != null:
		_warm_step()
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
			if avg > target_ms * 2.0:
				lvl = 0
			elif avg > target_ms * 1.35:
				lvl = 1
			_bench = {}
			quality_picked.emit(lvl)
	if not enabled or not warm_done or _ft.size() < 30:
		return
	var avg2 := 0.0
	for v in _ft:
		avg2 += v
	avg2 /= _ft.size()
	if avg2 > target_ms * 1.18:
		_over += dt
		_under = 0.0
	elif avg2 < target_ms * 0.85:
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
