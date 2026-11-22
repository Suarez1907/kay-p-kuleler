## Bir PCPartData için 3B düğüm kurar. Önce optional_glb_path'teki .glb'yi dener (varsa parçanın sınır
## kutusuna sığdırılır), yoksa prosedürel modele düşer. Modeller MeshKit ile kurulur ve devre elemanlarıyla
## aynı malzemeyi (shaders/component.gdshader) paylaşır; böylece "glow" örnek parametresiyle enerji
## parlaması her parçada çalışır. Dönen fanlar meta "spin" (eksen) taşır.
class_name PartBuilder
extends RefCounted

static var _glass: StandardMaterial3D
static var _cache := {}

static func build(p: PCPartData) -> Node3D:
	var root := Node3D.new()
	root.name = "Parca%03d" % p.part_id
	root.position = p.assembly_position
	root.rotation_degrees = p.assembly_rotation
	root.set_meta("part_id", p.part_id)
	var glb := AssetLoader.part_model(p.part_id, p.assembly_scale, p.optional_glb_path)
	if glb != null:
		root.add_child(glb)
		root.set_meta("bodies", _meshes_in(glb))
		return root
	var bodies := []
	var key := "%s|%s|%s" % [p.procedural_shape, p.assembly_scale, p.color.to_html()]
	var parts: Dictionary = _cache.get(key, {})
	if parts.is_empty():
		parts = _procedural(p.procedural_shape, p.assembly_scale, p.color)
		_cache[key] = parts
	var mi := MeshInstance3D.new()
	mi.mesh = parts["main"]
	mi.material_override = ComponentFactory.material()
	root.add_child(mi)
	bodies.append(mi)
	if parts.has("spin"):
		var sp := MeshInstance3D.new()
		sp.mesh = parts["spin"]
		sp.material_override = ComponentFactory.material()
		root.add_child(sp)
		sp.set_meta("spin_axis", parts["axis"])
		root.set_meta("spinner", sp)
		bodies.append(sp)
	if parts.has("glass"):
		var g := MeshInstance3D.new()
		g.mesh = parts["glass"]
		g.material_override = _glass_mat()
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(g)
	root.set_meta("bodies", bodies)
	return root

## Parçanın tüm gövdelerine enerji parlaması
static func set_glow(n: Node3D, v: float) -> void:
	for b in n.get_meta("bodies", []):
		if b is GeometryInstance3D and (b as GeometryInstance3D).material_override is ShaderMaterial:
			(b as GeometryInstance3D).set_instance_shader_parameter("glow", v)

static func _meshes_in(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes_in(c))
	return out

static func _load_glb(path: String, size: Vector3) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	var inst: Node = (res as PackedScene).instantiate()
	if not (inst is Node3D):
		inst.queue_free()
		return null
	var n: Node3D = inst
	# modelin sınır kutusunu bulup parçanın kutusuna orantılı sığdır ve ortala
	var acc := {"box": AABB(), "first": true}
	_accum(n, Transform3D.IDENTITY, acc)
	var box: AABB = acc["box"]
	var first: bool = acc["first"]
	if first or box.size.length() < 1e-5:
		return n
	var s := minf(size.x / maxf(box.size.x, 1e-4), minf(size.y / maxf(box.size.y, 1e-4), size.z / maxf(box.size.z, 1e-4)))
	n.scale = Vector3.ONE * s
	n.position = -box.get_center() * s
	return n

