## Blender sinematik paketleri (tools/blender_animation_studio.py) ve ASMR ses dosyaları (tools/generate_asmr_audio.py)
## Godot'da yükleniyor mu: animasyon adları, kare sayıları (30 FPS), zorunlu düğümler, boş iz yok; ses dosyaları eksiksiz.
## godot --headless --path godot-program --script res://tests/run_cinematics.gd
extends SceneTree

const DIR := "res://assets/animations/"

func _ap(n: Node) -> AnimationPlayer:
	var f := n.find_children("*", "AnimationPlayer", true, false)
	return f[0] if f.size() > 0 else null

func _check(file: String, anims: Array, frames: int, nodes: Array, fails: Array) -> void:
	var path := DIR + file
	if not ResourceLoader.exists(path):
		fails.append("yok: " + file)
		return
	var n: Node = (load(path) as PackedScene).instantiate()
	var ap := _ap(n)
	if ap == null:
		fails.append("%s: AnimationPlayer yok" % file)
		n.free()
		return
	for a in anims:
		if not ap.has_animation(a):
			fails.append("%s: animasyon yok %s (var: %s)" % [file, a, ap.get_animation_list()])
			continue
		var an := ap.get_animation(a)
		var got := roundi(an.length * 30.0)
		if frames > 0 and absi(got - frames) > 2:
			fails.append("%s/%s: %d kare (beklenen %d)" % [file, a, got, frames])
		if an.get_track_count() == 0:
			fails.append("%s/%s: boş iz" % [file, a])
	for nd in nodes:
		if n.find_child(nd, true, false) == null:
			fails.append("%s: düğüm yok %s" % [file, nd])
	n.free()

func _init() -> void:
	var fails := []
	_check("level_end_rigs.glb", ["anim_drop_snap", "anim_angle_insert", "anim_vertical_slide", "anim_screw_lock", "anim_magnetic_orbit"], 240,
		["CameraRig", "PartSocketAnchor", "RobotHelperAnchor", "SparkAnchor"], fails)
	for ph in range(1, 10):
		_check("phase_finale_%02d.glb" % ph, ["phase_finale_%02d" % ph], 360, ["CameraRig", "PartSocketAnchor", "SparkAnchor", "LockMarkers"], fails)
	_check("robot_cinematic_anims.glb", ["robot_level_victory", "robot_inspect_snap", "robot_power_jump", "robot_finale_wave"], 0, [], fails)
	_check("grand_finale_100.glb", ["grand_finale_100"], 900, ["CameraRig", "PowerButtonAnchor", "FanSpeed", "PhaseWake_01", "PhaseWake_10", "RobotFinaleAnchor"], fails)
	# sinematik yönetmeni: yükleme ve arketip seçimi
	var lv := CinematicDirector.load_rig("level_end_rigs.glb")
	if lv.is_empty() or lv["cam"] == null:
		fails.append("CinematicDirector.level rig kamerası yok")
	if CinematicDirector.archetype_for(21) != "anim_drop_snap" or CinematicDirector.archetype_for(61) != "anim_screw_lock":
		fails.append("arketip eşlemesi")
	if CinematicDirector.kind_for(100) != "grand" or CinematicDirector.kind_for(40) != "phase" or CinematicDirector.kind_for(41) != "level":
		fails.append("sinematik türü seçimi")
	if not lv.is_empty():
		(lv["root"] as Node).free()
	# ASMR ses dosyaları
	var audio := 0
	for g in ["phase_1_2", "phase_3_4", "phase_5_6", "phase_7_8", "phase_9_10"]:
		for l in ["think", "code", "run"]:
			if ResourceLoader.exists("res://assets/audio/music/%s_%s.ogg" % [g, l]):
				audio += 1
			else:
				fails.append("müzik yok: %s_%s" % [g, l])
	for f in ["sfx/ui_key_thock_04", "sfx/step_note_c6", "sfx/sfx_relay_clack_02", "sfx/sfx_capacitor_launch", "assembly/sfx_part_snap_03",
			"assembly/sfx_fan_spinup", "assembly/sfx_boot_chord", "assembly/sfx_bios_beep", "assembly/sfx_power_switch"]:
		if ResourceLoader.exists("res://assets/audio/%s.ogg" % f):
			audio += 1
		else:
			fails.append("ses yok: " + f)
	var bl = load("res://default_bus_layout.tres")
	if not (bl is AudioBusLayout):
		fails.append("default_bus_layout.tres yüklenemedi")
	print("cinematics: %s · ses %d" % ["TAMAM" if fails.is_empty() else "HATA " + str(fails), audio])
	quit(0 if fails.is_empty() else 1)
