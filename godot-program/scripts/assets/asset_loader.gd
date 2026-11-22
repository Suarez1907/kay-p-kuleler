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

## .glb'yi yükle ve hedef kutuya sığdır. align: true/"bottom" taban y=0, false/"center" merkez orijinde, "top" üst yüz y=0.
static func load_model(path: String, target := Vector3.ONE, align = true) -> Node3D:
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
	var y := -c.y
	if align is bool and align or align is String and align == "bottom":
		y = -box.position.y * s
	elif align is String and align == "top":
		y = -box.end.y * s
	n.position = Vector3(-c.x, y, -c.z)
	return holder

## Sahne modeli (assets/models/scenes/<ad>.glb): Blender'daki dünya koordinatlarıyla, ölçeklenmeden yüklenir.
static func scene_model(name: String) -> Node3D:
	var path := MODELS + "scenes/%s.glb" % name
	if not exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	var inst: Node = (res as PackedScene).instantiate()
	if inst is Node3D:
		return inst
	inst.queue_free()
	return null

## Tema dekor seti (assets/models/themes/theme_XX.glb), tabanı y=0, hedef kutuya sığar
static func theme_model(id: int, target := Vector3(1.4, 2.6, 2.4)) -> Node3D:
	return load_model(MODELS + "themes/theme_%02d.glb" % id, target, true)

static func robot_model() -> Node3D:
	return load_model(MODELS + "robot.glb", Vector3(0.62, 0.8, 0.62), true)

## Modeldeki ilk AnimationPlayer (iskeletli robot: idle, walk, turn, fall, victory, wave, look). Döngüler ayarlanır.
static func anim_player(root: Node, loops := ["idle", "walk", "look"]) -> AnimationPlayer:
	if root == null:
		return null
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	var ap: AnimationPlayer = found[0]
	for n in loops:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return ap

## Devre elemanı: 1×1×1 hücre, taban y=0 (köprü için align = "top": üst yüz y=0)
static func component_model(name: String, align = true) -> Node3D:
	return load_model(MODELS + "components/%s.glb" % name, Vector3.ONE, align)

## Modeldeki adı verilen malzemenin kullanıldığı yüzeylere, örneğe özel kopya malzeme bağlar ve kopyaları döndürür
## (ör. "RobotLED" tema rengi, "Band1".."Band4" direnç bantları, "Pins" basış parlaması, "MonitorScreen").
static func unique_surfaces(root: Node, mat_name: String) -> Array:
	var out := []
	for mi in PartBuilder._meshes_in(root):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm != null and sm.resource_name == mat_name:
				var cp: Material = sm.duplicate()
				m.set_surface_override_material(i, cp)
				out.append(cp)
	return out

## Adı verilen malzemenin yüzeylerine verilen malzemeyi bağlar (ör. MonitorScreen → BIOS SubViewport dokusu)
static func bind_surfaces(root: Node, mat_name: String, material: Material) -> int:
	var n := 0
	for mi in PartBuilder._meshes_in(root):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm != null and sm.resource_name == mat_name:
				m.set_surface_override_material(i, material)
				n += 1
	return n

static var _overlay: ShaderMaterial
## Harici modeller için enerji parlaması katmanı (örnek başına "glow")
static func glow_overlay() -> ShaderMaterial:
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = load("res://shaders/glow_overlay.gdshader")
	return _overlay

## Modeldeki toplam üçgen sayısı
static func triangle_count(root: Node) -> int:
	var n := 0
	for mi in PartBuilder._meshes_in(root):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(i)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n

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
