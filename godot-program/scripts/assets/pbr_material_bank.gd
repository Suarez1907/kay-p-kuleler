## 2K PBR malzeme bankası: tools/build_2k_pbr_library.py setlerinden üretilen res://assets/materials/pbr/<set>.tres
## kaynakları ve glTF malzeme yuvası → set eşlemesi.
##   godot --headless --path godot-program --script res://tools/make_pbr_materials.gd   (.tres'leri yeniden yazar)
## "full": setin rengi kullanılır (paylaşılan tek malzeme → toplu çizime uygun)
## "detail": modelin kendi rengi kalır, yalnızca 2K normal + pürüzlülük + AO eklenir (renkli plastik, koyu metal)
class_name PBRMaterialBank
extends RefCounted

const TEX := "res://assets/textures/pbr/"
const DIR := "res://assets/materials/pbr/"

## set → [triplanar ölçeği (dünya birimi başına tekrar), metalik, pürüzlülük çarpanı]
const SETS := {
	"brushed_aluminum_2k": [2.0, 1.0, 1.0],
	"copper_metal_2k": [2.0, 1.0, 1.0],
	"gold_contacts_2k": [3.0, 1.0, 1.0],
	"epoxy_black_2k": [1.6, 0.0, 1.0],
	"ceramic_matte_2k": [1.4, 0.0, 1.0],
	"pcb_circuit_2k": [0.5, 0.0, 1.0],
	"workshop_desk_2k": [0.45, 0.0, 1.0],
}

## glTF malzeme adı → [set, kip]
const SLOTS := {
	"Aluminum": ["brushed_aluminum_2k", "full"], "Steel": ["brushed_aluminum_2k", "full"], "Nickel": ["brushed_aluminum_2k", "full"],
	"Hinge": ["brushed_aluminum_2k", "full"], "Pins": ["brushed_aluminum_2k", "full"], "BdMetal": ["brushed_aluminum_2k", "full"],
	"DarkMetal": ["brushed_aluminum_2k", "detail"], "BrushedDarkMetal": ["brushed_aluminum_2k", "detail"],
	"Anthracite": ["brushed_aluminum_2k", "detail"], "Blade": ["brushed_aluminum_2k", "detail"],
	"Copper": ["copper_metal_2k", "full"], "Brass": ["gold_contacts_2k", "detail"], "BrassWool": ["copper_metal_2k", "detail"],
	"Gold": ["gold_contacts_2k", "full"], "BdGold": ["gold_contacts_2k", "full"],
	"Epoxy": ["epoxy_black_2k", "full"], "BlackPlastic": ["epoxy_black_2k", "full"], "RelayBase": ["epoxy_black_2k", "full"],
	"Die": ["epoxy_black_2k", "full"], "Rubber": ["epoxy_black_2k", "detail"], "TreadRubber": ["epoxy_black_2k", "detail"],
	"RubberBase": ["epoxy_black_2k", "detail"], "Sleeve": ["epoxy_black_2k", "detail"],
	"Ceramic": ["ceramic_matte_2k", "detail"], "AmberCeramic": ["ceramic_matte_2k", "detail"],
	"WhitePlastic": ["ceramic_matte_2k", "detail"], "RedPlastic": ["ceramic_matte_2k", "detail"],
	"BluePlastic": ["ceramic_matte_2k", "detail"],
	"PCB": ["pcb_circuit_2k", "full"], "BdPCB": ["pcb_circuit_2k", "full"], "BridgePCB": ["pcb_circuit_2k", "full"],
	"DeskWood": ["workshop_desk_2k", "full"],
}

static var _mats := {}
static var _derived := {}

static func has_set(set_name: String) -> bool:
	return ResourceLoader.exists(DIR + set_name + ".tres")

## Setin paylaşılan malzemesi (yoksa null)
static func material(set_name: String) -> StandardMaterial3D:
	if not _mats.has(set_name):
		_mats[set_name] = load(DIR + set_name + ".tres") if has_set(set_name) else null
	return _mats[set_name]

## Kaynak glTF malzemesine göre zenginleştirilmiş malzeme (eşleşme yoksa null)
static func for_source(src: StandardMaterial3D) -> StandardMaterial3D:
	if src == null or not SLOTS.has(src.resource_name):
		return null
	var spec: Array = SLOTS[src.resource_name]
	var bank := material(spec[0])
	if bank == null:
		return null
	if spec[1] == "full" and src.albedo_color.a >= 0.999 and not src.emission_enabled:
		return bank
	var key := "%d/%s" % [src.get_instance_id(), spec[1]]
	if not _derived.has(key):
		var e: StandardMaterial3D = src.duplicate()
		e.resource_name = src.resource_name
		e.uv1_triplanar = true
		e.uv1_world_triplanar = false
		e.uv1_scale = bank.uv1_scale
		e.normal_enabled = true
		e.normal_texture = bank.normal_texture
		e.normal_scale = bank.normal_scale
		e.roughness_texture = bank.roughness_texture
		e.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		e.roughness = clampf(src.roughness * 1.4, 0.2, 1.0)
		e.ao_enabled = true
		e.ao_texture = bank.ao_texture
		e.ao_light_affect = bank.ao_light_affect
		if spec[1] == "full":
			e.albedo_texture = bank.albedo_texture
			e.albedo_color = Color(1, 1, 1, src.albedo_color.a)
			e.metallic = bank.metallic
			e.metallic_texture = bank.metallic_texture
		_derived[key] = e
	return _derived[key]

## .tres kaynaklarını dokulardan yazar (tools/make_pbr_materials.gd çağırır)
static func build_all() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var out := {}
	for sk in SETS:
		var s: String = sk
		var d := TEX + s + "/"
		if not ResourceLoader.exists(d + "albedo.jpg"):
			out[s] = "doku yok"
			continue
		var p: Array = SETS[s]
		var m := StandardMaterial3D.new()
		m.resource_name = s
		m.albedo_texture = load(d + "albedo.jpg")
		m.normal_enabled = true
		m.normal_texture = load(d + "normal.jpg")
		m.normal_scale = 0.85
		m.roughness_texture = load(d + "roughness.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		m.roughness = float(p[2])
		m.ao_enabled = true
		m.ao_texture = load(d + "ao.jpg")
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		m.ao_light_affect = 0.65
		m.metallic = float(p[1])
		if ResourceLoader.exists(d + "metallic.jpg"):
			m.metallic = 1.0
			m.metallic_texture = load(d + "metallic.jpg")
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		m.metallic_specular = 0.5
		# glTF modellerin UV1'i Blender akıllı projeksiyonu (parça başına farklı ölçek); 2K setler yerel
		# triplanar ile birim başına sabit doku yoğunluğunda yansıtılır. UV2 ışık haritası için boş kalır.
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE * float(p[0])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var path: String = DIR + s + ".tres"
		out[s] = ResourceSaver.save(m, path)
	return out
