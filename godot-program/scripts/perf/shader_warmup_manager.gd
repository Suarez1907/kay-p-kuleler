extends Node
## ShaderWarmupManager
## Açılışta gizli ön-ısıtma düğümleri oluşturup Vulkan pipeline'larını
## (shader derleme) önceden derler. Oyun içi nesnelere, materyallere,
## ses motoruna veya sinematiklere dokunmaz. Hata durumunda sessizce çıkar.

const _WARMUP_FRAMES: int = 3
const _SCALE: Vector3 = Vector3(0.001, 0.001, 0.001)
const _HIDDEN_POS: Vector3 = Vector3(0.0, -50.0, 0.0)

var _warm: bool = false
var _running: bool = false
var _root: Node3D = null
var _temp_nodes: Array[Node] = []

## Projede bulunması muhtemel materyal yolları (yoksa atlanır).
const _CANDIDATE_MATERIAL_PATHS: Array[String] = [
	"res://assets/materials/smd.tres",
	"res://assets/materials/diode.tres",
	"res://assets/materials/capacitor.tres",
	"res://assets/materials/resistor.tres",
	"res://assets/materials/relay_glass.tres",
	"res://assets/materials/pcb.tres",
	"res://assets/materials/robot.tres",
	"res://assets/materials/spark.tres",
	"res://assets/materials/assembly.tres",
]


func is_warm() -> bool:
	return _warm


## Asenkron başlatır ve hemen döner. Oyunu bloklamaz.
func warm_up(material_paths: PackedStringArray = PackedStringArray()) -> void:
	if _running or _warm:
		return
	_running = true
	_warm_step(material_paths)


func _warm_step(material_paths: PackedStringArray) -> void:
	# Sahne ağacı hazır değilse sessizce çık.
	if not is_inside_tree():
		_running = false
		return

	_root = Node3D.new()
	_root.name = "ShaderWarmupRoot"
	add_child(_root)

	var paths: Array[String] = _resolve_paths(material_paths)
	for path in paths:
		_spawn_material_probe(path)

	_spawn_spark_probe()

	# Pipeline'ların derlenmesi için birkaç kare bekle.
	for _i in range(_WARMUP_FRAMES):
		await get_tree().process_frame

	_cleanup()
	_warm = true
	_running = false


func _resolve_paths(material_paths: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	# Önce verilen yolları dene.
	for p in material_paths:
		if ResourceLoader.exists(p):
			result.append(p)

	# Sonra bilinen aday yolları dene.
	for p in _CANDIDATE_MATERIAL_PATHS:
		if p in result:
			continue
		if ResourceLoader.exists(p):
			result.append(p)

	# Hiçbiri yoksa boş döner; hata fırlatılmaz.
	return result


func _spawn_material_probe(path: String) -> void:
	var mat: Resource = null
	if ResourceLoader.exists(path):
		mat = load(path) as Resource
	if mat == null:
		return

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _make_probe_mesh()
	mesh_inst.material_override = mat
	mesh_inst.scale = _SCALE
	mesh_inst.position = _HIDDEN_POS
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.visible = true
	_root.add_child(mesh_inst)
	_temp_nodes.append(mesh_inst)


func _spawn_spark_probe() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 4
	particles.lifetime = 0.1
	particles.position = _HIDDEN_POS
	particles.scale = _SCALE
	particles.visible = true
	var pm := ParticleProcessMaterial.new()
	particles.process_material = pm
	_root.add_child(particles)
	_temp_nodes.append(particles)


func _make_probe_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	return mesh


func _cleanup() -> void:
	for node in _temp_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_temp_nodes.clear()

	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
