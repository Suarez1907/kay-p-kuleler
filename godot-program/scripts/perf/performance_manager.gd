extends Node
## PerformanceManager - tek merkezli performans yöneticisi.
## Vulkan mobil (Mali/Adreno) profilleri, termal koruma, idle throttle,
## dinamik çözünürlük ve performans istatistikleri burada yönetilir.

enum Quality { ULTRA, HIGH, BALANCED, BATTERY }
enum GpuTier { MALI, ADRENO, OTHER }

signal gpu_detected(vendor: String, adapter_name: String, tier: int)
signal profile_changed(profile: int)
signal idle_state_changed(is_idle: bool)
signal scale_changed(scale: float)

const SETTINGS_PATH := "user://settings.cfg"
const IDLE_THRESHOLD_SEC := 3.0
const IDLE_FPS := 30
const DRS_DOWN_STEP := 0.05
const DRS_MIN_SCALE := 0.75
const DRS_STRESS_SEC := 3.0
const DRS_RELAX_SEC := 6.0

const _PROFILE_NAMES := ["ULTRA", "HIGH", "BALANCED", "BATTERY"]

var _gpu_vendor: String = ""
var _gpu_name: String = ""
var _gpu_tier: int = GpuTier.OTHER

var _profile: int = Quality.BALANCED
var _profile_auto: bool = true
var _target_fps: int = 60
var _smart_thermal: bool = true

var _base_scale: float = 0.8
var _current_scale: float = 0.8

var _last_activity_usec: int = 0
var _idle_throttled: bool = false
var _activity_active: bool = false
var _cinematic_active: bool = false

var _ema_frame_ms: float = 16.6
var _stress_accum: float = 0.0
var _relax_accum: float = 0.0

var _last_frame_usec: int = 0

func _ready() -> void:
	_last_frame_usec = Time.get_ticks_usec()
	_last_activity_usec = _last_frame_usec

	_gpu_vendor = RenderingServer.get_video_adapter_vendor()
	_gpu_name = RenderingServer.get_video_adapter_name()
	_gpu_tier = detect_gpu_tier()
	gpu_detected.emit(_gpu_vendor, _gpu_name, _gpu_tier)

	_load_settings()

	if _profile_auto:
		_profile = _auto_profile_for_tier()

	_setup_scaling_mode()
	apply_profile(_profile)

func _setup_scaling_mode() -> void:
	var win := get_window()
	if win == null:
		return
	win.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	win.scaling_3d_scale = _current_scale

func detect_gpu_tier() -> int:
	var combined := (_gpu_vendor + " " + _gpu_name).to_lower()
	if combined.contains("mali") or combined.contains("immortalis") or combined.contains("dimensity"):
		return GpuTier.MALI
	if combined.contains("adreno") or combined.contains("qualcomm"):
		return GpuTier.ADRENO
	return GpuTier.OTHER

func get_gpu_info() -> Dictionary:
	return {
		"vendor": _gpu_vendor,
		"name": _gpu_name,
		"tier": _gpu_tier,
	}

func _auto_profile_for_tier() -> int:
	match _gpu_tier:
		GpuTier.MALI:
			return Quality.HIGH
		GpuTier.ADRENO:
			return Quality.HIGH
		_:
			return Quality.BALANCED

