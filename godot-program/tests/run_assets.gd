## Harici .glb varlıklarının (tools/blender_asset_generator.py) oyunla uyumu.
## godot --headless --path godot-program --script res://tests/run_assets.gd
extends SceneTree

func _has_mat(n: Node, name: String) -> bool:
	for mi in PartBuilder._meshes_in(n):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm != null and sm.resource_name == name:
				return true
	return false

func _box(n: Node) -> AABB:
	var acc := {"box": AABB(), "first": true}
	PartBuilder._accum(n, Transform3D.IDENTITY, acc)
	return acc["box"]

func _init() -> void:
	var fails := []
	var robot := AssetLoader.robot_model()
	if robot == null:
		fails.append("robot.glb yok")
	else:
		if not _has_mat(robot, "RobotLED"):
			fails.append("robot: RobotLED yuvası yok")
		var t := AssetLoader.triangle_count(robot)
		if t > 40000:
			fails.append("robot üçgen %d > 40000" % t)
		var b := _box(robot)
		if absf(b.position.y) > 0.01:
			fails.append("robot tabanı y=0 değil")
	for nm in ["smd_transistor", "diode", "capacitor", "resistor", "relay", "bridge"]:
		var c := AssetLoader.component_model(nm, "top" if nm == "bridge" else true)
		if c == null:
			fails.append("bileşen yok: " + nm)
			continue
		var b2 := _box(c)
		if b2.size.x > 1.02 or b2.size.z > 1.02 or b2.size.x < 0.9:
			fails.append("%s 1x1 tabana oturmuyor: %s" % [nm, b2.size])
		if nm != "bridge" and absf(b2.position.y) > 0.01:
			fails.append("%s tabanı y=0 değil" % nm)
		if nm == "bridge" and absf(b2.end.y) > 0.01:
			fails.append("köprü üst yüzü y=0 değil")
		if AssetLoader.triangle_count(c) > 32000:
			fails.append("%s üçgen bütçesi" % nm)
		if nm in ["smd_transistor", "diode", "capacitor", "resistor", "relay"] and not _has_mat(c, "Pins"):
			fails.append("%s: Pins yuvası yok" % nm)
	var res := AssetLoader.component_model("resistor")
	if res != null:
		for k in 4:
			if not _has_mat(res, "Band%d" % (k + 1)):
				fails.append("direnç: Band%d yuvası yok" % (k + 1))
	var tot := 0
	for p in PCPartLibrary.all():
		var pd: PCPartData = p
		var m := AssetLoader.part_model(pd.part_id, pd.assembly_scale, pd.optional_glb_path)
		if m == null:
			fails.append("parça modeli yok: %d" % pd.part_id)
			continue
		var b3 := _box(m)
		if b3.size.x > pd.assembly_scale.x + 0.01 or b3.size.y > pd.assembly_scale.y + 0.01 or b3.size.z > pd.assembly_scale.z + 0.01:
			fails.append("parça %d montaj kutusundan taşıyor" % pd.part_id)
		var tc := AssetLoader.triangle_count(m)
		tot += tc
		if tc > 56000:
			fails.append("parça %d üçgen %d" % [pd.part_id, tc])
	if not _has_mat(AssetLoader.part_model(94, PCPartLibrary.part(94).assembly_scale), "MonitorScreen"):
		fails.append("monitör ekranı: MonitorScreen yuvası yok")
	# oyundaki kullanım: bileşen fabrikası modeli kullanır, direnç bantları gecikmeye göre boyanır
	var n := ComponentFactory.build(ComponentFactory.ComponentType.RESISTOR, 0, 2)
	if not n.has_meta("glow_mats") or (n.get_meta("glow_mats") as Array).is_empty():
		fails.append("fabrika: direnç modeli/bacak parlaması bağlanmadı")
	# iskeletli robot: 7 animasyon
	var ap := AssetLoader.anim_player(AssetLoader.robot_model())
	if ap == null:
		fails.append("robot: AnimationPlayer yok")
	else:
		for clip in ["idle", "walk", "turn", "fall", "victory", "wave", "look"]:
			if not ap.has_animation(clip):
				fails.append("robot animasyonu yok: " + clip)
	# bulmaca nesneleri
	for nm in ["stairs", "goal_crystal", "crate", "lever_base", "lever_arm", "crank_base", "crank_wheel", "handle",
			"slider", "portal", "plate", "crumble", "phantom"]:
		var pz := AssetLoader.load_model(AssetLoader.MODELS + "puzzle/%s.glb" % nm, Vector3.ONE)
		if pz == null:
			fails.append("bulmaca modeli yok: " + nm)
		elif AssetLoader.triangle_count(pz) > 24000:
			fails.append("bulmaca %s üçgen bütçesi" % nm)
	for pair in [["goal_crystal", "CrystalCore"], ["plate", "PlateLED"], ["portal", "PortalGlow"], ["phantom", "PhantomFrame"]]:
		var pm := AssetLoader.load_model(AssetLoader.MODELS + "puzzle/%s.glb" % pair[0], Vector3.ONE)
		if pm != null and not _has_mat(pm, pair[1]):
			fails.append("%s: %s yuvası yok" % pair)
	# sahneler ve tema dekorları
	for sc in ["workshop", "title_diorama"]:
		var sn := AssetLoader.scene_model(sc)
		if sn == null:
			fails.append("sahne yok: " + sc)
		elif AssetLoader.triangle_count(sn) > 160000:
			fails.append("sahne %s üçgen bütçesi" % sc)
	var dio := AssetLoader.scene_model("title_diorama")
	if dio != null and dio.find_child("RobotSpot", true, false) == null:
		fails.append("diorama: RobotSpot yok")
	for k in range(1, ThemeLibrary.COUNT + 1):
		var tm := AssetLoader.theme_model(k)
		if tm == null:
			fails.append("tema dekoru yok: %d" % k)
		else:
			var tb := _box(tm)
			if tb.size.x > 1.41 or tb.size.y > 2.61 or tb.size.z > 2.41:
				fails.append("tema %d dekoru alanından taşıyor" % k)
	# 2D: faz ikonları, komut ikonları, PCB doku seti
	for k in range(1, 11):
		if not ResourceLoader.exists("res://assets/ui/phase_%02d.png" % k):
			fails.append("faz ikonu yok: %d" % k)
	for c in UIKit.CMD_KINDS:
		if UIKit.cmd_texture(c) == null:
			fails.append("komut ikonu yok: " + c)
	for f in ["albedo", "normal", "mask"]:
		if not ResourceLoader.exists(AssetLoader.PBR + "pcb_detail/%s.png" % f):
			fails.append("PCB dokusu yok: " + f)
	print("assets: parça üçgeni toplam %d · %s" % [tot, "TAMAM" if fails.is_empty() else "HATA " + str(fails)])
	quit(0 if fails.is_empty() else 1)
