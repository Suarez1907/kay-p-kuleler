## Bilgisayar parçası kütüphanesi ve montaj sahnesi testi.
## godot --headless --path godot-program --script res://tests/run_parts.gd
extends SceneTree

func _init() -> void:
	var fails := []
	var parts := PCPartLibrary.all()
	if parts.size() != 100:
		fails.append("parça sayısı %d" % parts.size())
	var names := {}
	var phases := {}
	for p in parts:
		var pd: PCPartData = p
		if names.has(pd.part_name):
			fails.append("aynı ad: " + pd.part_name)
		names[pd.part_name] = true
		phases[pd.phase_index] = phases.get(pd.phase_index, 0) + 1
		if pd.part_id < 1 or pd.part_id > 100:
			fails.append("kimlik dışı: %d" % pd.part_id)
		if pd.assembly_scale.x <= 0 or pd.assembly_scale.y <= 0 or pd.assembly_scale.z <= 0:
			fails.append("boyut: " + pd.part_name)
		if pd.optional_glb_path != "res://assets/models/pc_parts/part_%03d.glb" % pd.part_id:
			fails.append("glb yolu: " + pd.part_name)
	for ph in 10:
		if phases.get(ph, 0) != 10:
			fails.append("faz %d: %d parça" % [ph + 1, phases.get(ph, 0)])
	# çakışma: iki parçanın kutusu iç içe geçmemeli (temas serbest)
	for i in parts.size():
		var a: PCPartData = parts[i]
		var ba := AABB(a.assembly_position - a.assembly_scale / 2.0, a.assembly_scale).grow(-0.0005)
		for j in range(i + 1, parts.size()):
			var b: PCPartData = parts[j]
			var bb := AABB(b.assembly_position - b.assembly_scale / 2.0, b.assembly_scale).grow(-0.0005)
			if ba.intersects(bb):
				fails.append("çakışma: %s <-> %s" % [a.part_name, b.part_name])
	# her parça bir model üretebilmeli (glb yoksa prosedürel)
	for p in parts:
		var n := PartBuilder.build(p)
		var bodies: Array = n.get_meta("bodies", [])
		if bodies.is_empty() or (bodies[0] as MeshInstance3D).mesh == null or (bodies[0] as MeshInstance3D).mesh.get_surface_count() == 0:
			fails.append("model yok: " + p.part_name)
		n.free()
	# siluet: anakart masanın üstünde, monitör sağda, sistem çekirdeği en üstte
	var mb := PCPartLibrary.part(1)
	var mon := PCPartLibrary.part(93)
	var core := PCPartLibrary.part(100)
	if not (mon.assembly_position.x > mb.assembly_position.x + 2.0 and core.assembly_position.y > 4.0):
		fails.append("siluet")
	print("parts: ", "TAMAM" if fails.is_empty() else "HATA " + str(fails))
	quit(0 if fails.is_empty() else 1)