func _profile_settings(profile: int) -> Dictionary:
	var settings := {
		"scale": 0.8,
		"msaa_3d": Viewport.MSAA_2X,
		"directional_shadow_size": 1024,
		"glow_levels": 0,
		"particles_amount_ratio": 0.5,
		"mesh_lod_threshold": 0.20,
	}
	match profile:
		Quality.ULTRA:
			settings = {
				"scale": 1.0,
				"msaa_3d": Viewport.MSAA_4X,
				"directional_shadow_size": 2048,
				"glow_levels": 2,
				"particles_amount_ratio": 1.0,
				"mesh_lod_threshold": 0.05,
			}
		Quality.HIGH:
			settings = {
				"scale": 0.9,
				"msaa_3d": Viewport.MSAA_2X,
				"directional_shadow_size": 2048,
				"glow_levels": 1,
				"particles_amount_ratio": 0.75,
				"mesh_lod_threshold": 0.10,
			}
		Quality.BALANCED:
			settings = {
				"scale": 0.8,
				"msaa_3d": Viewport.MSAA_2X,
				"directional_shadow_size": 1024,
				"glow_levels": 0,
				"particles_amount_ratio": 0.5,
				"mesh_lod_threshold": 0.20,
			}
		Quality.BATTERY:
			settings = {
				"scale": 0.72,
				"msaa_3d": Viewport.MSAA_DISABLED,
				"directional_shadow_size": 1024,
				"glow_levels": 0,
				"particles_amount_ratio": 0.25,
				"mesh_lod_threshold": 0.35,
			}

	# Tier ince ayarı.
	match _gpu_tier:
		GpuTier.MALI:
			settings["glow_levels"] = 0
			if profile == Quality.ULTRA:
				settings["msaa_3d"] = Viewport.MSAA_4X
			else:
				settings["msaa_3d"] = Viewport.MSAA_2X
		GpuTier.ADRENO:
			settings["msaa_3d"] = Viewport.MSAA_2X
		GpuTier.OTHER:
			if profile == Quality.ULTRA:
				settings["msaa_3d"] = Viewport.MSAA_2X
			elif profile == Quality.BATTERY:
				settings["msaa_3d"] = Viewport.MSAA_DISABLED
			settings["directional_shadow_size"] = 1024

	return settings

func apply_profile(profile: int) -> void:
	_profile = clampi(profile, Quality.ULTRA, Quality.BATTERY)
	var s := _profile_settings(_profile)

	_base_scale = float(s["scale"])
	_current_scale = _base_scale

	_apply_project_setting("rendering/anti_aliasing/quality/msaa_3d", int(s["msaa_3d"]))
	_apply_project_setting("rendering/lights_and_shadows/directional_shadow/size", int(s["directional_shadow_size"]))
	if ProjectSettings.has_setting("rendering/quality/environment/glow_levels"):
		_apply_project_setting("rendering/quality/environment/glow_levels", int(s["glow_levels"]))
	if ProjectSettings.has_setting("particles_amount_ratio"):
		_apply_project_setting("particles_amount_ratio", float(s["particles_amount_ratio"]))
	_apply_project_setting("rendering/mesh_lod/lod_change/threshold_pixels", float(s["mesh_lod_threshold"]))

	var win := get_window()
	if win != null:
		win.scaling_3d_scale = _current_scale

	Engine.max_fps = _target_fps
	scale_changed.emit(_current_scale)
	profile_changed.emit(_profile)

func _apply_project_setting(key: String, value: Variant) -> void:
	if ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, value)

func get_profile() -> int:
	return _profile

func set_profile(p: int) -> void:
	_profile_auto = false
	apply_profile(p)
	_save_settings()

func set_profile_auto(auto: bool) -> void:
	_profile_auto = auto
	if auto:
		apply_profile(_auto_profile_for_tier())
	_save_settings()

func is_profile_auto() -> bool:
	return _profile_auto

func set_target_fps(fps: int) -> void:
	if fps <= 0:
		return
	_target_fps = fps
	if not _idle_throttled:
		Engine.max_fps = _target_fps
	_save_settings()

func get_target_fps() -> int:
	return _target_fps

func set_smart_thermal_enabled(enabled: bool) -> void:
	_smart_thermal = enabled
	if not enabled and _idle_throttled:
		_exit_idle()
	_save_settings()

func is_smart_thermal_enabled() -> bool:
	return _smart_thermal

func notify_activity() -> void:
	_last_activity_usec = Time.get_ticks_usec()
	if _idle_throttled:
		_exit_idle()

func set_activity(active: bool) -> void:
	_activity_active = active
	if active:
		notify_activity()

func set_cinematic_active(active: bool) -> void:
	_cinematic_active = active
	if active:
		notify_activity()

func get_current_scale() -> float:
	return _current_scale

func get_idle_throttled() -> bool:
	return _idle_throttled

