## Harici model ve doku tak-çalıştır katmanı. Kod değiştirmeden dosya eklemek yeter:
##   res://assets/models/robot.glb
##   res://assets/models/components/{smd_transistor,diode,capacitor,resistor,relay,bridge}.glb
##   res://assets/models/pc_parts/part_001.glb … part_100.glb
##   res://assets/textures/pbr/<malzeme>/{albedo,normal,roughness,ao}.png
## Model varsa yüklenir, sınır kutusu (AABB) hesaplanıp hedef boyuta orantılı ölçeklenir, x/z'de ortalanır ve
## tabanı y = 0'a oturtulur. Yoksa null döner ve çağıran prosedürel modeli kullanır (oyun hatasız çalışır).
class_name AssetLoader
extends RefCounted

const MODELS := "res://assets/models/"
const PBR := "res://assets/textures/pbr/"

static var _pbr_cache := {}

static func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)

## .glb'yi yükle ve hedef kutuya sığdır. align_bottom: taban y=0 (değilse merkez orijinde).
static func load_model(path: String, target := Vector3.ONE, align_bottom := true) -> Node3D:
	if not exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	var inst: Node = (res as PackedScene).instantiate()
	if not (inst is Node3D):
		inst.queue_free()
		return null
	var holder := Node3D.new()
	var n: Node3D = inst
	holder.add_child(n)
	var acc := {"box": AABB(), "first": true}
	PartBuilder._accum(n, Transform3D.IDENTITY, acc)
	if acc["first"]:
		return holder
	var box: AABB = acc["box"]
	var s := minf(target.x / maxf(box.size.x, 1e-4), minf(target.y / maxf(box.size.y, 1e-4), target.z / maxf(box.size.z, 1e-4)))
	n.scale = Vector3.ONE * s
	var c := box.get_center() * s
	n.position = Vector3(-c.x, -box.position.y * s if align_bottom else -c.y, -c.z)
	return holder

static func robot_model() -> Node3D:
	return load_model(MODELS + "robot.glb", Vector3(0.62, 0.8, 0.62), true)

## Devre elemanı: 1×1×1 hücre, taban y=0
static func component_model(name: String) -> Node3D:
	return load_model(MODELS + "components/%s.glb" % name, Vector3.ONE, true)

## Bilgisayar parçası: parçanın montaj kutusuna sığar, merkezi orijinde
static func part_model(id: int, size: Vector3, extra_path := "") -> Node3D:
	for path in [MODELS + "pc_parts/part_%03d.glb" % id, extra_path]:
		if exists(path):
			var m := load_model(path, size, false)
			if m != null:
				return m
	return null

## PBR doku seti → StandardMaterial3D (albedo zorunlu; normal, roughness, ao isteğe bağlı). Yoksa null.
static func pbr_material(name: String) -> StandardMaterial3D:
	if _pbr_cache.has(name):
		return _pbr_cache[name]
	var dir := PBR + name + "/"
	var mat: StandardMaterial3D = null
	if exists(dir + "albedo.png"):
		mat = StandardMaterial3D.new()
		mat.albedo_texture = load(dir + "albedo.png")
		if exists(dir + "normal.png"):
			mat.normal_enabled = true
			mat.normal_texture = load(dir + "normal.png")
		if exists(dir + "roughness.png"):
			mat.roughness_texture = load(dir + "roughness.png")
			mat.roughness = 1.0
		if exists(dir + "ao.png"):
			mat.ao_enabled = true
			mat.ao_texture = load(dir + "ao.png")
	_pbr_cache[name] = mat
	return mat
