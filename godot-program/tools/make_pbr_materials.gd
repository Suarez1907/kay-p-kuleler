## 2K PBR doku setlerinden res://assets/materials/pbr/*.tres malzemelerini üretir ve doğrular.
##   godot --headless --path godot-program --script res://tools/make_pbr_materials.gd
extends SceneTree

func _init() -> void:
	var r := PBRMaterialBank.build_all()
	var bad := 0
	for s in r:
		var ok: bool = r[s] is int and r[s] == OK
		var m := load(PBRMaterialBank.DIR + s + ".tres") as StandardMaterial3D if ok else null
		var sz := Vector2i.ZERO
		if m != null and m.albedo_texture != null:
			sz = Vector2i(m.albedo_texture.get_width(), m.albedo_texture.get_height())
		ok = ok and sz == Vector2i(2048, 2048) and m.normal_texture != null and m.roughness_texture != null and m.ao_texture != null
		if not ok:
			bad += 1
		print("  %-22s %s %dx%d metalik=%s" % [s, "TAMAM" if ok else "HATA " + str(r[s]), sz.x, sz.y,
			"doku" if m != null and m.metallic_texture != null else str(m.metallic if m != null else 0)])
	print("pbr-bank: %s (%d set)" % ["TAMAM" if bad == 0 else "HATA", r.size()])
	quit(0 if bad == 0 else 1)