func get_average_frame_time_ms() -> float:
	return _ema_frame_ms

func _exit_idle() -> void:
	_idle_throttled = false
	Engine.max_fps = _target_fps
	idle_state_changed.emit(false)

func _enter_idle() -> void:
	_idle_throttled = true
	Engine.max_fps = IDLE_FPS
	idle_state_changed.emit(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch \
		or event is InputEventScreenDrag \
		or event is InputEventMouseButton \
		or event is InputEventKey:
		notify_activity()

func _process(delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	var frame_ms := float(now_usec - _last_frame_usec) / 1000.0
	_last_frame_usec = now_usec
	if frame_ms > 0.0 and frame_ms < 1000.0:
		_ema_frame_ms = lerpf(_ema_frame_ms, frame_ms, 0.1)

	_update_idle(now_usec)
	_update_drs(delta)

func _update_idle(now_usec: int) -> void:
	if not _smart_thermal:
		if _idle_throttled:
			_exit_idle()
		return

	var busy := _activity_active or _cinematic_active
	var idle_sec := float(now_usec - _last_activity_usec) / 1000000.0

	if busy:
		_last_activity_usec = now_usec
		if _idle_throttled:
			_exit_idle()
		return

	if idle_sec >= IDLE_THRESHOLD_SEC:
		if not _idle_throttled:
			_enter_idle()
	else:
		if _idle_throttled:
			_exit_idle()

func _target_frame_ms() -> float:
	match _target_fps:
		90:
			return 11.5
		120:
			return 9.0
		_:
			return 18.5

func _update_drs(delta: float) -> void:
	var threshold := _target_frame_ms()

	if _ema_frame_ms > threshold:
		_stress_accum += delta
		_relax_accum = 0.0
		if _stress_accum >= DRS_STRESS_SEC:
			_stress_accum = 0.0
			if _current_scale > DRS_MIN_SCALE:
				_current_scale = maxf(_current_scale - DRS_DOWN_STEP, DRS_MIN_SCALE)
				_apply_scale()
	else:
		_stress_accum = 0.0
		if _ema_frame_ms < 13.0:
			_relax_accum += delta
			if _relax_accum >= DRS_RELAX_SEC:
				_relax_accum = 0.0
				if _current_scale < _base_scale:
					_current_scale = minf(_current_scale + DRS_DOWN_STEP, _base_scale)
					_apply_scale()
		else:
			_relax_accum = 0.0

func _apply_scale() -> void:
	var win := get_window()
	if win != null:
		win.scaling_3d_scale = _current_scale
	scale_changed.emit(_current_scale)

func get_stats() -> Dictionary:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram_bytes := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	return {
		"fps": fps,
		"frame_ms": _ema_frame_ms,
		"gpu_name": _gpu_name,
		"gpu_vendor": _gpu_vendor,
		"tier": _gpu_tier,
		"profile": _PROFILE_NAMES[_profile],
		"profile_index": _profile,
		"profile_auto": _profile_auto,
		"scale": _current_scale,
		"idle": _idle_throttled,
		"target_fps": _target_fps,
		"draw_calls": int(draw_calls),
		"primitives": int(primitives),
		"video_ram_mb": vram_bytes / (1024.0 * 1024.0),
	}

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_profile_auto = true
		_target_fps = 60
		_smart_thermal = true
		return
	_profile_auto = bool(cfg.get_value("perf", "profile_auto", true))
	_profile = int(cfg.get_value("perf", "profile", Quality.BALANCED))
	_target_fps = int(cfg.get_value("perf", "target_fps", 60))
	_smart_thermal = bool(cfg.get_value("perf", "smart_thermal", true))
	_profile = clampi(_profile, Quality.ULTRA, Quality.BATTERY)
	if _target_fps not in [60, 90, 120]:
		_target_fps = 60

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("perf", "profile_auto", _profile_auto)
	cfg.set_value("perf", "profile", _profile)
	cfg.set_value("perf", "target_fps", _target_fps)
	cfg.set_value("perf", "smart_thermal", _smart_thermal)
	cfg.save(SETTINGS_PATH)