static func _accum(n: Node, xf: Transform3D, acc: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc["box"] = b if acc["first"] else (acc["box"] as AABB).merge(b)
		acc["first"] = false
	for c in n.get_children():
		_accum(c, t, acc)

static func _glass_mat() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.albedo_color = Color(0.75, 0.88, 1.0, 0.12)
		_glass.roughness = 0.05
		_glass.metallic_specular = 1.0
		_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass

# ---------------------------------------------------------------------------
# Prosedürel şekiller. s = sınır kutusu boyutu, merkez yerel orijindir.
static func _procedural(shape: String, s: Vector3, c: Color) -> Dictionary:
	var k := MeshKit.new()
	var D := MeshKit.DIELECTRIC
	var M := MeshKit.METAL
	var G := MeshKit.GLOW
	var CU := MeshKit.COPPER
	var h := s / 2.0
	var col := func(cc, id: float) -> Color: return MeshKit.col(cc, id)
	var out := {}
	var dark := c.darkened(0.45)
	match shape:
		"pcb_board", "ssd", "gpu_pcb", "substrate":
			k.box(Vector3.ZERO, s, col.call(c, D))
			var thin := s.y if shape != "gpu_pcb" else s.z
			if shape == "gpu_pcb":
				# altın kontak parmakları (alt kenar) ve bakır yollar
				k.box(Vector3(0, -h.y + 0.04, 0), Vector3(s.x * 0.45, 0.08, s.z * 1.02), col.call("#d4af37", M))
				for i in 6:
					k.box(Vector3(-h.x + 0.2 + i * s.x / 7.0, 0.1, h.z + 0.001), Vector3(0.02, s.y * 0.7, 0.004), col.call("#3a8a5a", D))
			else:
				for i in 7:
					var zz := -h.z + (i + 0.5) * s.z / 7.0
					k.box(Vector3(0, h.y + 0.002, zz), Vector3(s.x * 0.86, 0.004, 0.012), col.call("#2f8a58", D))
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						k.ring(Vector3(sx * (h.x - 0.1), h.y + 0.002, sz * (h.z - 0.1)), 0.04, 0.02, 0.006, col.call("#d4af37", M), 12)
				if shape == "ssd":
					k.box(Vector3(-h.x * 0.2, h.y + 0.003, 0), Vector3(s.x * 0.5, 0.004, s.z * 0.7), col.call("#e8e8ee", D))
					k.box(Vector3(h.x - 0.03, 0, 0), Vector3(0.06, s.y * 1.05, s.z * 0.9), col.call("#d4af37", M))
		"standoff", "screw":
			k.cyl(Vector3(0, 0, 0), minf(h.x, h.z) * 0.9, s.y, col.call(c, M), 6)
			k.cyl(Vector3(0, h.y - 0.01, 0), minf(h.x, h.z), 0.02, col.call(c.lightened(0.2), M), 6)
		"trace", "coldplate":
			k.box(Vector3.ZERO, s, col.call(c, CU))
		"chip", "chip_flat":
			k.box(Vector3(0, -h.y * 0.1, 0), Vector3(s.x * 0.84, s.y * 0.9, s.z * 0.84), col.call(c, D))
			var n := int(clampf(s.x / 0.05, 3, 12))
			for i in n:
				var xx := -h.x * 0.8 + i * (s.x * 0.8) / maxi(1, n - 1)
				for sz in [-1.0, 1.0]:
					k.box(Vector3(xx, -h.y * 0.6, sz * (h.z * 0.92)), Vector3(0.012, s.y * 0.3, s.z * 0.08), col.call("#d2d5dc", M))
			k.cyl(Vector3(-h.x * 0.6, h.y * 0.82, -h.z * 0.5), minf(s.x, s.z) * 0.06, 0.004, col.call("#9a9aa2", D), 10)
		"battery":
			k.cyl(Vector3.ZERO, minf(h.x, h.z), s.y, col.call(c, M), 26)
			k.box(Vector3(0, h.y + 0.002, 0), Vector3(0.08, 0.004, 0.02), col.call("#ffd36e", G))
			k.box(Vector3(0, h.y + 0.002, 0), Vector3(0.02, 0.004, 0.08), col.call("#ffd36e", G))
		"header", "connector", "m2_slot", "dimm_slot", "pcie_slot", "clip":
			k.box(Vector3(0, -h.y * 0.2, 0), Vector3(s.x, s.y * 0.8, s.z), col.call(c, D))
			var along_x := s.x >= s.z
			var L: float = s.x if along_x else s.z
			var nn := int(clampf(L / 0.06, 2, 24))
			for i in nn:
				var t := -L / 2.0 * 0.9 + i * L * 0.9 / maxi(1, nn - 1)
				var pp := Vector3(t, h.y * 0.62, 0) if along_x else Vector3(0, h.y * 0.62, t)
				if shape == "header":
					k.box(pp, Vector3(0.015, s.y * 0.5, 0.015), col.call("#d4af37", M))
				else:
					k.box(pp, Vector3(0.02 if along_x else s.x * 0.5, 0.004, s.z * 0.5 if along_x else 0.02), col.call("#0a0a0c", D))
			if shape in ["dimm_slot", "pcie_slot"]:
				var end := Vector3(0, 0, h.z - 0.03) if not along_x else Vector3(h.x - 0.03, 0, 0)
				k.box(end, Vector3(s.x if not along_x else 0.06, s.y, 0.06 if not along_x else s.z), col.call("#e8e8ee", D))
		"psu":
			k.box(Vector3.ZERO, s, col.call(c, M))
			for i in 9:
				k.box(Vector3(-h.x + 0.15 + i * (s.x - 0.3) / 8.0, 0, h.z + 0.003), Vector3(0.04, s.y * 0.6, 0.006), col.call("#0a0a0c", D))
			k.box(Vector3(0, 0.05, -h.z - 0.003), Vector3(s.x * 0.55, s.y * 0.4, 0.006), col.call("#e8b949", D))
			k.box(Vector3(h.x * 0.7, h.y * 0.6, h.z + 0.004), Vector3(0.06, 0.04, 0.006), col.call("#3cf08a", G))
		"grille_y":
			for r in [0.48, 0.36, 0.24, 0.12]:
				k.ring(Vector3.ZERO, minf(h.x, h.z) * r / 0.5, 0.012, s.y, col.call(c, M), 28)
			k.box(Vector3.ZERO, Vector3(s.x * 0.96, s.y, 0.02), col.call(c, M))
			k.box(Vector3.ZERO, Vector3(0.02, s.y, s.z * 0.96), col.call(c, M))
		"panel_conn", "io_shield", "port", "usb":
			k.box(Vector3.ZERO, s, col.call(c, M if shape in ["io_shield", "port"] and c.get_luminance() > 0.4 else D))
			# yuva ağızları: en ince eksene dik yüzde koyu dikdörtgenler
			var face_z := s.z <= s.x
			var cols2 := 3 if shape != "port" else 1
			var rows2 := 2 if shape != "port" else 2
			for a in cols2:
				for b in rows2:
					var u := (a + 0.5) / cols2 - 0.5
					var v := (b + 0.5) / rows2 - 0.5
					if face_z:
						k.box(Vector3(u * s.x * 0.8, v * s.y * 0.7, -h.z - 0.002), Vector3(s.x * 0.7 / cols2, s.y * 0.25, 0.004), col.call("#0a0a0c" if shape != "usb" else "#2f6fe0", D))
					else:
						k.box(Vector3(h.x + 0.002, v * s.y * 0.7, u * s.z * 0.8), Vector3(0.004, s.y * 0.25, s.z * 0.7 / cols2), col.call("#0a0a0c", D))
		"choke_row", "mosfet_row":
			var along := s.x >= s.z
			var L2: float = s.x if along else s.z
			var cnt := int(clampf(L2 / (0.12 if shape == "choke_row" else 0.09), 2, 12))
			for i in cnt:
				var t2 := -L2 / 2.0 + (i + 0.5) * L2 / cnt
				var w := L2 / cnt * 0.8
				var pc := Vector3(t2, 0, 0) if along else Vector3(0, 0, t2)
				var sz2 := Vector3(w, s.y, s.z * 0.9) if along else Vector3(s.x * 0.9, s.y, w)
				k.box(pc, sz2, col.call(c, D))
				k.box(pc + Vector3(0, h.y + 0.002, 0), sz2 * Vector3(0.6, 0.0, 0.6) + Vector3(0, 0.004, 0), col.call("#c27a3e" if shape == "choke_row" else "#d2d5dc", M))
		"cable_x", "cable_y", "cable_z":
			var ax := shape.substr(6)
			var b2 := Basis()
			var L3 := s.x
			var r2 := minf(s.y, s.z) / 2.0
			if ax == "x":
				b2 = Basis(Vector3.FORWARD, PI / 2)
			elif ax == "z":
				b2 = Basis(Vector3.RIGHT, PI / 2)
				L3 = s.z
				r2 = minf(s.x, s.y) / 2.0
			else:
				L3 = s.y
				r2 = minf(s.x, s.z) / 2.0
			for i in 3:
				var off := Vector3(0, (i - 1) * r2 * 0.6, 0) if ax != "y" else Vector3((i - 1) * r2 * 0.6, 0, 0)
				k.cyl(off, r2 * 0.42, L3, col.call(c, D), 10, b2)
			for j in 6:
				var t3 := -L3 / 2.0 + (j + 0.5) * L3 / 6.0
				var pos := b2 * Vector3(0, t3, 0)
				k.cyl(pos, r2 * 0.98, 0.03, col.call("#8a5cff" if j % 2 == 0 else "#3a3d44", D), 12, b2)
		"socket":
			k.box(Vector3(0, -h.y * 0.5, 0), Vector3(s.x, s.y * 0.5, s.z), col.call(c, D))
			for e in 4:
				var b3 := Basis(Vector3.UP, e * PI / 2)
				k.box(b3 * Vector3(0, h.y * 0.2, h.z * 0.92), Vector3(s.x, s.y * 0.6, s.z * 0.08), col.call("#c9ccd2", M), b3)
		"pins":
			k.box(Vector3(0, -h.y * 0.5, 0), Vector3(s.x, s.y * 0.5, s.z), col.call("#2a2c33", D))
			for a in 10:
				for b in 10:
					k.box(Vector3(-h.x * 0.9 + a * s.x * 0.9 / 9.0, h.y * 0.3, -h.z * 0.9 + b * s.z * 0.9 / 9.0), Vector3(0.012, s.y * 0.6, 0.012), col.call(c, M))
		"lever":
			k.cyl(Vector3(0, -h.y * 0.3, 0), minf(h.x, h.y) * 0.6, s.z, col.call(c, M), 8, Basis(Vector3.RIGHT, PI / 2))
			k.box(Vector3(0, 0, h.z - 0.02), Vector3(s.x, s.y, 0.04), col.call(c, M))
		"die", "die_v":
			k.box(Vector3.ZERO, s, col.call(c, G))
		"ihs":
			k.box(Vector3.ZERO, s, col.call(c, M))
			k.box(Vector3(0, h.y + 0.002, -h.z * 0.3), Vector3(s.x * 0.6, 0.004, 0.02), col.call("#5a5f68", D))
			k.box(Vector3(0, h.y + 0.002, 0), Vector3(s.x * 0.45, 0.004, 0.02), col.call("#5a5f68", D))
		"paste":
			k.cyl(Vector3.ZERO, minf(h.x, h.z), s.y, col.call(c, D), 24)
		"crystal", "battery_x":
			k.cyl(Vector3.ZERO, minf(h.y, h.z), s.x, col.call(c, M), 14, Basis(Vector3.FORWARD, PI / 2))
		"dimm":
			k.box(Vector3.ZERO, Vector3(s.x * 0.4, s.y, s.z), col.call(c, D))
			k.box(Vector3(0, -h.y + 0.03, 0), Vector3(s.x * 0.45, 0.06, s.z * 0.96), col.call("#d4af37", M))
			for i in 8:
				var zz2 := -h.z + (i + 0.5) * s.z / 8.0
				for sx in [-1.0, 1.0]:
					k.box(Vector3(sx * h.x * 0.65, -h.y * 0.05, zz2), Vector3(s.x * 0.28, s.y * 0.35, s.z / 8.0 * 0.8), col.call("#16161b", D))
			k.box(Vector3(0, h.y * 0.62, 0), Vector3(s.x, s.y * 0.36, s.z), col.call("#30333b", M))
		"rgb_bar", "led_strip":
			var segs := 8
			var along3 := s.x >= s.z
			for i in segs:
				var t4 := (i + 0.5) / segs - 0.5
				var hue := Color.from_hsv(fmod(0.72 + i * 0.07, 1.0), 0.7, 1.0)
				var pc2 := Vector3(t4 * s.x, 0, 0) if along3 else Vector3(0, 0, t4 * s.z)
				var sz3 := Vector3(s.x / segs, s.y, s.z) if along3 else Vector3(s.x, s.y, s.z / segs)
				k.box(pc2, sz3, col.call(hue, G))
		"heatsink", "fins_y", "fins_z":
			if shape == "fins_y":
				var nf := int(clampf(s.y / 0.05, 4, 24))
				for i in nf:
					k.box(Vector3(0, -h.y + (i + 0.5) * s.y / nf, 0), Vector3(s.x, s.y / nf * 0.45, s.z), col.call(c, M))
				k.box(Vector3(0, 0, 0), Vector3(s.x * 0.15, s.y, s.z * 0.15), col.call("#c27a3e", CU))
			elif shape == "fins_z":
				var nf2 := int(clampf(s.x / 0.05, 4, 60))
				for i in nf2:
					k.box(Vector3(-h.x + (i + 0.5) * s.x / nf2, 0, 0), Vector3(s.x / nf2 * 0.4, s.y, s.z), col.call(c, M))
			else:
				k.box(Vector3(0, -h.y * 0.7, 0), Vector3(s.x, s.y * 0.3, s.z), col.call(c, M))
				var along4 := s.x >= s.z
				var L4: float = s.z if along4 else s.x
				var nf3 := int(clampf(L4 / 0.04, 3, 16))
				for i in nf3:
					var t5 := -L4 / 2.0 + (i + 0.5) * L4 / nf3
					var pc3 := Vector3(0, h.y * 0.15, t5) if along4 else Vector3(t5, h.y * 0.15, 0)
					var sz4 := Vector3(s.x, s.y * 0.7, L4 / nf3 * 0.45) if along4 else Vector3(L4 / nf3 * 0.45, s.y * 0.7, s.z)
					k.box(pc3, sz4, col.call(c.lightened(0.1), M))
		"backplate", "backplate_v", "panel_v", "tray", "mon_base", "neck", "pad", "kb_base":
			k.box(Vector3.ZERO, s, col.call(c, M if shape in ["backplate", "backplate_v", "mon_base", "neck"] else D))
			if shape == "panel_v":
				k.ring(Vector3(0.3, 0.9, h.z + 0.004), 0.55, 0.03, 0.01, col.call("#4a4f58", M), 32, Basis(Vector3.RIGHT, PI / 2))
				for i in 12:
					k.box(Vector3(-h.x + 0.4 + i * 0.12, -h.y + 0.6, h.z + 0.004), Vector3(0.05, 0.4, 0.006), col.call("#15161a", D))
			elif shape == "tray":
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						k.cyl(Vector3(sx * (h.x - 0.2), -h.y + 0.01, sz * (h.z - 0.2)), 0.12, 0.02, col.call("#111", D), 12)
			elif shape == "kb_base":
				k.box(Vector3(h.x * 0.8, h.y + 0.002, -h.z * 0.8), Vector3(0.1, 0.004, 0.03), col.call("#3cf08a", G))
		"vram":
			for a in 4:
				for b in 2:
					k.box(Vector3(-h.x + (a + 0.5) * s.x / 4.0, -h.y + (b + 0.5) * s.y / 2.0, 0), Vector3(s.x / 4.0 * 0.7, s.y / 2.0 * 0.7, s.z), col.call(c, D))
		"shroud":
			k.box(Vector3.ZERO, s, col.call(c, D))
			k.box(Vector3(0, h.y * 0.85, h.z + 0.003), Vector3(s.x * 0.95, 0.03, 0.006), col.call("#62f2c8", G))
			k.box(Vector3(h.x * 0.7, -h.y * 0.6, h.z + 0.003), Vector3(0.3, 0.05, 0.006), col.call("#62f2c8", G))
		"fan_x", "fan_y", "fan_z":
			var ax2 := shape.substr(4)
			# yerel çerçeve: fan ekseni Y; X/Z için döndür
			var fb := Basis()
			var lw := Vector2(s.x, s.z)
			var th := s.y
			if ax2 == "z":
				fb = Basis(Vector3.RIGHT, PI / 2)
				lw = Vector2(s.x, s.y)
				th = s.z
			elif ax2 == "x":
				fb = Basis(Vector3.FORWARD, PI / 2)
				lw = Vector2(s.y, s.z)
				th = s.x
			var rr := minf(lw.x, lw.y) / 2.0
			for e in 4:
				var eb := Basis(Vector3.UP, e * PI / 2)
				k.box(fb * (eb * Vector3(0, 0, rr * 0.94)), Vector3(rr * 2.0, th, rr * 0.12), col.call(c, D), fb * eb)
			k.ring(Vector3.ZERO, rr * 0.9, rr * 0.05, th * 0.9, col.call(c.lightened(0.15), D), 28, fb)
			var spin := MeshKit.new()
			spin.cyl(Vector3.ZERO, rr * 0.28, th * 0.8, MeshKit.col("#30333b", D), 18, fb)
			spin.ring(Vector3.ZERO, rr * 0.3, rr * 0.04, th * 0.82, MeshKit.col("#8a5cff", G), 18, fb)
			for bl in 7:
				var bb := fb * Basis(Vector3.UP, bl * TAU / 7.0) * Basis(Vector3.RIGHT, 0.35)
				spin.box(fb * (Basis(Vector3.UP, bl * TAU / 7.0) * Vector3(rr * 0.58, 0, 0)), Vector3(rr * 0.6, th * 0.15, rr * 0.3), MeshKit.col("#2c2f36", D), bb)
			out["spin"] = spin.commit()
			out["axis"] = fb * Vector3.UP
		"heatpipes":
			for i in 4:
				k.cyl(Vector3(0, -h.y * 0.5 + (i % 2) * h.y * 0.6, -h.z * 0.75 + i * s.z * 0.5), minf(h.y, h.z) * 0.25, s.x, col.call(c, CU), 12, Basis(Vector3.FORWARD, PI / 2))
		"jacks":
			k.box(Vector3.ZERO, s, col.call("#2a2c33", D))
			var jc := ["#3cc07a", "#ff7ab8", "#3a8bff", "#ffb84d"]
			for i in 4:
				k.cyl(Vector3(0, -h.y * 0.7 + i * s.y * 0.45, -h.z - 0.004), minf(h.x, h.y) * 0.5, 0.01, col.call(jc[i], D), 14, Basis(Vector3.RIGHT, PI / 2))
		"antenna":
			for sx in [-1.0, 1.0]:
				k.cyl(Vector3(sx * h.x * 0.6, 0.05, 0), minf(h.x, h.z) * 0.25, s.y * 0.9, col.call(c, D), 10)
				k.cyl(Vector3(sx * h.x * 0.6, -h.y + 0.04, 0), minf(h.x, h.z) * 0.35, 0.08, col.call("#d4af37", M), 10)
		"pillar":
			k.box(Vector3.ZERO, s, col.call(c, M))
			k.box(Vector3(0, 0, h.z * 0.0 - h.z - 0.003), Vector3(s.x * 0.3, s.y * 0.96, 0.006), col.call("#8a5cff", G))
		"frame_top":
			for e in [Vector3(0, 0, -h.z + 0.08), Vector3(0, 0, h.z - 0.08)]:
				k.box(e, Vector3(s.x, s.y, 0.16), col.call(c, M))
			for e2 in [Vector3(-h.x + 0.08, 0, 0), Vector3(h.x - 0.08, 0, 0), Vector3(-0.75, 0, 0)]:
				k.box(e2, Vector3(0.16, s.y, s.z), col.call(c, M))
		"glass":
			var gk := MeshKit.new()
			gk.box(Vector3.ZERO, s, MeshKit.col(c, D))
			out["glass"] = gk.commit()
			k.box(Vector3(0, h.y - 0.02, 0), Vector3(s.x, 0.04, s.z), col.call("#30333b", M))
			k.box(Vector3(0, -h.y + 0.02, 0), Vector3(s.x, 0.04, s.z), col.call("#30333b", M))
		"button":
			k.cyl(Vector3.ZERO, minf(h.x, h.z), s.y, col.call(c, M), 24)
			k.ring(Vector3(0, h.y * 0.6, 0), minf(h.x, h.z) * 0.8, 0.012, s.y * 0.3, col.call("#62f2ff", G), 24)
		"mon_panel":
			k.box(Vector3.ZERO, s, col.call(c, D))
			k.box(Vector3(0, -h.y + 0.05, h.z + 0.002), Vector3(0.2, 0.03, 0.004), col.call("#e8e8ee", D))
		"screen":
			k.box(Vector3.ZERO, s, col.call("#0e2a4a", G))
			# masaüstü: pencereler, görev çubuğu ve oyunun kodu
			k.box(Vector3(0, -h.y + 0.05, h.z * 0.6), Vector3(s.x, 0.1, s.z * 0.6), col.call("#1d1f26", G))
			k.box(Vector3(-h.x * 0.45, h.y * 0.25, h.z * 0.7), Vector3(s.x * 0.42, s.y * 0.55, s.z * 0.5), col.call("#3a8bff", G))
			k.box(Vector3(h.x * 0.4, h.y * 0.05, h.z * 0.75), Vector3(s.x * 0.38, s.y * 0.62, s.z * 0.5), col.call("#2fc37a", G))
			for i in 5:
				k.box(Vector3(h.x * 0.3 - 0.1 * (i % 2), h.y * 0.25 - i * 0.12, h.z * 0.85), Vector3(s.x * 0.2 - 0.05 * (i % 3), 0.04, s.z * 0.4), col.call("#e8fff3", G))
		"keys":
			var nx := 15
			var nz := 5
			for a in nx:
				for b in nz:
					var kc := "#e8e8ee" if (a + b) % 7 != 0 else "#ff9a3c"
					k.box(Vector3(-h.x + (a + 0.5) * s.x / nx, 0, -h.z + (b + 0.5) * s.z / nz), Vector3(s.x / nx * 0.8, s.y, s.z / nz * 0.8), col.call(kc, D))
		"mouse":
			k.box(Vector3(0, -h.y * 0.3, 0), Vector3(s.x, s.y * 0.4, s.z), col.call(c, D))
			k.cyl(Vector3(0, h.y * 0.1, 0), minf(h.x, h.z) * 0.98, s.y * 0.55, col.call(c, D), 20)
			k.box(Vector3(0, h.y * 0.42, -h.z * 0.45), Vector3(0.03, 0.03, 0.08), col.call("#62f2ff", G))
		"speaker":
			k.box(Vector3.ZERO, s, col.call(c, D))
			for yy in [h.y * 0.45, -h.y * 0.25]:
				k.cyl(Vector3(0, yy, h.z + 0.005), minf(h.x, h.y) * (0.55 if yy < 0 else 0.3), 0.01, col.call("#3a3d44", M), 20, Basis(Vector3.RIGHT, PI / 2))
		"core":
			var r3 := minf(h.x, minf(h.y, h.z))
			k.box(Vector3.ZERO, Vector3.ONE * r3 * 1.1, col.call(c, G), Basis(Vector3(1, 1, 0).normalized(), 0.95))
			out["spin"] = MeshKit.new().ring(Vector3.ZERO, r3 * 0.95, 0.03, 0.03, MeshKit.col("#ffd36e", G), 32, Basis(Vector3.RIGHT, 0.5)).ring(Vector3.ZERO, r3 * 0.8, 0.03, 0.03, MeshKit.col("#8a5cff", G), 32, Basis(Vector3.FORWARD, 0.9)).commit()
			out["axis"] = Vector3.UP
		_:
			k.box(Vector3.ZERO, s, col.call(c, D))
	out["main"] = k.commit()
	return out
