class_name PerfHud
extends PanelContainer

const UPDATE_INTERVAL := 0.25
const MAX_GPU_NAME := 28

var governor: PerfGovernor

var _label: Label
var _acc := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = ""
	add_child(_label)
	visible = false
	set_process(false)

func setup(g: PerfGovernor) -> void:
	governor = g

func set_hud_visible(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		_acc = UPDATE_INTERVAL

func _process(delta: float) -> void:
	_acc += delta
	if _acc < UPDATE_INTERVAL:
		return
	_acc = 0.0
	_refresh()

func _refresh() -> void:
	if governor == null:
		_label.text = ""
		return
	var stats: Dictionary = governor.stats()
	if stats.is_empty():
		_label.text = ""
		return
	var lines: PackedStringArray = []
	var fps := float(stats.get("fps", 0.0))
	var avg_ms := float(stats.get("avg_frame_ms", -1.0))
	lines.append("FPS: %d  |  %.1f ms" % [int(round(fps)), avg_ms])
	var gpu := str(stats.get("gpu_name", ""))
	if gpu.length() > MAX_GPU_NAME:
		gpu = gpu.substr(0, MAX_GPU_NAME)
	if not gpu.is_empty():
		lines.append("GPU: %s" % gpu)
	var family := str(stats.get("gpu_family", ""))
	var profile := str(stats.get("profile", ""))
	if not family.is_empty() or not profile.is_empty():
		lines.append("Aile/Profil: %s / %s" % [family, profile])
	var scale := float(stats.get("render_scale_3d", -1.0))
	if scale >= 0.0:
		lines.append("3D Olcek: %.2f" % scale)
	var cap := int(stats.get("fps_cap", -1))
	if cap >= 0:
		lines.append("Cap: %d" % cap)
	if bool(stats.get("thermal_limited", false)):
		lines.append("[TERMAL]")
	elif bool(stats.get("idle", false)):
		lines.append("[IDLE]")
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	if draw_calls > 0:
		lines.append("Draw Calls: %d" % draw_calls)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	if prims > 0:
		lines.append("Primitives: %d" % prims)
	var vmem := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	if vmem > 0:
		lines.append("VRAM: %.1f MB" % (float(vmem) / 1048576.0))
	_label.text = "\n".join(lines)
